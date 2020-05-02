--Schema Creation SQL:
-- Wyseman copy of function; Keep in sync with what is in bootstrap.sql
create schema if not exists wm;
grant usage on schema wm to public;

create or replace function wm.create_role(grp text, subs text[] default '{}') returns boolean language plpgsql as $$
  declare
    retval	boolean default false;
    sub		text;
  begin
    if not exists (select rolname from pg_roles where rolname = grp) then
      execute 'create role ' || grp;
      retval = true;
    end if;
    foreach sub in array subs loop
      execute 'grant ' || sub || ' to ' || grp;
    end loop;
    return retval;
  end;
$$;
create or replace function wm.release() returns int stable language sql as $$
  select 1;
$$;
create type audit_type as enum ('update','delete');
create schema base;
grant usage on schema base to public;
create function comma_dollar(float8) returns text immutable language sql as $$
    select to_char($1,'999,999,999.99');
$$;
create function comma_dollar(numeric) returns text immutable language sql as $$
    select to_char($1,'999,999,999.99');
$$;
create function date_quart(date) returns text language sql as $$
    select to_char($1,'YYYY-Q');
$$;
create function eqnocase(text,text) returns boolean language plpgsql immutable as $$
    begin return upper($1) = upper($2); end;
$$;
create function is_date(s text) returns boolean language plpgsql immutable as $$
    begin 
      perform s::date;
      return true;
    exception when others then
      return false;
    end;
$$;
create function neqnocase(text,text) returns boolean language plpgsql immutable as $$
    begin return upper($1) != upper($2); end;
$$;
create function norm_bool(boolean) returns text immutable strict language sql as $$
    select case when $1 then 'yes' else 'no' end;
$$;
create function norm_date(date) returns text immutable language sql as $$
    select to_char($1,'YYYY-Mon-DD');
$$;
create function norm_date(timestamptz) returns text immutable language sql as $$
    select to_char($1,'YYYY-Mon-DD HH24:MI:SS');
$$;
create function wm.column_names(oid,int4[]) returns varchar[] as $$
    declare
        val	varchar[];
        rec	record;
    begin
        for rec in select * from pg_attribute where attrelid = $1 and attnum = any($2) loop
            if val isnull then
                val := array[rec.attname::varchar];
            else
                val := val || rec.attname::varchar;
            end if;
        end loop;
        return val;
    end;
  $$ language plpgsql stable;
create table wm.column_native (
cnt_sch		name
  , cnt_tab		name
  , cnt_col		name
  , nat_sch		name
  , nat_tab		name
  , nat_col		name
  , nat_exp		boolean not null default 'f'
  , pkey		boolean
  , primary key (cnt_sch, cnt_tab, cnt_col)	-- each column can have only zero or one table considered as its native source
);
create table wm.column_style (
cs_sch		name
  , cs_tab		name
  , cs_col		name
  , sw_name		varchar not null
  , sw_value		varchar not null
  , primary key (cs_sch, cs_tab, cs_col, sw_name)
);
create table wm.column_text (
ct_sch		name
  , ct_tab		name
  , ct_col		name
  , language		varchar not null
  , title		varchar
  , help		varchar
  , primary key (ct_sch, ct_tab, ct_col, language)
);
create view wm.fkey_data as select
      co.conname			as conname
    , tn.nspname			as kyt_sch
    , tc.relname			as kyt_tab
    , ta.attname			as kyt_col
    , co.conkey[s.a]			as kyt_field
    , fn.nspname			as kyf_sch
    , fc.relname			as kyf_tab
    , fa.attname			as kyf_col
    , co.confkey[s.a]			as kyf_field
    , s.a				as key
    , array_upper(co.conkey,1)		as keys
  from			pg_constraint	co 
    join		generate_series(1,10) s(a)	on true
    join		pg_attribute	ta on ta.attrelid = co.conrelid  and ta.attnum = co.conkey[s.a]
    join		pg_attribute	fa on fa.attrelid = co.confrelid and fa.attnum = co.confkey[s.a]
    join		pg_class	tc on tc.oid = co.conrelid
    join		pg_namespace	tn on tn.oid = tc.relnamespace
    left join		pg_class	fc on fc.oid = co.confrelid
    left join		pg_namespace	fn on fn.oid = fc.relnamespace
  where co.contype = 'f';
grant select on table wm.fkey_data to public;
create table wm.message_text (
mt_sch		name
  , mt_tab		name
  , code		varchar
  , language		varchar not null
  , title		varchar		-- brief title for error message
  , help		varchar		-- longer help description
  , primary key (mt_sch, mt_tab, code, language)
);
create view wm.role_members as select ro.rolname				as role
  , me.rolname					as member
  , (string_to_array(ro.rolname,'_'))[1]	as priv
  , (string_to_array(ro.rolname,'_'))[2]	as level
    from        	pg_auth_members am
    join        	pg_authid       ro on ro.oid = am.roleid
    join        	pg_authid       me on me.oid = am.member
    where not ro.rolname like 'pg_%';
create table wm.table_style (
ts_sch		name
  , ts_tab		name
  , sw_name		varchar not null
  , sw_value		varchar not null
  , inherit		boolean default true
  , primary key (ts_sch, ts_tab, sw_name)
);
create table wm.table_text (
tt_sch		name
  , tt_tab		name
  , language	varchar not null
  , title		varchar
  , help		varchar
  , primary key (tt_sch, tt_tab, language)
);
create table wm.value_text (
vt_sch		name
  , vt_tab		name
  , vt_col		name
  , value		varchar
  , language		varchar not null
  , title		varchar		-- Normal title
  , help		varchar		-- longer help description
  , primary key (vt_sch, vt_tab, vt_col, value, language)
);
create view wm.view_column_usage as select * from information_schema.view_column_usage;
grant select on table wm.view_column_usage to public;
create schema wylib;
grant usage on schema wylib to public;
create table base.country (
code	varchar(2)	primary key
  , com_name	text		not null unique
  , capital	text
  , cur_code	varchar(4)	not null
  , cur_name	text		not null 
  , dial_code	varchar(20)
  , iso_3	varchar(4)	not null unique
  , iana	varchar(6)
);
create table base.language (
code	varchar(3)	primary key
  , iso_3b	text		unique
  , eng_name	text		not null
  , fra_name	text		not null
  , iso_2	varchar(2)	unique
);
create function base.priv_role(uname name, priv text, lev int) returns boolean security definer language plpgsql stable as $$
    declare
      trec	record;
    begin
      if uname = current_database() then		-- Often true for DB owner
        return true;
      end if;
      for trec in 
        select role, member, priv, level from wm.role_members rm where member = uname and rm.priv = priv or rm.level is null order by rm.level desc loop
raise notice 'Checking % % % % %', uname, trec.role, trec.priv, trec.level, trec.member;
          if trec.rpriv = priv and trec.level >= lev then
              return true;
          elsif trec.level is null then
              if base.priv_role(trec.role, priv, lev) then return true; end if;
          end if;
        end loop;
        return false;
    end;
$$;
create operator =* (leftarg = text,rightarg = text,procedure = eqnocase, negator = !=*);
create operator !=* (leftarg = text,rightarg = text,procedure = neqnocase, negator = =*);
create view wm.column_ambig as select
    cu.view_schema	as sch
  , cu.view_name	as tab
  , cu.column_name	as col
  , cn.nat_exp		as spec
  , count(*)		as count
  , array_agg(cu.table_name::varchar order by cu.table_name desc)	as natives
    from		wm.view_column_usage		cu
    join		wm.column_native		cn on cn.cnt_sch = cu.view_schema and cn.cnt_tab = cu.view_name and cn.cnt_col = cu.column_name
    where		view_schema not in ('pg_catalog','information_schema')
    group by		1,2,3,4
    having		count(*) > 1;
create view wm.column_data as select
    n.nspname		as cdt_sch
  , c.relname		as cdt_tab
  , a.attname		as cdt_col
  , a.attnum		as field
  , t.typname		as type
  , na.attnotnull	as nonull		-- notnull of native table
  , pg_get_expr (nd.adbin,nd.adrelid)		as def	--PG 12+

  , case when a.attlen < 0 then null else a.attlen end 	as length
  , coalesce(na.attnum = any((select conkey from pg_constraint
        where connamespace = nc.relnamespace
        and conrelid = nc.oid and contype = 'p')::int4[]),'f') as is_pkey
  , ts.pkey		-- like ispkey, but can be overridden explicitly in the wms file
  , c.relkind		as tab_kind
  , ts.nat_sch
  , ts.nat_tab
  , ts.nat_col
  from			pg_class	c
      join		pg_attribute	a	on a.attrelid =	c.oid
      join		pg_type		t	on t.oid = a.atttypid
      join		pg_namespace	n	on n.oid = c.relnamespace
      left join		wm.column_native ts	on ts.cnt_sch = n.nspname and ts.cnt_tab = c.relname and ts.cnt_col = a.attname
      left join		pg_namespace	nn	on nn.nspname = ts.nat_sch
      left join		pg_class	nc	on nc.relnamespace = nn.oid and nc.relname = ts.nat_tab
      left join		pg_attribute	na	on na.attrelid = nc.oid and na.attname = a.attname
      left join		pg_attrdef	nd	on nd.adrelid = na.attrelid and nd.adnum = na.attnum
  where c.relkind in ('r','v');
;
grant select on table wm.column_data to public;
create view wm.column_istyle as select
    coalesce(cs.cs_sch, zs.cs_sch)		as cs_sch
  , coalesce(cs.cs_tab, zs.cs_tab)		as cs_tab
  , coalesce(cs.cs_sch, zs.cs_sch) || '.' || coalesce(cs.cs_tab, zs.cs_tab)		as cs_obj
  , coalesce(cs.cs_col, zs.cs_col)		as cs_col
  , coalesce(cs.sw_name, zs.sw_name)		as sw_name
  , coalesce(cs.sw_value, zs.sw_value)		as sw_value
  , cs.sw_value					as cs_value
  , zs.nat_sch					as nat_sch
  , zs.nat_tab					as nat_tab
  , zs.nat_col					as nat_col
  , zs.sw_value					as nat_value

  from		wm.column_style  cs
  full join	( select nn.cnt_sch as cs_sch, nn.cnt_tab as cs_tab, nn.cnt_col as cs_col, ns.sw_name, ns.sw_value, nn.nat_sch, nn.nat_tab, nn.nat_col
    from	wm.column_native nn
    join	wm.column_style  ns	on ns.cs_sch = nn.nat_sch and ns.cs_tab = nn.nat_tab and ns.cs_col = nn.nat_col
  )		as		 zs	on zs.cs_sch = cs.cs_sch and zs.cs_tab = cs.cs_tab and zs.cs_col = cs.cs_col and zs.sw_name = cs.sw_name;
create index wm_column_native_x_nat_sch_nat_tab on wm.column_native (nat_sch,nat_tab);
create view wm.fkey_pub as select
    tn.cnt_sch				as tt_sch
  , tn.cnt_tab				as tt_tab
  , tn.cnt_sch || '.' || tn.cnt_tab	as tt_obj
  , tn.cnt_col				as tt_col
  , tn.nat_sch				as tn_sch
  , tn.nat_tab				as tn_tab
  , tn.nat_sch || '.' || tn.nat_tab	as tn_obj
  , tn.nat_col				as tn_col
  , fn.cnt_sch				as ft_sch
  , fn.cnt_tab				as ft_tab
  , fn.cnt_sch || '.' || fn.cnt_tab	as ft_obj
  , fn.cnt_col				as ft_col
  , fn.nat_sch				as fn_sch
  , fn.nat_tab				as fn_tab
  , fn.nat_sch || '.' || fn.nat_tab	as fn_obj
  , fn.nat_col				as fn_col
  , kd.key
  , kd.keys
  , kd.conname
  , case when exists (select * from wm.column_native where cnt_sch = tn.cnt_sch and cnt_tab = tn.cnt_tab and nat_sch = tn.nat_sch and nat_tab = tn.nat_tab and cnt_col != tn.cnt_col and nat_col = kd.kyt_col) then
        tn.cnt_col
    else
        null
    end						as unikey

  from	wm.fkey_data	kd
    join		wm.column_native	tn on tn.nat_sch = kd.kyt_sch and tn.nat_tab = kd.kyt_tab and tn.nat_col = kd.kyt_col
    join		wm.column_native	fn on fn.nat_sch = kd.kyf_sch and fn.nat_tab = kd.kyf_tab and fn.nat_col = kd.kyf_col
  where	not kd.kyt_sch in ('pg_catalog','information_schema');
grant select on table wm.fkey_pub to public;
create view wm.fkeys_data as select
      co.conname				as conname
    , tn.nspname				as kst_sch
    , tc.relname				as kst_tab
    , wm.column_names(co.conrelid,co.conkey)	as kst_cols
    , fn.nspname				as ksf_sch
    , fc.relname				as ksf_tab
    , wm.column_names(co.confrelid,co.confkey)	as ksf_cols
  from			pg_constraint	co 
    join		pg_class	tc on tc.oid = co.conrelid
    join		pg_namespace	tn on tn.oid = tc.relnamespace
    join		pg_class	fc on fc.oid = co.confrelid
    join		pg_namespace	fn on fn.oid = fc.relnamespace
  where co.contype = 'f';
grant select on table wm.fkeys_data to public;
create function wylib.data_tf_notify() returns trigger language plpgsql security definer as $$
    declare
      trec	record;
    begin
      if TG_OP = 'DELETE' then trec = old; else trec = new; end if;
      perform pg_notify('wylib', format('{"target":"data", "component":"%s", "name":"%s", "oper":"%s"}', trec.component, trec.name, TG_OP));
      return null;
    end;
$$;
create table base.ent (
id		text		primary key
  , ent_num	int		not null check(ent_num > 0)
  , ent_type	varchar(1)	not null default 'p' check(ent_type in ('p','o','g','r'))
  , ent_name	text		not null
  , fir_name	text		constraint "!base.ent.CFN" check(case when ent_type != 'p' then fir_name is null end)
  , mid_name	text		constraint "!base.ent.CMN" check(case when fir_name is null then mid_name is null end)
  , pref_name	text		constraint "!base.ent.CPN" check(case when fir_name is null then pref_name is null end)
  , title	text		constraint "!base.ent.CTI" check(case when fir_name is null then title is null end)
  , gender	varchar(1)	constraint "!base.ent.CGN" check(case when ent_type != 'p' then gender is null end)
  , marital	varchar(1)	constraint "!base.ent.CMS" check(case when ent_type != 'p' then marital is null end)
  , ent_cmt	text
  , born_date	date
  , username	text		unique
  , conn_pub	text
  , ent_inact	boolean		not null default false
  , country	varchar(3)	not null default 'US' references base.country on update cascade
  , tax_id	text          , unique(country, tax_id)
  , bank	text
  , _last_addr	int		not null default 0	-- leading '_' makes these invisible to multiview triggers
  , _last_comm	int		not null default 0



    
  , crt_date    timestamptz	not null default current_timestamp
  , mod_date    timestamptz	not null default current_timestamp
  , crt_by      name		not null default session_user references base.ent (username) on update cascade
  , mod_by	name		not null default session_user references base.ent (username) on update cascade

);
create function base.priv_has(priv text, lev int) returns boolean language sql stable as $$
      select base.priv_role(session_user, priv, lev);
$$;
create view wm.column_lang as select
    cd.cdt_sch					as sch
  , cd.cdt_tab					as tab
  , cd.cdt_sch || '.' || cd.cdt_tab		as obj
  , cd.cdt_col					as col
  , cd.nat_sch
  , cd.nat_tab
  , cd.nat_sch || '.' || cd.nat_tab		as nat
  , cd.nat_col
  , (select array_agg(to_jsonb(d)) from (select value, title, help from wm.value_text vt where vt.vt_sch = cd.nat_sch and vt.vt_tab = cd.nat_tab and vt.vt_col = cd.nat_col and vt.language = nt.language order by value) d) as values
  , coalesce(ct.language, nt.language, 'en')	as language
  , coalesce(ct.title, nt.title, cd.cdt_col)	as title
  , coalesce(ct.help, nt.help)			as help
  , cd.cdt_sch in ('pg_catalog','information_schema') as system
  from		wm.column_data cd
    left join	wm.column_text nt	on nt.ct_sch = cd.nat_sch and nt.ct_tab = cd.nat_tab and nt.ct_col = cd.nat_col
    left join	wm.column_text ct	on ct.ct_sch = cd.cdt_sch and ct.ct_tab = cd.cdt_tab and ct.ct_col = cd.cdt_col 	--(No!) and ct.language = nt.language

    where	cd.cdt_col != '_oid'
    and		cd.field >= 0;
grant select on table wm.column_lang to public;
create view wm.column_meta as select
    cd.cdt_sch					as sch
  , cd.cdt_tab					as tab
  , cd.cdt_sch || '.' || cd.cdt_tab		as obj
  , cd.cdt_col					as col
  , cd.field
  , cd.type
  , cd.nonull
  , cd.def
  , cd.length
  , cd.is_pkey
  , cd.pkey
  , cd.nat_sch
  , cd.nat_tab
  , cd.nat_sch || '.' || cd.nat_tab		as nat
  , cd.nat_col
  , (select array_agg(distinct value) from wm.value_text vt where vt.vt_sch = cd.nat_sch and vt.vt_tab = cd.nat_tab and vt.vt_col = cd.nat_col) as values
  , array (select array[sw_name, sw_value] from wm.column_istyle cs where cs.cs_sch = cd.cdt_sch and cs.cs_tab = cd.cdt_tab and cs.cs_col = cd.cdt_col order by sw_name) as styles
  from		wm.column_data cd
    where	cd.cdt_col != '_oid'
    and		cd.field >= 0;
grant select on table wm.column_meta to public;
create view wm.column_pub as select
    cd.cdt_sch					as sch
  , cd.cdt_tab					as tab
  , cd.cdt_sch || '.' || cd.cdt_tab		as obj
  , cd.cdt_col					as col
  , cd.field
  , cd.type
  , cd.nonull
  , cd.def
  , cd.length
  , cd.is_pkey
  , cd.pkey
  , cd.nat_sch
  , cd.nat_tab
  , cd.nat_sch || '.' || cd.nat_tab		as nat
  , cd.nat_col
  , coalesce(vt.language, nt.language, 'en')	as language
  , coalesce(vt.title, nt.title, cd.cdt_col)	as title
  , coalesce(vt.help, nt.help)			as help
  from		wm.column_data cd
    left join	wm.column_text vt	on vt.ct_sch = cd.cdt_sch and vt.ct_tab = cd.cdt_tab and vt.ct_col = cd.cdt_col
    left join	wm.column_text nt	on nt.ct_sch = cd.nat_sch and nt.ct_tab = cd.nat_tab and nt.ct_col = cd.nat_col

    where	cd.cdt_col != '_oid'
    and		cd.field >= 0;
grant select on table wm.column_pub to public;
create function wm.default_native() returns int language plpgsql as $$
    declare
        crec	record;
        nrec	record;
        sname	varchar;
        tname	varchar;
        cnt	int default 0;
    begin
        delete from wm.column_native;
        for crec in select * from wm.column_data where cdt_col != '_oid' and field  >= 0 and cdt_sch not in ('pg_catalog','information_schema') loop

            sname = crec.cdt_sch;
            tname = crec.cdt_tab;
            loop
                select into nrec * from wm.view_column_usage where view_schema = sname and view_name = tname and column_name = crec.cdt_col order by table_name desc limit 1;
                if not found then exit; end if;
                sname = nrec.table_schema;
                tname = nrec.table_name;
            end loop;
            insert into wm.column_native (cnt_sch, cnt_tab, cnt_col, nat_sch, nat_tab, nat_col, pkey, nat_exp) values (crec.cdt_sch, crec.cdt_tab, crec.cdt_col, sname, tname, crec.cdt_col, crec.is_pkey, false);
            cnt = cnt + 1;
        end loop;
        return cnt;
    end;
$$;
create view wm.fkeys_pub as select
    tn.cnt_sch				as tt_sch
  , tn.cnt_tab				as tt_tab
  , tn.cnt_sch || '.' || tn.cnt_tab	as tt_obj
  , tk.kst_cols				as tt_cols
  , tn.nat_sch				as tn_sch
  , tn.nat_tab				as tn_tab
  , tn.nat_sch || '.' || tn.nat_tab	as tn_obj
  , fn.cnt_sch				as ft_sch
  , fn.cnt_tab				as ft_tab
  , fn.cnt_sch || '.' || fn.cnt_tab	as ft_obj
  , tk.ksf_cols				as ft_cols
  , fn.nat_sch				as fn_sch
  , fn.nat_tab				as fn_tab
  , fn.nat_sch || '.' || fn.nat_tab	as fn_obj
  , tk.conname
  from	wm.fkeys_data		tk
    join		wm.column_native	tn on tn.nat_sch = tk.kst_sch and tn.nat_tab = tk.kst_tab and tn.nat_col = tk.kst_cols[1]
    join		wm.column_native	fn on fn.nat_sch = tk.ksf_sch and fn.nat_tab = tk.ksf_tab and fn.nat_col = tk.ksf_cols[1]
  where	not tk.kst_sch in ('pg_catalog','information_schema');
grant select on table wm.fkeys_pub to public;
create view wm.table_data as select
    ns.nspname				as td_sch
  , cl.relname				as td_tab
  , ns.nspname || '.' || cl.relname	as obj
  , cl.relkind				as tab_kind

  , coalesce(ci.indisprimary,false)	as has_pkey		-- PG 12+
  , cl.relnatts				as cols
  , ns.nspname in ('pg_catalog','information_schema') as system
  , kd.pkey
  from		pg_class	cl
  join		pg_namespace	ns	on cl.relnamespace = ns.oid
  left join	(select cdt_sch,cdt_tab,array_agg(cdt_col) as pkey from (select cdt_sch,cdt_tab,cdt_col,field from wm.column_data where pkey order by 1,2,4) sq group by 1,2) kd on kd.cdt_sch = ns.nspname and kd.cdt_tab = cl.relname
  left join	pg_index	ci	on ci.indrelid = cl.oid and ci.indisprimary
  where		cl.relkind in ('r','v');
create table base.addr (
addr_ent	text		references base.ent on update cascade on delete cascade
  , addr_seq	int	      , primary key (addr_ent, addr_seq)
  , addr_spec	text		not null
  , addr_type	text		not null check(addr_type in ('phys','mail','bill','ship'))
  , addr_prim	boolean		not null default false constraint "!base.addr.CPA" check(case when addr_inact is true then addr_prim is false end)
  , addr_cmt	text
  , addr_inact	boolean		not null default false
  , city	text
  , state	text
  , pcode	text
  , country	varchar(3)	constraint "!base.addr.CCO" not null default 'US' references base.country on update cascade
  , unique (addr_ent, addr_seq, addr_type)		-- Needed for addr_prim FK to work

    
  , crt_date    timestamptz	not null default current_timestamp
  , mod_date    timestamptz	not null default current_timestamp
  , crt_by      name		not null default session_user references base.ent (username) on update cascade
  , mod_by	name		not null default session_user references base.ent (username) on update cascade

);
create table base.comm (
comm_ent	text		references base.ent on update cascade on delete cascade
  , comm_seq	int	      , primary key (comm_ent, comm_seq)
  , comm_spec	text
  , comm_type	text		not null check(comm_type in ('phone','email','cell','fax','text','web','pager','other'))
  , comm_prim	boolean		not null default false constraint "!base.comm.CPC" check(case when comm_inact is true then comm_prim is false end)
  , comm_cmt	text
  , comm_inact	boolean		not null default false
  , unique (comm_ent, comm_seq, comm_type)		-- Needed for comm_prim FK to work

    
  , crt_date    timestamptz	not null default current_timestamp
  , mod_date    timestamptz	not null default current_timestamp
  , crt_by      name		not null default session_user references base.ent (username) on update cascade
  , mod_by	name		not null default session_user references base.ent (username) on update cascade

);
create function base.curr_eid() returns text language sql security definer stable as $$
    select id from base.ent where username = session_user;
$$;
create table base.ent_audit (
id text
          , a_seq	int		check (a_seq >= 0)
          , a_date	timestamptz	not null default current_timestamp
          , a_by	name		not null default session_user references base.ent (username) on update cascade
          , a_action	audit_type	not null default 'update'
          , a_column	varchar		not null
          , a_value	varchar
     	  , a_reason	text
          , primary key (id,a_seq)
);
select wm.create_role('glman_3');
grant select on table base.ent_audit to glman_3;
create table base.ent_link (
org		text		references base.ent on update cascade
  , mem		text		references base.ent on update cascade on delete cascade
  , primary key (org, mem)
  , role	text
  , supr_path	text[]		-- other modules (like empl) are responsible to maintain this cached field
    
  , crt_date    timestamptz	not null default current_timestamp
  , mod_date    timestamptz	not null default current_timestamp
  , crt_by      name		not null default session_user references base.ent (username) on update cascade
  , mod_by	name		not null default session_user references base.ent (username) on update cascade

);
create function base.ent_tf_dacc() returns trigger language plpgsql as $$
    begin
        if old.username is not null then
            execute 'drop user if exists ' || old.username;
        end if;
        return old;
    end;
$$;
create function base.ent_tf_id() returns trigger language plpgsql as $$
    declare
      min_num	int;
    begin
      if new.ent_num is null then
        lock table base.ent;
        min_num = case when new.ent_type = 'p' then 1000
                       when new.ent_type = 'g' then 100
                       when new.ent_type = 'o' then 500
                       else 1 end;
        select into new.ent_num coalesce(max(ent_num)+1,min_num) from base.ent where ent_type = new.ent_type and ent_num >= min_num;
      end if;
      new.id = new.ent_type || new.ent_num::text;  



      return new;
    end;
$$;
create function base.ent_tf_iuacc() returns trigger language plpgsql security definer as $$
    declare
      trec	record;
    begin
      if new.username is null then		-- Can't have connection access without a username
        new.conn_pub = null;
      end if;
      if TG_OP = 'UPDATE' then			-- if trying to modify an existing username
        if new.username is distinct from old.username then
          if new.username is null then		-- Don't leave relational privs stranded
            delete from base.priv where grantee = old.username;
          end if;
          if old.username is not null then
            execute 'drop user if exists ' || '"' || old.username || '"';
          end if;
        end if;
      end if;

      if new.username is not null and not exists (select usename from pg_shadow where usename = new.username) then

        execute 'create user ' || '"' || new.username || '"';
        for trec in select * from base.priv where grantee = new.username loop
          execute 'grant "' || trec.priv_level || '" to ' || trec.grantee;
        end loop;
      end if;
      return new;
    end;
$$;
create view base.ent_v as select e.id, e.ent_num, e.conn_pub, e.ent_name, e.ent_type, e.ent_cmt, e.fir_name, e.mid_name, e.pref_name, e.title, e.gender, e.marital, e.born_date, e.username, e.ent_inact, e.country, e.tax_id, e.bank, e.crt_by, e.mod_by, e.crt_date, e.mod_date
      , case when e.fir_name is null then e.ent_name else e.ent_name || ', ' || coalesce(e.pref_name,e.fir_name) end	as std_name
      , e.ent_name || case when e.fir_name is not null then ', ' || 
                case when e.title is null then '' else e.title || ' ' end ||
                e.fir_name ||
                case when e.mid_name is null then '' else ' ' || e.mid_name end
            else '' end												as frm_name
      , case when e.fir_name is null then '' else coalesce(e.pref_name,e.fir_name) || ' ' end || e.ent_name	as cas_name
      , e.fir_name || case when e.mid_name is null then '' else ' ' || e.mid_name end				as giv_name	
      , extract(year from age(e.born_date))									as age
    from	base.ent	e;

    ;
    ;
    create rule base_ent_v_delete as on delete to base.ent_v
        do instead delete from base.ent where id = old.id;
select wm.create_role('ent_1');
grant select on table base.ent_v to ent_1;
select wm.create_role('ent_2');
grant insert on table base.ent_v to ent_2;
grant update on table base.ent_v to ent_2;
select wm.create_role('ent_3');
grant delete on table base.ent_v to ent_3;
create index base_ent_x_ent_type_ent_num on base.ent (ent_type,ent_num);
create index base_ent_x_username on base.ent (username);
create table base.parm (
module	text
  , parm	text
  , primary key (module, parm)
  , type	text		check (type in ('int','date','text','float','boolean'))
  , cmt		text
  , v_int	int		check (type = 'int' and v_int is not null or type != 'int' and v_int is null)
  , v_date	date		check (type = 'date' and v_date is not null or type != 'date' and v_date is null)
  , v_text	text		check (type = 'text' and v_text is not null or type != 'text' and v_text is null)
  , v_float	float		check (type = 'float' and v_float is not null or type != 'float' and v_float is null)
  , v_boolean	boolean		check (type = 'boolean' and v_boolean is not null or type != 'boolean' and v_boolean is null)
    
  , crt_date    timestamptz	not null default current_timestamp
  , mod_date    timestamptz	not null default current_timestamp
  , crt_by      name		not null default session_user references base.ent (username) on update cascade
  , mod_by	name		not null default session_user references base.ent (username) on update cascade

);
create table base.priv (
grantee	text		references base.ent (username) on update cascade on delete cascade
  , priv	text	      , primary key (grantee, priv)
  , level	int		constraint "!base.priv.CLV" check(level > 0 and level < 10)
  , priv_level	text		not null
  , cmt		text
);
create table base.token (
token_ent	text		references base.ent on update cascade on delete cascade
  , token_seq	int	      , primary key (token_ent, token_seq)
  , token	text		not null unique
  , allows	varchar(8)	not null
  , used	timestamp
  , expires	timestamp(0)	default current_timestamp + '30 minutes'
    
  , crt_date    timestamptz	not null default current_timestamp
  , mod_date    timestamptz	not null default current_timestamp
  , crt_by      name		not null default session_user references base.ent (username) on update cascade
  , mod_by	name		not null default session_user references base.ent (username) on update cascade

);
create function base.user_id(text) returns text language sql security definer stable as $$
    select id from base.ent where username = $1;
$$;
create function base.username(text) returns text language sql security definer stable as $$
    select username from base.ent where id = $1;
$$;
create view wm.column_def as select obj, col, 
    case when def is not null then
      'coalesce($1.' || quote_ident(col) || ',' || def || ') as ' || quote_ident(col)
    else
      '$1.' || col || ' as ' || quote_ident(col)
    end as val
  from wm.column_pub order by obj, field;
create function wm.init_dictionary() returns boolean language plpgsql as $$
    declare
      trec	record;
      s		varchar;
      tarr	varchar[];
      oarr	varchar[];
      narr	varchar[];
    begin
      perform wm.default_native();
      for trec in select * from wm.objects where obj_typ = 'view' loop
        foreach s in array trec.col_data loop		-- Overlay user specified natives
          tarr = string_to_array(s,',');
          if tarr[1] != 'nat' then continue; end if;

          oarr = string_to_array(trec.obj_nam,'.');
          narr = string_to_array(tarr[3],'.');
          update wm.column_native set nat_sch = narr[1], nat_tab = narr[2], nat_col = tarr[4], nat_exp = true where cnt_sch = oarr[1] and cnt_tab = oarr[2] and cnt_col = tarr[2];
        end loop;
      end loop;

      for trec in select cdt_sch,cdt_tab,cdt_col from wm.column_data where is_pkey and cdt_col != '_oid' and field >= 0 order by 1,2 loop
        update wm.column_native set pkey = true where cnt_sch = trec.cdt_sch and cnt_tab = trec.cdt_tab and cnt_col = trec.cdt_col;
      end loop;
      
      for trec in select * from wm.objects where obj_typ = 'view' loop
        tarr = string_to_array(trec.col_data[1],',');
        if tarr[1] = 'pri' then			
          tarr = tarr[2:array_upper(tarr,1)];

          oarr = string_to_array(trec.obj_nam,'.');
          update wm.column_native set pkey = (cnt_col = any(tarr)) where cnt_sch = oarr[1] and cnt_tab = oarr[2];
        end if;
      end loop;
      return true;
    end;
  $$;
create view wm.table_lang as select
    td.td_sch				as sch
  , td.td_tab				as tab
  , td.td_sch || '.' || td.td_tab	as obj
  , tt.language
  , tt.title
  , tt.help
  , array (select jsonb_object(array['code', code, 'title', title, 'help', help]) from wm.message_text mt where mt.mt_sch = td.td_sch and mt.mt_tab = td.td_tab and mt.language = tt.language order by code) as messages
  , (select array_agg(to_jsonb(d)) from (select col, title, help, values from wm.column_lang cl where cl.sch = td.td_sch and cl.tab = td.td_tab and cl.language = tt.language) d) as columns
  from		wm.table_data		td
  left join	wm.table_text		tt on td.td_sch = tt.tt_sch and td.td_tab = tt.tt_tab;
grant select on table wm.table_lang to public;
create view wm.table_meta as select
    td.td_sch				as sch
  , td.td_tab				as tab
  , td.td_sch || '.' || td.td_tab	as obj
  , td.tab_kind
  , td.has_pkey
  , td.system
  , to_jsonb(td.pkey)			as pkey
  , td.cols
  , (select jsonb_object_agg(sw_name,sw_value::jsonb) from wm.table_style ts where ts.ts_sch = td.td_sch and ts.ts_tab = td.td_tab) as styles
  , (select array_agg(to_jsonb(d)) from (select col, field, type, nonull, length, pkey, to_jsonb(values) as values, jsonb_object(styles) as styles from wm.column_meta cm where cm.sch = td.td_sch and cm.tab = td.td_tab) d) as columns
  , (select array_agg(to_jsonb(d)) from (select ft_sch || '.' || ft_tab as "table", to_jsonb(tt_cols) as columns, to_jsonb(ft_cols) as foreign from wm.fkeys_pub ks where ks.tt_sch = td.td_sch and ks.tt_tab = td.td_tab) d) as fkeys
  from		wm.table_data		td;
grant select on table wm.table_meta to public;
create view wm.table_pub as select
    td.td_sch				as sch
  , td.td_tab				as tab
  , td.td_sch || '.' || td.td_tab	as obj
  , td.tab_kind
  , td.has_pkey
  , td.pkey
  , td.cols
  , td.system
  , tt.language
  , tt.title
  , tt.help
  from		wm.table_data		td
  left join	wm.table_text		tt on td.td_sch = tt.tt_sch and td.td_tab = tt.tt_tab;
;
grant select on table wm.table_pub to public;
create table base.addr_prim (
prim_ent	text
  , prim_seq	int
  , prim_type	text
  , primary key (prim_ent, prim_seq, prim_type)
  , constraint addr_prim_prim_ent_fk foreign key (prim_ent, prim_seq, prim_type) references base.addr (addr_ent, addr_seq, addr_type)
    on update cascade on delete cascade deferrable
);
create function base.addr_tf_aiud() returns trigger language plpgsql security definer as $$
    begin
        insert into base.addr_prim (prim_ent, prim_seq, prim_type) 
            select addr_ent,max(addr_seq),addr_type from base.addr where not addr_inact and not exists (select * from base.addr_prim cp where cp.prim_ent = addr_ent and cp.prim_type = addr_type) group by 1,3;
        return old;
    end;
$$;
create function base.addr_tf_bd() returns trigger language plpgsql security definer as $$
    begin
        perform base.addr_remove_prim(old.addr_ent, old.addr_seq, old.addr_type);
        return old;
    end;
$$;
create function base.addr_tf_bi() returns trigger language plpgsql security definer as $$
    begin
        if new.addr_seq is null then			-- Generate unique sequence for new address entry
            update base.ent set _last_addr = greatest(coalesce(_last_addr,0) + 1,
              (select coalesce(max(addr_seq),0)+1 from base.addr where addr_ent = new.addr_ent)
            ) where id = new.addr_ent returning _last_addr into new.addr_seq;
            if not found then new.addr_seq = 1; end if;

        end if;
        if new.addr_inact then				-- Can't be primary if inactive
            new.addr_prim = false;
        elsif not exists (select addr_seq from base.addr where addr_ent = new.addr_ent and addr_type = new.addr_type) then
            new.addr_prim = true;
        end if;
        if new.addr_prim then				-- If this is primary, all others are now not
            set constraints base.addr_prim_prim_ent_fk deferred;
            perform base.addr_make_prim(new.addr_ent, new.addr_seq, new.addr_type);
        end if;
        new.addr_prim = false;
        return new;
    end;
$$;
create function base.addr_tf_bu() returns trigger language plpgsql security definer as $$
    declare
        prim_it		boolean;
    begin
        if new.addr_inact or (not new.addr_prim and old.addr_prim) then	-- Can't be primary if inactive
            prim_it = false;
        elsif new.addr_prim and not old.addr_prim then
            prim_it = true;
        end if;

        if prim_it then
            perform base.addr_make_prim(new.addr_ent, new.addr_seq, new.addr_type);
        elsif not prim_it then
            perform base.addr_remove_prim(new.addr_ent, new.addr_seq, new.addr_type);
        end if;
        new.addr_prim = false;
        return new;
    end;
$$;
create view base.addr_v_flat as select e.id, a0.addr_spec as "phys_addr", a0.city as "phys_city", a0.state as "phys_state", a0.pcode as "phys_pcode", a0.country as "phys_country", a1.addr_spec as "mail_addr", a1.city as "mail_city", a1.state as "mail_state", a1.pcode as "mail_pcode", a1.country as "mail_country", a2.addr_spec as "bill_addr", a2.city as "bill_city", a2.state as "bill_state", a2.pcode as "bill_pcode", a2.country as "bill_country", a3.addr_spec as "ship_addr", a3.city as "ship_city", a3.state as "ship_state", a3.pcode as "ship_pcode", a3.country as "ship_country" from base.ent e left join base.addr a0 on a0.addr_ent = e.id and a0.addr_type = 'phys' and a0.addr_prim left join base.addr a1 on a1.addr_ent = e.id and a1.addr_type = 'mail' and a1.addr_prim left join base.addr a2 on a2.addr_ent = e.id and a2.addr_type = 'bill' and a2.addr_prim left join base.addr a3 on a3.addr_ent = e.id and a3.addr_type = 'ship' and a3.addr_prim;
create index base_addr_x_addr_type on base.addr (addr_type);
create table base.comm_prim (
prim_ent	text
  , prim_seq	int
  , prim_type	text
  , primary key (prim_ent, prim_seq, prim_type)
  , constraint comm_prim_prim_ent_fk foreign key (prim_ent, prim_seq, prim_type) references base.comm (comm_ent, comm_seq, comm_type)
    on update cascade on delete cascade deferrable
);
create function base.comm_tf_aiud() returns trigger language plpgsql security definer as $$
    begin
        insert into base.comm_prim (prim_ent, prim_seq, prim_type) 
            select comm_ent,max(comm_seq),comm_type from base.comm where not comm_inact and not exists (select * from base.comm_prim cp where cp.prim_ent = comm_ent and cp.prim_type = comm_type) group by 1,3;
        return old;
    end;
$$;
create function base.comm_tf_bd() returns trigger language plpgsql security definer as $$
    begin
        perform base.comm_remove_prim(old.comm_ent, old.comm_seq, old.comm_type);
        return old;
    end;
$$;
create function base.comm_tf_bi() returns trigger language plpgsql security definer as $$
    begin
        if new.comm_seq is null then			-- Generate unique sequence for new communication entry
            update base.ent set _last_comm = greatest(coalesce(_last_comm,0) + 1,
              (select coalesce(max(comm_seq),0)+1 from base.comm where comm_ent = new.comm_ent)
            ) where id = new.comm_ent returning _last_comm into new.comm_seq;
            if not found then new.comm_seq = 1; end if;

        end if;
        if new.comm_inact then				-- Can't be primary if inactive
            new.comm_prim = false;
        elsif not exists (select comm_seq from base.comm where comm_ent = new.comm_ent and comm_type = new.comm_type) then
            new.comm_prim = true;
        end if;
        if new.comm_prim then				-- If this is primary, all others are now not
            set constraints base.comm_prim_prim_ent_fk deferred;
            perform base.comm_make_prim(new.comm_ent, new.comm_seq, new.comm_type);
        end if;
        new.comm_prim = false;
        return new;
    end;
$$;
create function base.comm_tf_bu() returns trigger language plpgsql security definer as $$
    declare
        prim_it		boolean;
    begin
        if new.comm_inact or (not new.comm_prim and old.comm_prim) then	-- Can't be primary if inactive
            prim_it = false;
        elsif new.comm_prim and not old.comm_prim then
            prim_it = true;
        end if;

        if prim_it then
            perform base.comm_make_prim(new.comm_ent, new.comm_seq, new.comm_type);
        elsif not prim_it then
            perform base.comm_remove_prim(new.comm_ent, new.comm_seq, new.comm_type);
        end if;
        new.comm_prim = false;
        return new;
    end;
$$;
create view base.comm_v_flat as select e.id, c0.comm_spec as "phone_comm", c1.comm_spec as "email_comm", c2.comm_spec as "cell_comm", c3.comm_spec as "fax_comm", c4.comm_spec as "text_comm", c5.comm_spec as "web_comm", c6.comm_spec as "pager_comm", c7.comm_spec as "other_comm" from base.ent e left join base.comm c0 on c0.comm_ent = e.id and c0.comm_type = 'phone' and c0.comm_prim left join base.comm c1 on c1.comm_ent = e.id and c1.comm_type = 'email' and c1.comm_prim left join base.comm c2 on c2.comm_ent = e.id and c2.comm_type = 'cell' and c2.comm_prim left join base.comm c3 on c3.comm_ent = e.id and c3.comm_type = 'fax' and c3.comm_prim left join base.comm c4 on c4.comm_ent = e.id and c4.comm_type = 'text' and c4.comm_prim left join base.comm c5 on c5.comm_ent = e.id and c5.comm_type = 'web' and c5.comm_prim left join base.comm c6 on c6.comm_ent = e.id and c6.comm_type = 'pager' and c6.comm_prim left join base.comm c7 on c7.comm_ent = e.id and c7.comm_type = 'other' and c7.comm_prim;
create index base_comm_x_comm_spec on base.comm (comm_spec);
create index base_comm_x_comm_type on base.comm (comm_type);
create function base.ent_audit_tf_bi() --Call when a new audit record is generated
          returns trigger language plpgsql security definer as $$
            begin
                if new.a_seq is null then		--Generate unique audit sequence number
                    select into new.a_seq coalesce(max(a_seq)+1,0) from base.ent_audit where id = new.id;
                end if;
                return new;
            end;
        $$;
create index base_ent_audit_x_a_column on base.ent_audit (a_column);
create function base.ent_link_tf_check() returns trigger language plpgsql security definer as $$
    declare
        erec	record;
        mrec	record;
    begin
        select into erec * from base.ent where id = new.org;
        
        if erec.ent_type = 'g' then
            return new;
        end if;
        if erec.ent_type = 'p' then
            raise exception '!base.ent_link.NBP % %', new.mem, new.org;
        end if;

        select into mrec * from base.ent where id = new.mem;
        if erec.ent_type = 'c' and mrec.ent_type != 'p' then
            raise exception '!base.ent_link.PBC % %', new.mem, new.org;
        end if;
        return new;
    end;
$$;
create view base.ent_link_v as select el.org, el.mem, el.role, el.supr_path, el.crt_by, el.mod_by, el.crt_date, el.mod_date
      , oe.std_name		as org_name
      , me.std_name		as mem_name
    from	base.ent_link	el
    join	base.ent_v	oe on oe.id = el.org
    join	base.ent_v	me on me.id = el.mem;

    create rule base_ent_link_v_insert as on insert to base.ent_link_v
        do instead insert into base.ent_link (org, mem, role, crt_by, mod_by, crt_date, mod_date) values (new.org, new.mem, new.role, session_user, session_user, current_timestamp, current_timestamp);
    create rule base_ent_link_v_update as on update to base.ent_link_v
        do instead update base.ent_link set role = new.role, mod_by = session_user, mod_date = current_timestamp where org = old.org and mem = old.mem;
    create rule base_ent_link_v_delete as on delete to base.ent_link_v
        do instead delete from base.ent_link where org = old.org and mem = old.mem;
grant select on table base.ent_link_v to ent_1;
grant insert on table base.ent_link_v to ent_2;
grant update on table base.ent_link_v to ent_2;
grant delete on table base.ent_link_v to ent_2;
create function base.ent_tf_audit_d() --Call when a record is deleted in the audited table
          returns trigger language plpgsql security definer as $$
            begin
                insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'delete','ent_name',old.ent_name::varchar);
		insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'delete','ent_type',old.ent_type::varchar);
		insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'delete','ent_cmt',old.ent_cmt::varchar);
		insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'delete','fir_name',old.fir_name::varchar);
		insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'delete','mid_name',old.mid_name::varchar);
		insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'delete','pref_name',old.pref_name::varchar);
		insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'delete','title',old.title::varchar);
		insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'delete','gender',old.gender::varchar);
		insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'delete','marital',old.marital::varchar);
		insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'delete','born_date',old.born_date::varchar);
		insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'delete','username',old.username::varchar);
		insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'delete','ent_inact',old.ent_inact::varchar);
		insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'delete','country',old.country::varchar);
		insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'delete','tax_id',old.tax_id::varchar);
		insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'delete','bank',old.bank::varchar);
                return old;
            end;
        $$;
create function base.ent_tf_audit_u() --Call when a record is updated in the audited table
          returns trigger language plpgsql security definer as $$
            begin
                if new.ent_name is distinct from old.ent_name then insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'update','ent_name',old.ent_name::varchar); end if;
		if new.ent_type is distinct from old.ent_type then insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'update','ent_type',old.ent_type::varchar); end if;
		if new.ent_cmt is distinct from old.ent_cmt then insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'update','ent_cmt',old.ent_cmt::varchar); end if;
		if new.fir_name is distinct from old.fir_name then insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'update','fir_name',old.fir_name::varchar); end if;
		if new.mid_name is distinct from old.mid_name then insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'update','mid_name',old.mid_name::varchar); end if;
		if new.pref_name is distinct from old.pref_name then insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'update','pref_name',old.pref_name::varchar); end if;
		if new.title is distinct from old.title then insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'update','title',old.title::varchar); end if;
		if new.gender is distinct from old.gender then insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'update','gender',old.gender::varchar); end if;
		if new.marital is distinct from old.marital then insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'update','marital',old.marital::varchar); end if;
		if new.born_date is distinct from old.born_date then insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'update','born_date',old.born_date::varchar); end if;
		if new.username is distinct from old.username then insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'update','username',old.username::varchar); end if;
		if new.ent_inact is distinct from old.ent_inact then insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'update','ent_inact',old.ent_inact::varchar); end if;
		if new.country is distinct from old.country then insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'update','country',old.country::varchar); end if;
		if new.tax_id is distinct from old.tax_id then insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'update','tax_id',old.tax_id::varchar); end if;
		if new.bank is distinct from old.bank then insert into base.ent_audit (id,a_date,a_by,a_action,a_column,a_value) values (old.id,transaction_timestamp(),session_user,'update','bank',old.bank::varchar); end if;
                return new;
            end;
        $$;
create trigger base_ent_tr_dacc -- do after individual grants are deleted
    after delete on base.ent for each row execute procedure base.ent_tf_dacc();
create trigger base_ent_tr_id before insert or update on base.ent for each row execute procedure base.ent_tf_id();
create trigger base_ent_tr_iuacc before insert or update on base.ent for each row execute procedure base.ent_tf_iuacc();
create function base.ent_v_insfunc() returns trigger language plpgsql security definer as $$
  declare
    trec record;
    str  varchar;
  begin
    execute 'select string_agg(val,'','') from wm.column_def where obj = $1;' into str using 'base.ent_v';
    execute 'select ' || str || ';' into trec using new;
    insert into base.ent (ent_name,ent_type,ent_cmt,fir_name,mid_name,pref_name,title,gender,marital,born_date,username,ent_inact,country,tax_id,bank,crt_by,mod_by,crt_date,mod_date) values (trec.ent_name,trec.ent_type,trec.ent_cmt,trec.fir_name,trec.mid_name,trec.pref_name,trec.title,trec.gender,trec.marital,trec.born_date,trec.username,trec.ent_inact,trec.country,trec.tax_id,trec.bank,session_user,session_user,current_timestamp,current_timestamp) returning id into new.id;
    select into new * from base.ent_v where id = new.id;
    return new;
  end;
$$;
create view base.ent_v_pub as select id, std_name, ent_type, ent_num, username, ent_inact, crt_by, mod_by, crt_date, mod_date from base.ent_v;
grant select on table base.ent_v_pub to public;
create function base.ent_v_updfunc() returns trigger language plpgsql security definer as $$
  begin
    update base.ent set ent_name = new.ent_name,ent_cmt = new.ent_cmt,fir_name = new.fir_name,mid_name = new.mid_name,pref_name = new.pref_name,title = new.title,gender = new.gender,marital = new.marital,born_date = new.born_date,username = new.username,ent_inact = new.ent_inact,country = new.country,tax_id = new.tax_id,bank = new.bank,mod_by = session_user,mod_date = current_timestamp where id = old.id returning id into new.id;
    select into new * from base.ent_v where id = new.id;
    return new;
  end;
$$;
create table base.parm_audit (
module text,parm text
          , a_seq	int		check (a_seq >= 0)
          , a_date	timestamptz	not null default current_timestamp
          , a_by	name		not null default session_user references base.ent (username) on update cascade
          , a_action	audit_type	not null default 'update'
          , a_column	varchar		not null
          , a_value	varchar
     	  , a_reason	text
          , primary key (module,parm,a_seq)
);
grant select on table base.parm_audit to glman_3;
create function base.parm_boolean(m text, p text) returns boolean language plpgsql stable as $$
    declare
        r	record;
    begin
        select into r * from base.parm where module = m and parm = p and type = 'boolean';

        if not found then return null; end if;
        return r.v_boolean;
    end;
$$;
create function base.parm_date(m text, p text) returns date language plpgsql stable as $$
    declare
        r	record;
    begin
        select into r * from base.parm where module = m and parm = p and type = 'date';

        if not found then return null; end if;
        return r.v_date;
    end;
$$;
create function base.parm_float(m text, p text) returns float language plpgsql stable as $$
    declare
        r	record;
    begin
        select into r * from base.parm where module = m and parm = p and type = 'float';

        if not found then return null; end if;
        return r.v_float;
    end;
$$;
create function base.parm_int(m text, p text) returns int language plpgsql stable as $$
    declare
        r	record;
    begin
        select into r * from base.parm where module = m and parm = p and type = 'int';

        if not found then return null; end if;
        return r.v_int;
    end;
$$;
create function base.parm(m text, p text, d anyelement) returns anyelement language plpgsql stable as $$
    declare
        r	record;
    begin
        select into r * from base.parm where module = m and parm = p;
        if not found then return d; end if;
        case when r.type = 'int'	then return r.v_int;
             when r.type = 'date'	then return r.v_date;
             when r.type = 'text'	then return r.v_text;
             when r.type = 'float'	then return r.v_float;
             when r.type = 'boolean'	then return r.v_boolean;
        end case;
    end;
$$;
create function base.parm_text(m text, p text) returns text language plpgsql stable as $$
    declare
        r	record;
    begin
        select into r * from base.parm where module = m and parm = p and type = 'text';

        if not found then return null; end if;
        return r.v_text;
    end;
$$;
create view base.parm_v as select module, parm, type, cmt, crt_by, mod_by, crt_date, mod_date
  , case when type = 'int'	then v_int::text
         when type = 'date'	then norm_date(v_date)
         when type = 'text'	then v_text
         when type = 'float'	then v_float::text
         when type = 'boolean'	then norm_bool(v_boolean)
    end as value
    from base.parm;
select wm.create_role('glman_1');
grant select on table base.parm_v to glman_1;
select wm.create_role('glman_2');
grant update on table base.parm_v to glman_2;
grant insert on table base.parm_v to glman_3;
grant delete on table base.parm_v to glman_3;
create function base.priv_grants() returns int language plpgsql as $$
    declare
        erec	record;
        trec	record;
        cnt	int default 0;
    begin
        for erec in select * from base.ent where username is not null loop

            if not exists (select usename from pg_shadow where usename = erec.username) then
                execute 'create user ' || erec.username;
            end if;
            for trec in select * from base.priv where grantee = erec.username loop
                execute 'grant "' || trec.priv_level || '" to ' || trec.grantee;
                cnt := cnt + 1;
            end loop;
        end loop;
        return cnt;
    end;
$$;
create function base.priv_tf_dgrp() returns trigger security definer language plpgsql as $$
    begin
        execute 'revoke "' || old.priv_level || '" from ' || old.grantee;
        return old;
    end;
$$;
create function base.priv_tf_iugrp() returns trigger security definer language plpgsql as $$
    begin
        if new.level is null then		-- cache concatenated version of priv name
          new.priv_level = new.priv;
        else
          new.priv_level = new.priv || '_' || new.level;
        end if;
        
        if TG_OP = 'UPDATE' then
            if new.grantee != old.grantee or new.priv != old.priv or new.level is distinct from old.level then
                execute 'revoke "' || old.priv_level || '" from ' || old.grantee;
            end if;
        end if;

        execute 'grant "' || new.priv_level || '" to ' || new.grantee;
        return new;
    end;
$$;
create view base.priv_v as select p.grantee, p.priv, p.level, p.cmt, p.priv_level
  , e.std_name
  , e.username
  , g.priv_list

    from	base.priv	p
    join	base.ent_v	e on e.username = p.grantee
    left join	(select member,array_agg(role) as priv_list from wm.role_members group by 1) g on g.member = p.grantee;

    ;
    ;
    create rule base_priv_v_delete as on delete to base.priv_v
        do instead delete from base.priv where grantee = old.grantee and priv = old.priv;
grant select on table base.priv_v to public;
select wm.create_role('privedit_1');
grant select on table base.priv_v to privedit_1;
select wm.create_role('privedit_2');
grant insert on table base.priv_v to privedit_2;
grant update on table base.priv_v to privedit_2;
grant delete on table base.priv_v to privedit_2;
create function base.std_name(name) returns text language sql security definer stable as $$
    select std_name from base.ent_v where username = $1;
$$;
create function base.std_name(text) returns text language sql security definer stable as $$
    select std_name from base.ent_v where id = $1;
$$;
create function base.token_tf_seq() returns trigger security definer language plpgsql as $$
    begin
      if new.token_seq is null then	-- not technically safe for concurrency, but we should really only have one token being created at a time anyway
        select into new.token_seq coalesce(max(token_seq),0)+1 from base.token where token_ent = new.token_ent;
      end if;
      if new.token is null then				-- If no token specified
        loop
          select into new.token md5(random()::text);
          if not exists (select token from base.token where token = new.token) then
            exit;
          end if;
        end loop;
      end if;
      return new;
    end;
$$;
create view base.token_v as select t.token_ent, t.token_seq, t.token, t.allows, t.used, t.expires, t.crt_by, t.mod_by, t.crt_date, t.mod_date
      , t.expires <= current_timestamp as "expired"
      , t.expires > current_timestamp and used is null as "valid"
      , e.username
      , e.std_name

    from	base.token	t
    join	base.ent_v	e	on e.id = t.token_ent

    ;
create table wylib.data (
ruid	serial primary key
  , component	text
  , name	text
  , descr	text
  , access	varchar(5)	not null default 'read' constraint "!wylib.data.IAT" check (access in ('priv', 'read', 'write'))
  , owner	text		not null default base.curr_eid() references base.ent on update cascade on delete cascade
  , data	jsonb
    
  , crt_date    timestamptz	not null default current_timestamp
  , mod_date    timestamptz	not null default current_timestamp
  , crt_by      name		not null default session_user references base.ent (username) on update cascade
  , mod_by	name		not null default session_user references base.ent (username) on update cascade

);
create function base.addr_make_prim(ent text, seq int, typ text) returns void language plpgsql security definer as $$
    begin

        update base.addr_prim set prim_seq = seq where prim_ent = ent and prim_type = typ;
        if not found then
            insert into base.addr_prim (prim_ent,prim_seq,prim_type) values (ent,seq,typ);
        end if;
    end;
$$;
create function base.addr_remove_prim(ent text, seq int, typ text) returns void language plpgsql security definer as $$
    declare
        prim_rec	record;
        addr_rec	record;
    begin

        select * into prim_rec from base.addr_prim where prim_ent = ent and prim_seq = seq and prim_type = typ;
        if found then			-- If the addr we are deleting was a primary, find the next latest record
            select * into addr_rec from base.addr where addr_ent = prim_rec.prim_ent and addr_type = prim_rec.prim_type and addr_seq != seq and not addr_inact order by addr_seq desc limit 1;
            if found then		-- And make it the new primary

                update base.addr_prim set prim_seq = addr_rec.addr_seq where prim_ent = addr_rec.addr_ent and prim_type = addr_rec.addr_type;
            else

                delete from base.addr_prim where prim_ent = ent and prim_seq = seq and prim_type = typ;
            end if;
        else

        end if;
    end;
$$;
create trigger base_addr_tr_aiud after insert or update or delete on base.addr for each statement execute procedure base.addr_tf_aiud();
create trigger base_addr_tr_bd before delete on base.addr for each row execute procedure base.addr_tf_bd();
create trigger base_addr_tr_bi before insert on base.addr for each row execute procedure base.addr_tf_bi();
create trigger base_addr_tr_bu before update on base.addr for each row execute procedure base.addr_tf_bu();
create view base.addr_v as select a.addr_ent, a.addr_seq, a.addr_spec, a.city, a.state, a.pcode, a.country, a.addr_cmt, a.addr_type, a.addr_inact, a.crt_by, a.mod_by, a.crt_date, a.mod_date
      , oe.std_name
      , ap.prim_seq is not null and ap.prim_seq = a.addr_seq	as addr_prim

    from	base.addr	a
    join	base.ent_v	oe	on oe.id = a.addr_ent
    left join	base.addr_prim	ap	on ap.prim_ent = a.addr_ent and ap.prim_type = a.addr_type;

    ;
    ;
    create rule base_addr_v_delete as on delete to base.addr_v
        do instead delete from base.addr where addr_ent = old.addr_ent and addr_seq = old.addr_seq;
grant select on table base.addr_v to ent_1;
grant insert on table base.addr_v to ent_2;
grant update on table base.addr_v to ent_2;
grant delete on table base.addr_v to ent_3;
create function base.comm_make_prim(ent text, seq int, typ text) returns void language plpgsql security definer as $$
    begin

        update base.comm_prim set prim_seq = seq where prim_ent = ent and prim_type = typ;
        if not found then
            insert into base.comm_prim (prim_ent,prim_seq,prim_type) values (ent,seq,typ);
        end if;
    end;
$$;
create function base.comm_remove_prim(ent text, seq int, typ text) returns void language plpgsql security definer as $$
    declare
        prim_rec	record;
        comm_rec	record;
    begin

        select * into prim_rec from base.comm_prim where prim_ent = ent and prim_seq = seq and prim_type = typ;
        if found then			-- If the comm we are deleting was a primary, find the next latest record
            select * into comm_rec from base.comm where comm_ent = prim_rec.prim_ent and comm_type = prim_rec.prim_type and comm_seq != seq and not comm_inact order by comm_seq desc limit 1;
            if found then		-- And make it the new primary

                update base.comm_prim set prim_seq = comm_rec.comm_seq where prim_ent = comm_rec.comm_ent and prim_type = comm_rec.comm_type;
            else

                delete from base.comm_prim where prim_ent = ent and prim_seq = seq and prim_type = typ;
            end if;
        else

        end if;
    end;
$$;
create trigger base_comm_tr_aiud after insert or update or delete on base.comm for each statement execute procedure base.comm_tf_aiud();
create trigger base_comm_tr_bd before delete on base.comm for each row execute procedure base.comm_tf_bd();
create trigger base_comm_tr_bi before insert on base.comm for each row execute procedure base.comm_tf_bi();
create trigger base_comm_tr_bu before update on base.comm for each row execute procedure base.comm_tf_bu();
create view base.comm_v as select c.comm_ent, c.comm_seq, c.comm_type, c.comm_spec, c.comm_cmt, c.comm_inact, c.crt_by, c.mod_by, c.crt_date, c.mod_date
      , oe.std_name
      , cp.prim_seq is not null and cp.prim_seq = c.comm_seq	as comm_prim

    from	base.comm	c
    join	base.ent_v	oe	on oe.id = c.comm_ent
    left join	base.comm_prim	cp	on cp.prim_ent = c.comm_ent and cp.prim_type = c.comm_type;

    ;
    ;
    create rule base_comm_v_delete as on delete to base.comm_v
        do instead delete from base.comm where comm_ent = old.comm_ent and comm_seq = old.comm_seq;
grant select on table base.comm_v to ent_1;
grant insert on table base.comm_v to ent_2;
grant update on table base.comm_v to ent_2;
grant delete on table base.comm_v to ent_3;
create trigger base_ent_audit_tr_bi before insert on base.ent_audit for each row execute procedure base.ent_audit_tf_bi();
create trigger base_ent_link_tf_check before insert or update on base.ent_link for each row execute procedure base.ent_link_tf_check();
create trigger base_ent_tr_audit_d after delete on base.ent for each row execute procedure base.ent_tf_audit_d();
create trigger base_ent_tr_audit_u after update on base.ent for each row execute procedure base.ent_tf_audit_u();
create trigger base_ent_v_tr_ins instead of insert on base.ent_v for each row execute procedure base.ent_v_insfunc();
create trigger base_ent_v_tr_upd instead of update on base.ent_v for each row execute procedure base.ent_v_updfunc();
create function base.parm_audit_tf_bi() --Call when a new audit record is generated
          returns trigger language plpgsql security definer as $$
            begin
                if new.a_seq is null then		--Generate unique audit sequence number
                    select into new.a_seq coalesce(max(a_seq)+1,0) from base.parm_audit where module = new.module and parm = new.parm;
                end if;
                return new;
            end;
        $$;
create index base_parm_audit_x_a_column on base.parm_audit (a_column);
create function base.parmset(m text, p text, v anyelement, t text default null) returns anyelement language plpgsql as $$
    begin
      if exists (select type from base.parm where module = m and parm = p) then
        update base.parm_v set value = v where module = m and parm = p;
      else
        insert into base.parm_v (module,parm,value,type) values (m,p,v,t);
      end if;
      return v;
    end;
$$;
create function base.parm(m text, p text) returns text language sql stable as $$ select value from base.parm_v where module = m and parm = p; $$;
create function base.parm_tf_audit_d() --Call when a record is deleted in the audited table
          returns trigger language plpgsql security definer as $$
            begin
                insert into base.parm_audit (module,parm,a_date,a_by,a_action,a_column,a_value) values (old.module, old.parm,transaction_timestamp(),session_user,'delete','cmt',old.cmt::varchar);
		insert into base.parm_audit (module,parm,a_date,a_by,a_action,a_column,a_value) values (old.module, old.parm,transaction_timestamp(),session_user,'delete','v_int',old.v_int::varchar);
		insert into base.parm_audit (module,parm,a_date,a_by,a_action,a_column,a_value) values (old.module, old.parm,transaction_timestamp(),session_user,'delete','v_date',old.v_date::varchar);
		insert into base.parm_audit (module,parm,a_date,a_by,a_action,a_column,a_value) values (old.module, old.parm,transaction_timestamp(),session_user,'delete','v_text',old.v_text::varchar);
		insert into base.parm_audit (module,parm,a_date,a_by,a_action,a_column,a_value) values (old.module, old.parm,transaction_timestamp(),session_user,'delete','v_float',old.v_float::varchar);
		insert into base.parm_audit (module,parm,a_date,a_by,a_action,a_column,a_value) values (old.module, old.parm,transaction_timestamp(),session_user,'delete','v_boolean',old.v_boolean::varchar);
                return old;
            end;
        $$;
create function base.parm_tf_audit_u() --Call when a record is updated in the audited table
          returns trigger language plpgsql security definer as $$
            begin
                if new.cmt is distinct from old.cmt then insert into base.parm_audit (module,parm,a_date,a_by,a_action,a_column,a_value) values (old.module, old.parm,transaction_timestamp(),session_user,'update','cmt',old.cmt::varchar); end if;
		if new.v_int is distinct from old.v_int then insert into base.parm_audit (module,parm,a_date,a_by,a_action,a_column,a_value) values (old.module, old.parm,transaction_timestamp(),session_user,'update','v_int',old.v_int::varchar); end if;
		if new.v_date is distinct from old.v_date then insert into base.parm_audit (module,parm,a_date,a_by,a_action,a_column,a_value) values (old.module, old.parm,transaction_timestamp(),session_user,'update','v_date',old.v_date::varchar); end if;
		if new.v_text is distinct from old.v_text then insert into base.parm_audit (module,parm,a_date,a_by,a_action,a_column,a_value) values (old.module, old.parm,transaction_timestamp(),session_user,'update','v_text',old.v_text::varchar); end if;
		if new.v_float is distinct from old.v_float then insert into base.parm_audit (module,parm,a_date,a_by,a_action,a_column,a_value) values (old.module, old.parm,transaction_timestamp(),session_user,'update','v_float',old.v_float::varchar); end if;
		if new.v_boolean is distinct from old.v_boolean then insert into base.parm_audit (module,parm,a_date,a_by,a_action,a_column,a_value) values (old.module, old.parm,transaction_timestamp(),session_user,'update','v_boolean',old.v_boolean::varchar); end if;
                return new;
            end;
        $$;
create function base.parm_v_tf_del() returns trigger language plpgsql as $$
    begin
        delete from base.parm where module = old.module and parm = old.parm;
        return old;
    end;
$$;
create function base.parm_v_tf_ins() returns trigger language plpgsql as $$
    begin
        if new.type is null then
            case when new.value ~ '^[0-9]+$' then
                new.type = 'int';
            when new.value ~ '^[0-9]+\.*[0-9]*$' then
                new.type = 'float';
            when is_date(new.value) then
                new.type = 'date';
            when lower(new.value) in ('t','f','true','false','yes','no') then
                new.type = 'boolean';
            else
                new.type = 'text';
            end case;
        end if;
    
        case when new.type = 'int' then
            insert into base.parm (module, parm, type, cmt, crt_by, mod_by, crt_date, mod_date,v_int) values (new.module, new.parm, new.type, new.cmt, session_user, session_user, current_timestamp, current_timestamp, new.value::int);
        when new.type = 'date' then
            insert into base.parm (module, parm, type, cmt, crt_by, mod_by, crt_date, mod_date,v_date) values (new.module, new.parm, new.type, new.cmt, session_user, session_user, current_timestamp, current_timestamp, new.value::date);
        when new.type = 'float' then
            insert into base.parm (module, parm, type, cmt, crt_by, mod_by, crt_date, mod_date,v_float) values (new.module, new.parm, new.type, new.cmt, session_user, session_user, current_timestamp, current_timestamp, new.value::float);
        when new.type = 'boolean' then
            insert into base.parm (module, parm, type, cmt, crt_by, mod_by, crt_date, mod_date,v_boolean) values (new.module, new.parm, new.type, new.cmt, session_user, session_user, current_timestamp, current_timestamp, new.value::boolean);
        else		-- when new.type = 'text' then
            insert into base.parm (module, parm, type, cmt, crt_by, mod_by, crt_date, mod_date,v_text) values (new.module, new.parm, new.type, new.cmt, session_user, session_user, current_timestamp, current_timestamp, new.value);
        end case;
        return new;
    end;
$$;
create function base.parm_v_tf_upd() returns trigger language plpgsql as $$
    begin
        case when old.type = 'int' then
            update base.parm set parm = new.parm, cmt = new.cmt, mod_by = session_user, mod_date = current_timestamp, v_int = new.value::int where module = old.module and parm = old.parm;
        when old.type = 'date' then
            update base.parm set parm = new.parm, cmt = new.cmt, mod_by = session_user, mod_date = current_timestamp, v_date = new.value::date where module = old.module and parm = old.parm;
        when old.type = 'text' then
            update base.parm set parm = new.parm, cmt = new.cmt, mod_by = session_user, mod_date = current_timestamp, v_text = new.value::text where module = old.module and parm = old.parm;
        when old.type = 'float' then
            update base.parm set parm = new.parm, cmt = new.cmt, mod_by = session_user, mod_date = current_timestamp, v_float = new.value::float where module = old.module and parm = old.parm;
        when old.type = 'boolean' then
            update base.parm set parm = new.parm, cmt = new.cmt, mod_by = session_user, mod_date = current_timestamp, v_boolean = new.value::boolean where module = old.module and parm = old.parm;
        end case;
        return new;
    end;
$$;
create function base.pop_role(rname text) returns void security definer language plpgsql as $$
    declare
        trec	record;
    begin
        for trec in select grantee from base.priv_v where priv = rname and level is null loop
            execute 'grant ' || rname || ' to ' || trec.grantee;
        end loop;
    end;
$$;
create trigger base_priv_tr_dgrp before delete on base.priv for each row execute procedure base.priv_tf_dgrp();
create trigger base_priv_tr_iugrp before insert or update on base.priv for each row execute procedure base.priv_tf_iugrp();
create function base.priv_v_insfunc() returns trigger language plpgsql security definer as $$
  declare
    trec record;
    str  varchar;
  begin
    execute 'select string_agg(val,'','') from wm.column_def where obj = $1;' into str using 'base.priv_v';
    execute 'select ' || str || ';' into trec using new;
    insert into base.priv (grantee,priv,level,cmt) values (new.grantee,new.priv,trec.level,trec.cmt) returning grantee,priv into new.grantee, new.priv;
    select into new * from base.priv_v where grantee = new.grantee and priv = new.priv;
    return new;
  end;
$$;
create function base.priv_v_updfunc() returns trigger language plpgsql security definer as $$
  begin
    update base.priv set grantee = new.grantee,priv = new.priv,level = new.level,cmt = new.cmt where grantee = old.grantee and priv = old.priv returning grantee,priv into new.grantee, new.priv;
    select into new * from base.priv_v where grantee = new.grantee and priv = new.priv;
    return new;
  end;
$$;
create trigger base_token_tr_seq before insert on base.token for each row execute procedure base.token_tf_seq();
create function base.token_v_insfunc() returns trigger language plpgsql security definer as $$
  declare
    trec record;
    str  varchar;
  begin
    execute 'select string_agg(val,'','') from wm.column_def where obj = $1;' into str using 'base.token_v';
    execute 'select ' || str || ';' into trec using new;
    insert into base.token (token_ent,allows,crt_by,mod_by,crt_date,mod_date) values (new.token_ent,trec.allows,session_user,session_user,current_timestamp,current_timestamp) returning token_ent,token_seq into new.token_ent, new.token_seq;
    select into new * from base.token_v where token_ent = new.token_ent and token_seq = new.token_seq;
    return new;
  end;
$$;
create view base.token_v_ticket as select token_ent, allows, token, expires
      , base.parm_text('wylib','host') as host
      , base.parm_int('wylib','port') as port
    from	base.token	t;
create function base.validate_token(uname text, tok text, pub text) returns boolean language plpgsql as $$
    declare
      trec	record;
    begin
      select into trec valid,token,allows,token_ent,token_seq from base.token_v where username = uname order by token_seq desc limit 1;
      if found and trec.valid and tok = trec.token and trec.allows = 'login' then
        update base.token set used = current_timestamp where token_ent = trec.token_ent and token_seq = trec.token_seq;
        update base.ent set conn_pub = pub where id = trec.token_ent;
        return true;
      end if;
      return false;
    end;
$$;
create trigger wylib_data_tr_notify after insert or update or delete on wylib.data for each row execute procedure wylib.data_tf_notify();
create view wylib.data_v as select wd.ruid, wd.component, wd.name, wd.descr, wd.access, wd.data, wd.owner, wd.crt_by, wd.mod_by, wd.crt_date, wd.mod_date
      , oe.std_name		as own_name

    from	wylib.data	wd
    join	base.ent_v	oe	on oe.id = wd.owner
    where	access = 'read' or owner = base.curr_eid();
grant select on table wylib.data_v to public;
grant insert on table wylib.data_v to public;
grant update on table wylib.data_v to public;
grant delete on table wylib.data_v to public;
create function base.addr_v_insfunc() returns trigger language plpgsql security definer as $$
  declare
    trec record;
    str  varchar;
  begin
    execute 'select string_agg(val,'','') from wm.column_def where obj = $1;' into str using 'base.addr_v';
    execute 'select ' || str || ';' into trec using new;
    insert into base.addr (addr_ent,addr_spec,city,state,pcode,country,addr_cmt,addr_type,addr_prim,addr_inact,crt_by,mod_by,crt_date,mod_date) values (new.addr_ent,trec.addr_spec,trec.city,trec.state,trec.pcode,trec.country,trec.addr_cmt,trec.addr_type,trec.addr_prim,trec.addr_inact,session_user,session_user,current_timestamp,current_timestamp) returning addr_ent,addr_seq into new.addr_ent, new.addr_seq;
    select into new * from base.addr_v where addr_ent = new.addr_ent and addr_seq = new.addr_seq;
    return new;
  end;
$$;
create function base.addr_v_updfunc() returns trigger language plpgsql security definer as $$
  begin
    update base.addr set addr_spec = new.addr_spec,city = new.city,state = new.state,pcode = new.pcode,country = new.country,addr_cmt = new.addr_cmt,addr_type = new.addr_type,addr_prim = new.addr_prim,addr_inact = new.addr_inact,mod_by = session_user,mod_date = current_timestamp where addr_ent = old.addr_ent and addr_seq = old.addr_seq returning addr_ent,addr_seq into new.addr_ent, new.addr_seq;
    select into new * from base.addr_v where addr_ent = new.addr_ent and addr_seq = new.addr_seq;
    return new;
  end;
$$;
create function base.comm_v_insfunc() returns trigger language plpgsql security definer as $$
  declare
    trec record;
    str  varchar;
  begin
    execute 'select string_agg(val,'','') from wm.column_def where obj = $1;' into str using 'base.comm_v';
    execute 'select ' || str || ';' into trec using new;
    insert into base.comm (comm_ent,comm_type,comm_spec,comm_cmt,comm_inact,comm_prim,crt_by,mod_by,crt_date,mod_date) values (new.comm_ent,trec.comm_type,trec.comm_spec,trec.comm_cmt,trec.comm_inact,trec.comm_prim,session_user,session_user,current_timestamp,current_timestamp) returning comm_ent,comm_seq into new.comm_ent, new.comm_seq;
    select into new * from base.comm_v where comm_ent = new.comm_ent and comm_seq = new.comm_seq;
    return new;
  end;
$$;
create function base.comm_v_updfunc() returns trigger language plpgsql security definer as $$
  begin
    update base.comm set comm_type = new.comm_type,comm_spec = new.comm_spec,comm_cmt = new.comm_cmt,comm_inact = new.comm_inact,comm_prim = new.comm_prim,mod_by = session_user,mod_date = current_timestamp where comm_ent = old.comm_ent and comm_seq = old.comm_seq returning comm_ent,comm_seq into new.comm_ent, new.comm_seq;
    select into new * from base.comm_v where comm_ent = new.comm_ent and comm_seq = new.comm_seq;
    return new;
  end;
$$;
create trigger base_parm_audit_tr_bi before insert on base.parm_audit for each row execute procedure base.parm_audit_tf_bi();
create function base.parmsett(m text, p text, v text, t text default null) returns text language plpgsql as $$
    begin
      return base.parmset(m,p,v,t);
    end;
$$;
create trigger base_parm_tr_audit_d after delete on base.parm for each row execute procedure base.parm_tf_audit_d();
create trigger base_parm_tr_audit_u after update on base.parm for each row execute procedure base.parm_tf_audit_u();
create trigger base_parm_v_tr_del instead of delete on base.parm_v for each row execute procedure base.parm_v_tf_del();
create trigger base_parm_v_tr_ins instead of insert on base.parm_v for each row execute procedure base.parm_v_tf_ins();
create trigger base_parm_v_tr_upd instead of update on base.parm_v for each row execute procedure base.parm_v_tf_upd();
create trigger base_priv_v_tr_ins instead of insert on base.priv_v for each row execute procedure base.priv_v_insfunc();
create trigger base_priv_v_tr_upd instead of update on base.priv_v for each row execute procedure base.priv_v_updfunc();
create function base.ticket_login(uid text) returns base.token_v_ticket language sql as $$
    insert into base.token_v_ticket (token_ent, allows) values (uid, 'login') returning *;
$$;
create trigger base_token_v_tr_ins instead of insert on base.token_v for each row execute procedure base.token_v_insfunc();
create function wylib.data_v_tf_del() returns trigger language plpgsql security definer as $$
        begin
           if not (old.owner = base.curr_eid() or old.access = 'write') then return null; end if;
            delete from wylib.data where ruid = old.ruid;
            return old;
        end;
    $$;
create function wylib.data_v_tf_ins() returns trigger language plpgsql security definer as $$
        begin

            insert into wylib.data (component, name, descr, access, data, crt_by, mod_by, crt_date, mod_date) values (new.component, new.name, new.descr, new.access, new.data, session_user, session_user, current_timestamp, current_timestamp) returning into new.ruid ruid;
            return new;
        end;
    $$;
create function wylib.data_v_tf_upd() returns trigger language plpgsql security definer  as $$
        begin
           if not (old.owner = base.curr_eid() or old.access = 'write') then return null; end if;
            if ((new.access is not distinct from old.access) and (new.name is not distinct from old.name) and (new.descr is not distinct from old.descr) and (new.data is not distinct from old.data)) then return null; end if;
            update wylib.data set access = new.access, name = new.name, descr = new.descr, data = new.data, mod_by = session_user, mod_date = current_timestamp where ruid = old.ruid returning into new.ruid ruid;
            return new;
        end;
    $$;
create function wylib.get_data(comp text, nam text, own text) returns jsonb language sql stable as $$
      select data from wylib.data_v where owner = coalesce(own,base.curr_eid()) and component = comp and name = nam;
$$;
create function wylib.set_data(comp text, nam text, des text, own text, dat jsonb) returns int language plpgsql as $$
    declare
      userid	text = coalesce(own, base.curr_eid());
      id	int;
      trec	record;
    begin
      select ruid into id from wylib.data_v where owner = userid and component = comp and name = nam;

      if dat is null then
        if found then
          delete from wylib.data_v where ruid = id;
        end if;
      elsif not found then
        insert into wylib.data_v (component, name, descr, owner, access, data) values (comp, nam, des, userid, 'read', dat) returning ruid into id;
      else
        update wylib.data_v set descr = des, data = dat where ruid = id;
      end if;
      return id;
    end;
$$;
create trigger base_addr_v_tr_ins instead of insert on base.addr_v for each row execute procedure base.addr_v_insfunc();
create trigger base_addr_v_tr_upd instead of update on base.addr_v for each row execute procedure base.addr_v_updfunc();
create trigger base_comm_v_tr_ins instead of insert on base.comm_v for each row execute procedure base.comm_v_insfunc();
create trigger base_comm_v_tr_upd instead of update on base.comm_v for each row execute procedure base.comm_v_updfunc();
create trigger wylib_data_v_tr_del instead of delete on wylib.data_v for each row execute procedure wylib.data_v_tf_del();
create trigger wylib_data_v_tr_ins instead of insert on wylib.data_v for each row execute procedure wylib.data_v_tf_ins();
create trigger wylib_data_v_tr_upd instead of update on wylib.data_v for each row execute procedure wylib.data_v_tf_upd();

--Data Dictionary:
insert into wm.table_text (tt_sch,tt_tab,language,title,help) values
  ('wm','releases','eng','Releases','Tracks the version number of each public release of the database design'),
  ('wm','objects','eng','Objects','Keeps data on database tables, views, functions, etc. telling how to build or drop each object and how it relates to other objects in the database.'),
  ('wm','objects_v','eng','Rel Objects','An enhanced view of the object table, expanded by showing the full object specifier, and each separate release this version of the object belongs to'),
  ('wm','objects_v_depth','eng','Dep Objects','An enhanced view of the object table, expanded by showing the full object specifier, each separate release this version of the object belongs to, and the maximum depth it is along any path in the dependency tree.'),
  ('wm','depends_v','eng','Dependencies','A recursive view showing which database objects depend on (must be created after) other database objects.'),
  ('wm','table_style','eng','Table Styles','Contains style flags to tell the GUI how to render each table or view'),
  ('wm','column_style','eng','Column Styles','Contains style flags to tell the GUI how to render the columns of a table or view'),
  ('wm','table_text','eng','Table Text','Contains a description of each table in the system'),
  ('wm','column_text','eng','Column Text','Contains a description for each column of each table in the system'),
  ('wm','value_text','eng','Value Text','Contains a description for the values which certain columns may be set to.  Used only for columns that can be set to one of a finite set of values (like an enumerated type).'),
  ('wm','message_text','eng','Message Text','Contains messages in a particular language to describe an error, or a widget feature or button'),
  ('wm','column_native','eng','Native Columns','Contains cached information about the tables and their columns which various higher level view columns derive from.  To query this directly from the information schema is somewhat slow, so wyseman caches it here when building the schema for faster access.'),
  ('wm','table_data','eng','Table Data','Contains information from the system catalogs about views and tables in the system'),
  ('wm','table_pub','eng','Tables','Joins information about tables from the system catalogs with the text descriptions defined in wyseman'),
  ('wm','view_column_usage','eng','View Column Usage','A version of a similar view in the information schema but faster.  For each view, tells what underlying table and column the view column uses.'),
  ('wm','column_data','eng','Column Data','Contains information from the system catalogs about columns of tables in the system'),
  ('wm','column_def','eng','Column Default','A view used internally for initializing columns to their default value'),
  ('wm','column_istyle','eng','Column Styles','A view of the default display styles for table and view columns'),
  ('wm','column_lang','eng','Column language','A view of descriptive language data as it applies to the columns of tables and views'),
  ('wm','column_meta','eng','Column Metadata','A view of data about the use and display of the columns of tables and views'),
  ('wm','table_lang','eng','Table Language','A view of titles and descriptions of database tables/views'),
  ('wm','table_meta','eng','Table Metadata','A view of data about the use and display of tables and views'),
  ('wm','column_pub','eng','Columns','Joins information about table columns from the system catalogs with the text descriptions defined in wyseman'),
  ('wm','fkeys_data','eng','Keys Data','Includes data from the system catalogs about how key fields in a table point to key fields in a foreign table.  Each key group is described on a separate row.'),
  ('wm','fkeys_pub','eng','Keys','Public view to see foreign key relationships between views and tables and what their native underlying tables/columns are.  One row per key group.'),
  ('wm','fkey_data','eng','Key Data','Includes data from the system catalogs about how key fields in a table point to key fields in a foreign table.  Each separate key field is listed as a separate row.'),
  ('wm','fkey_pub','eng','Key Info','Public view to see foreign key relationships between views and tables and what their native underlying tables/columns are.  One row per key column.'),
  ('wm','role_members','eng','Role Members','Summarizes information from the system catalogs about members of various defined roles'),
  ('wm','column_ambig','eng','Ambiguous Columns','A view showing view and their columns for which no definitive native table and column can be found automatically'),
  ('wylib','data','eng','GUI Data','Configuration and preferences data accessed by Wylib view widgets'),
  ('wylib','data_v','eng','GUI Data','A view of configuration and preferences data accessed by Wylib view widgets'),
  ('wylib','data','fin','GUI Data','Wylib-näkymäkomponenttien käyttämät konfigurointi- ja asetustiedot'),
  ('base','addr','eng','Addresses','Addresses (home, mailing, etc.) pertaining to entities'),
  ('base','addr_v','eng','Addresses','A view of addresses (home, mailing, etc.) pertaining to entities, with additional derived fields'),
  ('base','addr_prim','eng','Primary Address','Internal table to track which address is the main one for each given type'),
  ('base','addr_v_flat','eng','Entities Flat','A flattened view of entities showing their primary standard addresses'),
  ('base','comm','eng','Communication','Communication points (phone, email, fax, etc.) for entities'),
  ('base','comm_v','eng','Communication','View of users'' communication points (phone, email, fax, etc.) with additional helpful fields'),
  ('base','comm_prim','eng','Primary Communication','Internal table to track which communication point is the main one for each given type'),
  ('base','comm_v_flat','eng','Entities Flat','A flattened view of entities showing their primary standard contact points'),
  ('base','country','eng','Countries','Contains standard ISO data about international countries'),
  ('base','ent','eng','Entities','Entities, which can be a person, a company or a group'),
  ('base','ent_v','eng','Entities','A view of Entities, which can be a person, a company or a group, plus additional derived fields'),
  ('base','ent_link','eng','Entity Links','Links to show how one entity (like an employee) is linked to another (like his company)'),
  ('base','ent_link_v','eng','Entity Links','A view showing links to show how one entity (like an employee) is linked to another (like his company), plus the derived names of the entities'),
  ('base','ent_audit','eng','Entities Auditing','Table tracking changes to the entities table'),
  ('base','language','eng','Languages','Contains standard ISO data about international language codes'),
  ('base','token','eng','Access Tokens','Stores access codes which allow users to connect for the first time'),
  ('base','token_v','eng','Tokens','A view of the access codes, which allow users to connect for the first time'),
  ('base','token_v_ticket','eng','Login Tickets','A view of the access codes, which allow users to connect for the first time'),
  ('base','parm','eng','System Parameters','Contains parameter settings of several types for configuring and controlling various modules across the database'),
  ('base','parm_v','eng','Parameters','System parameters are stored in different tables depending on their data type (date, integer, etc.).  This view is a union of all the different type tables so all parameters can be viewed and updated in one place.  The value specified will have to be entered in a way that is compatible with the specified type so it can be stored natively in its correct data type.'),
  ('base','parm_audit','eng','Parameters Auditing','Table tracking changes to the parameters table'),
  ('base','priv','eng','Privileges','Permissions assigned to each system user defining what tasks they can perform and what database objects they can access'),
  ('base','priv_v','eng','Privileges','Privileges assigned to each entity');

insert into wm.column_text (ct_sch,ct_tab,ct_col,language,title,help) values
  ('wm','releases','release','eng','Release','The integer number of the release, starting with 1.  The current number in this field always designates a work-in-progress.  The number prior indicates the last public release.'),
  ('wm','releases','crt_date','eng','Created','When this record was created.  Indicates when development started on this release (And the prior release was frozen).'),
  ('wm','releases','sver_1','eng','BS Version','Dummy column with a name indicating the version of these bootstrap tables (which can''t be managed by wyseman themselves).'),
  ('wm','objects','obj_typ','eng','Type','The object type, for example: table, function, trigger, etc.'),
  ('wm','objects','obj_nam','eng','Name','The schema and name of object as known within that schema'),
  ('wm','objects','obj_ver','eng','Version','A sequential integer showing how many times this object has been modified, as a part of an official release.  Changes to the current (working) release do not increment this number.'),
  ('wm','objects','checked','eng','Checked','This record has had its dependencies and consistency checked'),
  ('wm','objects','clean','eng','Clean','The object represented by this record is built and current according to this create script'),
  ('wm','objects','module','eng','Module','The name of a code module (package) this object belongs to'),
  ('wm','objects','mod_ver','eng','Mod Vers','The version of the code module, or package this object belongs to'),
  ('wm','objects','source','eng','Source','The basename of the external source code file this object was parsed from'),
  ('wm','objects','deps','eng','Depends','A list of un-expanded dependencies for this object, exactly as expressed in the source file'),
  ('wm','objects','ndeps','eng','Normal Deps','An expanded and normalized array of dependencies, guaranteed to exist in another record of the table'),
  ('wm','objects','grants','eng','Grants','The permission grants found, applicable to this object'),
  ('wm','objects','col_data','eng','Display','Switches found, expressing preferred display characteristics for columns, assuming this is a view or table object'),
  ('wm','objects','crt_sql','eng','Create','The SQL code to build this object'),
  ('wm','objects','drp_sql','eng','Drop','The SQL code to drop this object'),
  ('wm','objects','min_rel','eng','Minimum','The oldest release this version of this object belongs to'),
  ('wm','objects','max_rel','eng','Maximum','The latest release this version of this object belongs to'),
  ('wm','objects','crt_date','eng','Created','When this object record was first created'),
  ('wm','objects','mod_date','eng','Modified','When this object record was last modified'),
  ('wm','objects_v','object','eng','Object','Full type and name of this object'),
  ('wm','objects_v','release','eng','Release','A release this version of the object belongs to'),
  ('wm','objects_v_depth','depth','eng','Max Depth','The maximum depth of this object along any path in the dependency tree'),
  ('wm','depends_v','object','eng','Object','Full object type and name (type:name)'),
  ('wm','depends_v','od_typ','eng','Type','Function, view, table, etc'),
  ('wm','depends_v','od_nam','eng','Name','Schema and name of object as known within that schema'),
  ('wm','depends_v','od_release','eng','Release','The release this object belongs to'),
  ('wm','depends_v','cycle','eng','Cycle','Prevents the recursive view gets into an infinite loop'),
  ('wm','depends_v','depend','eng','Depends On','Another object that must be created before this object'),
  ('wm','depends_v','depth','eng','Depth','The depth of the dependency tree, when following this particular dependency back to the root.'),
  ('wm','depends_v','path','eng','Path','The path of the dependency tree above this object'),
  ('wm','depends_v','fpath','eng','Full Path','The full path of the dependency tree above this object (including this object).'),
  ('wm','table_style','ts_sch','eng','Schema Name','The schema for the table this style pertains to'),
  ('wm','table_style','ts_tab','eng','Table Name','The name of the table this style pertains to'),
  ('wm','table_style','sw_name','eng','Name','The name of the style being described'),
  ('wm','table_style','sw_value','eng','Value','The value for this particular style'),
  ('wm','table_style','inherit','eng','Inherit','The value for this style can propagate to derivative views'),
  ('wm','column_style','cs_sch','eng','Schema Name','The schema for the table this style pertains to'),
  ('wm','column_style','cs_tab','eng','Table Name','The name of the table containing the column this style pertains to'),
  ('wm','column_style','cs_col','eng','Column Name','The name of the column this style pertains to'),
  ('wm','column_style','sw_name','eng','Name','The name of the style being described'),
  ('wm','column_style','sw_value','eng','Value','The value for this particular style'),
  ('wm','table_text','tt_sch','eng','Schema Name','The schema this table belongs to'),
  ('wm','table_text','tt_tab','eng','Table Name','The name of the table being described'),
  ('wm','table_text','language','eng','Language','The language this description is in'),
  ('wm','table_text','title','eng','Title','A short title for the table'),
  ('wm','table_text','help','eng','Description','A longer description of what the table is used for'),
  ('wm','column_text','ct_sch','eng','Schema Name','The schema this column''s table belongs to'),
  ('wm','column_text','ct_tab','eng','Table Name','The name of the table this column is in'),
  ('wm','column_text','ct_col','eng','Column Name','The name of the column being described'),
  ('wm','column_text','language','eng','Language','The language this description is in'),
  ('wm','column_text','title','eng','Title','A short title for the column'),
  ('wm','column_text','help','eng','Description','A longer description of what the column is used for'),
  ('wm','value_text','vt_sch','eng','Schema Name','The schema of the table the column belongs to'),
  ('wm','value_text','vt_tab','eng','Table Name','The name of the table this column is in'),
  ('wm','value_text','vt_col','eng','Column Name','The name of the column whose values are being described'),
  ('wm','value_text','value','eng','Value','The name of the value being described'),
  ('wm','value_text','language','eng','Language','The language this description is in'),
  ('wm','value_text','title','eng','Title','A short title for the value'),
  ('wm','value_text','help','eng','Description','A longer description of what it means when the column is set to this value'),
  ('wm','message_text','mt_sch','eng','Schema Name','The schema of the table this message belongs to'),
  ('wm','message_text','mt_tab','eng','Table Name','The name of the table this message belongs to is in'),
  ('wm','message_text','code','eng','Code','A unique code referenced in the source code to evoke this message in the language of choice'),
  ('wm','message_text','language','eng','Language','The language this message is in'),
  ('wm','message_text','title','eng','Title','A short version for the message, or its alert'),
  ('wm','message_text','help','eng','Description','A longer, more descriptive version of the message'),
  ('wm','column_native','cnt_sch','eng','Schema Name','The schema of the table this column belongs to'),
  ('wm','column_native','cnt_tab','eng','Table Name','The name of the table this column is in'),
  ('wm','column_native','cnt_col','eng','Column Name','The name of the column whose native source is being described'),
  ('wm','column_native','nat_sch','eng','Schema Name','The schema of the native table the column derives from'),
  ('wm','column_native','nat_tab','eng','Table Name','The name of the table the column natively derives from'),
  ('wm','column_native','nat_col','eng','Column Name','The name of the column in the native table from which the higher level column derives'),
  ('wm','column_native','nat_exp','eng','Explic Native','The information about the native table in this record has been defined explicitly in the schema description (not derived from the database system catalogs)'),
  ('wm','column_native','pkey','eng','Primary Key','Wyseman can often determine the "primary key" for views on its own from the database.  When it can''t, you have to define it explicitly in the schema.  This indicates that thiscolumn should be regarded as a primary key field when querying the view.'),
  ('wm','table_data','td_sch','eng','Schema Name','The schema the table is in'),
  ('wm','table_data','td_tab','eng','Table Name','The name of the table being described'),
  ('wm','table_data','tab_kind','eng','Kind','Tells whether the relation is a table or a view'),
  ('wm','table_data','has_pkey','eng','Has Pkey','Indicates whether the table has a primary key defined in the database'),
  ('wm','table_data','obj','eng','Object Name','The table name, prefixed by the schema (namespace) name'),
  ('wm','table_data','cols','eng','Columns','Indicates how many columns are in the table'),
  ('wm','table_data','system','eng','System','True if the table/view is built in to PostgreSQL'),
  ('wm','table_pub','sch','eng','Schema Name','The schema the table belongs to'),
  ('wm','table_pub','tab','eng','Table Name','The name of the table being described'),
  ('wm','table_pub','obj','eng','Object Name','The table name, prefixed by the schema (namespace) name'),
  ('wm','view_column_usage','view_catalog','eng','View Database','The database the view belongs to'),
  ('wm','view_column_usage','view_schema','eng','View Schema','The schema the view belongs to'),
  ('wm','view_column_usage','view_name','eng','View Name','The name of the view being described'),
  ('wm','view_column_usage','table_catalog','eng','Table Database','The database the underlying table belongs to'),
  ('wm','view_column_usage','table_schema','eng','Table Schema','The schema the underlying table belongs to'),
  ('wm','view_column_usage','table_name','eng','Table Name','The name of the underlying table'),
  ('wm','view_column_usage','column_name','eng','Column Name','The name of the column in the view'),
  ('wm','column_data','cdt_sch','eng','Schema Name','The schema of the table this column belongs to'),
  ('wm','column_data','cdt_tab','eng','Table Name','The name of the table this column is in'),
  ('wm','column_data','cdt_col','eng','Column Name','The name of the column whose data is being described'),
  ('wm','column_data','field','eng','Field','The number of the column as it appears in the table'),
  ('wm','column_data','nonull','eng','Not Null','Indicates that the column is not allowed to contain a null value'),
  ('wm','column_data','length','eng','Length','The normal number of characters this item would occupy'),
  ('wm','column_data','type','eng','Data Type','The kind of data this column holds, such as integer, string, date, etc.'),
  ('wm','column_data','def','eng','Default','Default value for this column if none is explicitly assigned'),
  ('wm','column_data','tab_kind','eng','Table/View','The kind of database relation this column is in (r=table, v=view)'),
  ('wm','column_data','is_pkey','eng','Def Prim Key','Indicates that this column is defined as a primary key in the database (can be overridden by a wyseman setting)'),
  ('wm','column_def','val','eng','Init Value','An expression used for default initialization'),
  ('wm','column_istyle','nat_value','eng','Native Style','The inherited style as specified by an ancestor object'),
  ('wm','column_istyle','cs_value','eng','Given Style','The style, specified explicitly for this object'),
  ('wm','column_istyle','cs_obj','eng','Object Name','The schema and table name this style applies to'),
  ('wm','column_lang','sch','eng','Schema','The schema that holds the table or view this language data applies to'),
  ('wm','column_lang','tab','eng','Table','The table or view this language data applies to'),
  ('wm','column_lang','obj','eng','Object','The schema name and the table/view name'),
  ('wm','column_lang','col','eng','Column','The name of the column the metadata applies to'),
  ('wm','column_lang','values','eng','Values','A JSON description of the allowable values for this column'),
  ('wm','column_lang','system','eng','System','Indicates if this table/view is built in to PostgreSQL'),
  ('wm','column_lang','nat','eng','Native','The (possibly ancestor) schema and table/view this language information descends from'),
  ('wm','column_meta','sch','eng','Schema','The schema that holds the table or view this metadata applies to'),
  ('wm','column_meta','tab','eng','Table','The table or view this metadata applies to'),
  ('wm','column_meta','obj','eng','Object','The schema name and the table/view name'),
  ('wm','column_meta','col','eng','Column','The name of the column the metadata applies to'),
  ('wm','column_meta','values','eng','Values','An array of allowable values for this column'),
  ('wm','column_meta','styles','eng','Styles','An array of default display styles for this column'),
  ('wm','column_meta','nat','eng','Native','The (possibly ancestor) schema and table/view this metadata descends from'),
  ('wm','table_lang','messages','eng','Messages','Human readable messages the computer may generate in connection with this table/view'),
  ('wm','table_lang','columns','eng','Columns','A JSON structure describing language information relevant to the columns in this table/view'),
  ('wm','table_lang','obj','eng','Object','The schema and table/view'),
  ('wm','table_meta','fkeys','eng','Foreign Keys','A JSON structure containing information about the foreign keys pointed to by this table'),
  ('wm','table_meta','obj','eng','Object','The schema and table/view'),
  ('wm','table_meta','pkey','eng','Primary Key','A JSON array describing the primary key fields for this table/view'),
  ('wm','table_meta','columns','eng','Columns','A JSON structure describing metadata information relevant to the columns in this table/view'),
  ('wm','column_pub','sch','eng','Schema Name','The schema of the table the column belongs to'),
  ('wm','column_pub','tab','eng','Table Name','The name of the table that holds the column being described'),
  ('wm','column_pub','col','eng','Column Name','The name of the column being described'),
  ('wm','column_pub','obj','eng','Object Name','The table name, prefixed by the schema (namespace) name'),
  ('wm','column_pub','nat','eng','Native Object','The name of the native table, prefixed by the native schema'),
  ('wm','column_pub','language','eng','Language','The language of the included textual descriptions'),
  ('wm','column_pub','title','eng','Title','A short title for the table'),
  ('wm','column_pub','help','eng','Description','A longer description of what the table is used for'),
  ('wm','fkeys_data','kst_sch','eng','Base Schema','The schema of the table that has the referencing key fields'),
  ('wm','fkeys_data','kst_tab','eng','Base Table','The name of the table that has the referencing key fields'),
  ('wm','fkeys_data','kst_cols','eng','Base Columns','The name of the columns in the referencing table''s key'),
  ('wm','fkeys_data','ksf_sch','eng','Foreign Schema','The schema of the table that is referenced by the key fields'),
  ('wm','fkeys_data','ksf_tab','eng','Foreign Table','The name of the table that is referenced by the key fields'),
  ('wm','fkeys_data','ksf_cols','eng','Foreign Columns','The name of the columns in the referenced table''s key'),
  ('wm','fkeys_data','conname','eng','Constraint','The name of the the foreign key constraint in the database'),
  ('wm','fkeys_pub','tt_sch','eng','Schema','The schema of the table that has the referencing key fields'),
  ('wm','fkeys_pub','tt_tab','eng','Table','The name of the table that has the referencing key fields'),
  ('wm','fkeys_pub','tt_cols','eng','Columns','The name of the columns in the referencing table''s key'),
  ('wm','fkeys_pub','tt_obj','eng','Object','Concatenated schema.table that has the referencing key fields'),
  ('wm','fkeys_pub','tn_sch','eng','Nat Schema','The schema of the native table that has the referencing key fields'),
  ('wm','fkeys_pub','tn_tab','eng','Nat Table','The name of the native table that has the referencing key fields'),
  ('wm','fkeys_pub','tn_cols','eng','Nat Columns','The name of the columns in the native referencing table''s key'),
  ('wm','fkeys_pub','tn_obj','eng','Nat Object','Concatenated schema.table for the native table that has the referencing key fields'),
  ('wm','fkeys_pub','ft_sch','eng','For Schema','The schema of the table that is referenced by the key fields'),
  ('wm','fkeys_pub','ft_tab','eng','For Table','The name of the table that is referenced by the key fields'),
  ('wm','fkeys_pub','ft_cols','eng','For Columns','The name of the columns referenced by the key'),
  ('wm','fkeys_pub','ft_obj','eng','For Object','Concatenated schema.table for the table that is referenced by the key fields'),
  ('wm','fkeys_pub','fn_sch','eng','For Nat Schema','The schema of the native table that is referenced by the key fields'),
  ('wm','fkeys_pub','fn_tab','eng','For Nat Table','The name of the native table that is referenced by the key fields'),
  ('wm','fkeys_pub','fn_cols','eng','For Nat Columns','The name of the columns in the native referenced by the key'),
  ('wm','fkeys_pub','fn_obj','eng','For Nat Object','Concatenated schema.table for the native table that is referenced by the key fields'),
  ('wm','fkey_data','kyt_sch','eng','Base Schema','The schema of the table that has the referencing key fields'),
  ('wm','fkey_data','kyt_tab','eng','Base Table','The name of the table that has the referencing key fields'),
  ('wm','fkey_data','kyt_col','eng','Base Columns','The name of the column in the referencing table''s key'),
  ('wm','fkey_data','kyt_field','eng','Base Field','The number of the column in the referencing table''s key'),
  ('wm','fkey_data','kyf_sch','eng','Foreign Schema','The schema of the table that is referenced by the key fields'),
  ('wm','fkey_data','kyf_tab','eng','Foreign Table','The name of the table that is referenced by the key fields'),
  ('wm','fkey_data','kyf_col','eng','Foreign Columns','The name of the columns in the referenced table''s key'),
  ('wm','fkey_data','kyf_field','eng','Foreign Field','The number of the column in the referenced table''s key'),
  ('wm','fkey_data','key','eng','Key','The number of which field of a compound key this record describes'),
  ('wm','fkey_data','keys','eng','Keys','The total number of columns used for this foreign key'),
  ('wm','fkey_data','conname','eng','Constraint','The name of the the foreign key constraint in the database'),
  ('wm','fkey_pub','tt_sch','eng','Schema','The schema of the table that has the referencing key fields'),
  ('wm','fkey_pub','tt_tab','eng','Table','The name of the table that has the referencing key fields'),
  ('wm','fkey_pub','tt_col','eng','Column','The name of the column in the referencing table''s key component'),
  ('wm','fkey_pub','tt_obj','eng','Object','Concatenated schema.table that has the referencing key fields'),
  ('wm','fkey_pub','tn_sch','eng','Nat Schema','The schema of the native table that has the referencing key fields'),
  ('wm','fkey_pub','tn_tab','eng','Nat Table','The name of the native table that has the referencing key fields'),
  ('wm','fkey_pub','tn_col','eng','Nat Column','The name of the column in the native referencing table''s key component'),
  ('wm','fkey_pub','tn_obj','eng','Nat Object','Concatenated schema.table for the native table that has the referencing key fields'),
  ('wm','fkey_pub','ft_sch','eng','For Schema','The schema of the table that is referenced by the key fields'),
  ('wm','fkey_pub','ft_tab','eng','For Table','The name of the table that is referenced by the key fields'),
  ('wm','fkey_pub','ft_col','eng','For Column','The name of the column referenced by the key component'),
  ('wm','fkey_pub','ft_obj','eng','For Object','Concatenated schema.table for the table that is referenced by the key fields'),
  ('wm','fkey_pub','fn_sch','eng','For Nat Schema','The schema of the native table that is referenced by the key fields'),
  ('wm','fkey_pub','fn_tab','eng','For Nat Table','The name of the native table that is referenced by the key fields'),
  ('wm','fkey_pub','fn_col','eng','For Nat Column','The name of the column in the native referenced by the key component'),
  ('wm','fkey_pub','fn_obj','eng','For Nat Object','Concatenated schema.table for the native table that is referenced by the key fields'),
  ('wm','fkey_pub','unikey','eng','Unikey','Used to differentiate between multiple fkeys pointing to the same destination, and multi-field fkeys pointing to multi-field destinations'),
  ('wm','role_members','role','eng','Role','The name of a role'),
  ('wm','role_members','member','eng','Member','The username of a member of the named role'),
  ('wm','role_members','priv','eng','Privilege','The privilege this role relates to'),
  ('wm','role_members','level','eng','Level','What level this role has in the privilge'),
  ('wm','column_ambig','sch','eng','Schema','The name of the schema this view is in'),
  ('wm','column_ambig','tab','eng','Table','The name of the view'),
  ('wm','column_ambig','col','eng','Column','The name of the column within the view'),
  ('wm','column_ambig','spec','eng','Specified','True if the definitive native table has been specified explicitly in the schema definition files'),
  ('wm','column_ambig','count','eng','Count','The number of possible native tables for this column'),
  ('wm','column_ambig','natives','eng','Natives','A list of the possible native tables for this column'),
  ('wylib','data','ruid','eng','Record ID','A unique ID number generated for each data record'),
  ('wylib','data','component','eng','Component','The part of the graphical, or other user interface that uses this data'),
  ('wylib','data','name','eng','Name','A name explaining the version or configuration this data represents (i.e. Default, Searching, Alphabetical, Urgent, Active, etc.)'),
  ('wylib','data','descr','eng','Description','A full description of what this configuration is for'),
  ('wylib','data','access','eng','Access','Who is allowed to access this data, and how'),
  ('wylib','data','owner','eng','Owner','The user entity who created and has full permission to the data in this record'),
  ('wylib','data','data','eng','JSON Data','A record in JSON (JavaScript Object Notation) in a format known and controlled by the view or other accessing module'),
  ('wylib','data','crt_date','eng','Created','The date this record was created'),
  ('wylib','data','crt_by','eng','Created By','The user who entered this record'),
  ('wylib','data','mod_date','eng','Modified','The date this record was last modified'),
  ('wylib','data','mod_by','eng','Modified By','The user who last modified this record'),
  ('wylib','data_v','own_name','eng','Owner Name','The name of the person who saved this configuration data'),
  ('wylib','data','ruid','fin','Tunnistaa','Kullekin datatietueelle tuotettu yksilöllinen ID-numero'),
  ('wylib','data','component','fin','Komponentti','GUI:n osa joka käyttää tämä data'),
  ('wylib','data','access','fin','Pääsy','Kuka saa käyttää näitä tietoja ja miten'),
  ('base','addr','addr_ent','eng','Entity ID','The ID number of the entity this address applies to'),
  ('base','addr','addr_seq','eng','Sequence','A unique number assigned to each new address for a given entity'),
  ('base','addr','addr_spec','eng','Address','Street address or PO Box.  This can occupy multiple lines if necessary'),
  ('base','addr','addr_type','eng','Type','The kind of address'),
  ('base','addr','addr_prim','eng','Primary','If checked this is the primary address for contacting this entity'),
  ('base','addr','addr_cmt','eng','Comment','Any other notes about this address'),
  ('base','addr','city','eng','City','The name of the city this address is in'),
  ('base','addr','state','eng','State','The name of the state or province this address is in'),
  ('base','addr','pcode','eng','Zip/Postal','Zip or other mailing code applicable to this address.'),
  ('base','addr','country','eng','Country','The name of the country this address is in.  Use standard international country code abbreviations.'),
  ('base','addr','addr_inact','eng','Inactive','If checked this address is no longer a valid address'),
  ('base','addr','dirty','eng','Dirty','A flag used in the database backend to track whether the primary address needs to be recalculated'),
  ('base','addr','crt_date','eng','Created','The date this record was created'),
  ('base','addr','crt_by','eng','Created By','The user who entered this record'),
  ('base','addr','mod_date','eng','Modified','The date this record was last modified'),
  ('base','addr','mod_by','eng','Modified By','The user who last modified this record'),
  ('base','addr_v','std_name','eng','Entity Name','The name of the entity this address pertains to'),
  ('base','addr_v','addr_prim','eng','Primary','If true this is the primary address for contacting this entity'),
  ('base','addr_prim','prim_ent','eng','Entity','The entity ID number of the main address'),
  ('base','addr_prim','prim_seq','eng','Sequence','The sequence number of the main address'),
  ('base','addr_prim','prim_type','eng','type','The address type this record applies to'),
  ('base','addr_v_flat','bill_addr','eng','Bill Address','First line of the billing address'),
  ('base','addr_v_flat','bill_city','eng','Bill City','Billing address city'),
  ('base','addr_v_flat','bill_state','eng','Bill State','Billing address state'),
  ('base','addr_v_flat','bill_country','eng','Bill Country','Billing address country'),
  ('base','addr_v_flat','bill_pcode','eng','Bill Postal','Billing address postal code'),
  ('base','addr_v_flat','ship_addr','eng','Ship Address','First line of the shipping address'),
  ('base','addr_v_flat','ship_city','eng','Ship City','Shipping address city'),
  ('base','addr_v_flat','ship_state','eng','Ship State','Shipping address state'),
  ('base','addr_v_flat','ship_country','eng','Ship Country','Shipping address country'),
  ('base','addr_v_flat','ship_pcode','eng','Ship Postal','Shipping address postal code'),
  ('base','addr_v_flat','phys_addr','eng','Physical Address','First line of the physical address'),
  ('base','addr_v_flat','phys_city','eng','Physical City','Physical address city'),
  ('base','addr_v_flat','phys_state','eng','Physical State','Physical address state'),
  ('base','addr_v_flat','phys_country','eng','Physical Country','Physical address country'),
  ('base','addr_v_flat','phys_pcode','eng','Physical Postal','Physical address postal code'),
  ('base','addr_v_flat','mail_addr','eng','Mailing Address','First line of the mailing address'),
  ('base','addr_v_flat','mail_city','eng','Mailing City','Mailing address city'),
  ('base','addr_v_flat','mail_state','eng','Mailing State','Mailing address state'),
  ('base','addr_v_flat','mail_country','eng','Mailing Country','Mailing address country'),
  ('base','addr_v_flat','mail_pcode','eng','Mailing Postal','ailing address postal code'),
  ('base','comm','comm_ent','eng','Entity','The ID number of the entity this communication point belongs to'),
  ('base','comm','comm_seq','eng','Sequence','A unique number assigned to each new address for a given entity'),
  ('base','comm','comm_spec','eng','Num/Addr','The number or address to use when communication via this method and communication point'),
  ('base','comm','comm_type','eng','Medium','The method of communication'),
  ('base','comm','comm_prim','eng','Primary','If checked this is the primary method of this type for contacting this entity'),
  ('base','comm','comm_cmt','eng','Comment','Any other notes about this communication point'),
  ('base','comm','comm_inact','eng','Inactive','This box is checked to indicate that this record is no longer current'),
  ('base','comm','crt_date','eng','Created','The date this record was created'),
  ('base','comm','crt_by','eng','Created By','The user who entered this record'),
  ('base','comm','mod_date','eng','Modified','The date this record was last modified'),
  ('base','comm','mod_by','eng','Modified By','The user who last modified this record'),
  ('base','comm_v','std_name','eng','Entity Name','The name of the entity this communication point pertains to'),
  ('base','comm_v','comm_prim','eng','Primary','If true this is the primary method of this type for contacting this entity'),
  ('base','comm_prim','prim_ent','eng','Entity','The entity ID number of the main communication point'),
  ('base','comm_prim','prim_seq','eng','Sequence','The sequence number of the main communication point'),
  ('base','comm_prim','prim_spec','eng','Medium','The communication type this record applies to'),
  ('base','comm_prim','prim_type','eng','type','The communication type this record applies to'),
  ('base','comm_v_flat','web_comm','eng','Web Address','The contact''s web page'),
  ('base','comm_v_flat','cell_comm','eng','Cellular','The contact''s cellular phone number'),
  ('base','comm_v_flat','other_comm','eng','Other','Some other communication point for the contact'),
  ('base','comm_v_flat','pager_comm','eng','Pager','The contact''s pager number'),
  ('base','comm_v_flat','fax_comm','eng','Fax','The contact''s FAX number'),
  ('base','comm_v_flat','email_comm','eng','Email','The contact''s email address'),
  ('base','comm_v_flat','text_comm','eng','Text Message','An email address that will send text to the contact''s phone'),
  ('base','comm_v_flat','phone_comm','eng','Phone','The contact''s telephone number'),
  ('base','country','code','eng','Country Code','The ISO 2-letter country code.  This is the offical value to use when entering countries in wylib applications.'),
  ('base','country','com_name','eng','Country','The common name of the country in English'),
  ('base','country','capital','eng','Capital','The name of the capital city'),
  ('base','country','cur_code','eng','Currency','The standard code for the currency of this country'),
  ('base','country','cur_name','eng','Curr Name','The common name in English of the currency of this country'),
  ('base','country','dial_code','eng','Dial Code','The numeric code to dial when calling this country on the phone'),
  ('base','country','iso_3','eng','Code 3','The ISO 3-letter code for this country (not the wylib standard)'),
  ('base','country','iana','eng','Root Domain','The standard extension for WWW domain names for this country'),
  ('base','ent','id','eng','Entity ID','A unique code assigned to each entity, consisting of the entity type and number'),
  ('base','ent','ent_num','eng','Entity Number','A number assigned to each entity, unique within its own group of entities with the same type'),
  ('base','ent','ent_type','eng','Entity Type','The kind of entity this record represents'),
  ('base','ent','ent_cmt','eng','Ent Comment','Any other notes relating to this entity'),
  ('base','ent','ent_name','eng','Entity Name','Company name, personal surname, or group name'),
  ('base','ent','fir_name','eng','First Name','First given (Robert, Susan, William etc.) for person entities only'),
  ('base','ent','mid_name','eng','Middle Names','One or more middle given or maiden names, for person entities only'),
  ('base','ent','pref_name','eng','Preferred','Preferred first name (Bob, Sue, Bill etc.) for person entities only'),
  ('base','ent','title','eng','Title','A title that prefixes the name (Mr., Chief, Dr. etc.)'),
  ('base','ent','born_date','eng','Born Date','Birth date for person entities or optionally, an incorporation date for entities'),
  ('base','ent','gender','eng','Gender','Whether the person is male (m) or female (f)'),
  ('base','ent','marital','eng','Marital Status','Whether the person is married (m) or single (s)'),
  ('base','ent','username','eng','Username','The login name for this person, if a user on this system'),
  ('base','ent','conn_pub','eng','Connection Key','The public key this user uses to authorize connection to the database'),
  ('base','ent','ent_inact','eng','Inactive','A flag indicating that this entity is no longer current, in business, alive, etc'),
  ('base','ent','country','eng','Country','The country of primary citizenship (for people) or legal organization (companies)'),
  ('base','ent','tax_id','eng','TID/SSN','The number by which the country recognizes this person or company for taxation purposes'),
  ('base','ent','bank','eng','Bank Routing','Bank routing information: bank_number<:.;,>account_number'),
  ('base','ent','_last_addr','eng','Addr Sequence','A field used internally to generate unique, sequential record numbers for address records'),
  ('base','ent','_last_comm','eng','Comm Sequence','A field used internally to generate unique, sequential record numbers for communication records'),
  ('base','ent','crt_date','eng','Created','The date this record was created'),
  ('base','ent','crt_by','eng','Created By','The user who entered this record'),
  ('base','ent','mod_date','eng','Modified','The date this record was last modified'),
  ('base','ent','mod_by','eng','Modified By','The user who last modified this record'),
  ('base','ent_v','std_name','eng','Name','The standard format for the entity''s name or, for a person, a standard format: Last, Preferred'),
  ('base','ent_v','frm_name','eng','Formal Name','A person''s full name in a formal format: Last, Title First Middle'),
  ('base','ent_v','cas_name','eng','Casual Name','A person''s full name in a casual format: First Last'),
  ('base','ent_v','giv_name','eng','Given Name','A person''s First given name'),
  ('base','ent_v','age','eng','Age','Age, in years, of the entity'),
  ('base','ent_link','org','eng','Organization ID','The ID of the organization entity that the member entity belongs to'),
  ('base','ent_link','mem','eng','Member ID','The ID of the entity that is a member of the organization'),
  ('base','ent_link','role','eng','Member Role','The function or job description of the member within the organization'),
  ('base','ent_link','supr_path','eng','Super Chain','An ordered list of superiors from the top down for this member in this organization'),
  ('base','ent_link','crt_date','eng','Created','The date this record was created'),
  ('base','ent_link','crt_by','eng','Created By','The user who entered this record'),
  ('base','ent_link','mod_date','eng','Modified','The date this record was last modified'),
  ('base','ent_link','mod_by','eng','Modified By','The user who last modified this record'),
  ('base','ent_link_v','org_name','eng','Org Name','The name of the organization or group entity the member belongs to'),
  ('base','ent_link_v','mem_name','eng','Member Name','The name of the person who belongs to the organization'),
  ('base','ent_link_v','role','eng','Role','The job description or duty of the member with respect to the organization he belongs to'),
  ('base','ent_audit','id','eng','Entity ID','The ID of the entity that was changed'),
  ('base','ent_audit','a_seq','eng','Sequence','A sequential number unique to each alteration'),
  ('base','ent_audit','a_date','eng','Date/Time','Date and time of the change'),
  ('base','ent_audit','a_by','eng','Altered By','The username of the user who made the change'),
  ('base','ent_audit','a_action','eng','Action','The operation that produced the change (update, delete)'),
  ('base','ent_audit','a_column','eng','Column','The name of the column that was changed'),
  ('base','ent_audit','a_value','eng','Value','The old value of the column before the change'),
  ('base','ent_audit','a_reason','eng','Reason','The reason for the change'),
  ('base','language','code','eng','Language Code','The ISO 3-letter language code.  Where a native T-code exists, it is the one used here.'),
  ('base','language','iso_3b','eng','Biblio Code','The ISO bibliographic 3-letter code for this language'),
  ('base','language','iso_2','eng','Code 2','The ISO 2-letter code for this language, if it exists'),
  ('base','language','eng_name','eng','Name in English','The common name of the language English'),
  ('base','language','fra_name','eng','Name in French','The common name of the language in French'),
  ('base','token','token_ent','eng','Token Entity','The id of the user or entity this token is generated for'),
  ('base','token','token_seq','eng','Entity ID','A sequential number assigned to each new token, unique to the user the tokens are for'),
  ('base','token','token','eng','Token','An automatically generated code the user will present to get access'),
  ('base','token','allows','eng','Allowed Access','The type of access this token authorizes.  The value "login" grants the user permission to log in.'),
  ('base','token','used','eng','Used','A time stamp showing when the token was presented back to the system'),
  ('base','token','expires','eng','Expires','A time stamp showing when the token will no longer be valid because it has been too long since it was issued'),
  ('base','token','crt_date','eng','Created','The date this record was created'),
  ('base','token','crt_by','eng','Created By','The user who entered this record'),
  ('base','token','mod_date','eng','Modified','The date this record was last modified'),
  ('base','token','mod_by','eng','Modified By','The user who last modified this record'),
  ('base','token_v','expired','eng','Expired','Indicates that this token is no longer valid because too much time has gone by since it was issued'),
  ('base','token_v','valid','eng','Valid','This token can still be used if it has not yet expired and has never yet been used to connect'),
  ('base','token_v','username','eng','Username','The login name of the user this token belongs to'),
  ('base','token_v','std_name','eng','Name','The standard format for the entity''s name or, for a person, a standard format: Last, Preferred'),
  ('base','token_v_ticket','host','eng','Host','The host name of a computer for the user to connect to using this new ticket'),
  ('base','token_v_ticket','port','eng','Port','The port number the user will to connect to using this new ticket'),
  ('base','parm','module','eng','Module','The system or module within the ERP this setting is applicable to'),
  ('base','parm','parm','eng','Name','The name of the parameter setting'),
  ('base','parm','cmt','eng','Comment','Notes you may want to add about why the setting is set to a particular value'),
  ('base','parm','type','eng','Data Type','Indicates the native data type of this paramter (and hence the particular underlying table it will be stored in.)'),
  ('base','parm','v_int','eng','Integer Value','The parameter value in the case when the type is an integer'),
  ('base','parm','v_date','eng','Date Value','The parameter value in the case when the type is a date'),
  ('base','parm','v_text','eng','Text Value','The parameter value in the case when the type is a character string'),
  ('base','parm','v_float','eng','Float Value','The parameter value in the case when the type is a real number'),
  ('base','parm','v_boolean','eng','Boolean Value','The parameter value in the case when the type is a boolean (true/false) value'),
  ('base','parm','crt_date','eng','Created','The date this record was created'),
  ('base','parm','crt_by','eng','Created By','The user who entered this record'),
  ('base','parm','mod_date','eng','Modified','The date this record was last modified'),
  ('base','parm','mod_by','eng','Modified By','The user who last modified this record'),
  ('base','parm_v','value','eng','Value','The value for the parameter setting, expressed as a string'),
  ('base','parm_audit','module','eng','Module','The module name for the parameter that was changed'),
  ('base','parm_audit','parm','eng','Parameter','The parameter name that was changed'),
  ('base','parm_audit','a_seq','eng','Sequence','A sequential number unique to each alteration'),
  ('base','parm_audit','a_date','eng','Date/Time','Date and time of the change'),
  ('base','parm_audit','a_by','eng','Altered By','The username of the user who made the change'),
  ('base','parm_audit','a_action','eng','Action','The operation that produced the change (update, delete)'),
  ('base','parm_audit','a_column','eng','Column','The name of the column that was changed'),
  ('base','parm_audit','a_value','eng','Value','The old value of the column before the change'),
  ('base','parm_audit','a_reason','eng','Reason','The reason for the change'),
  ('base','priv','grantee','eng','Grantee','The username of the entity receiving the privilege'),
  ('base','priv','priv','eng','Privilege','The name of the privilege being granted'),
  ('base','priv','level','eng','Access Level','What level of access within this privilege.  This is normally null for a group or role privilege or a number from 1 to 3.  1 means limited access, 2 is for normal access, and 3 means supervisory access.'),
  ('base','priv','priv_level','eng','Priv Level','Shows the name the privilege level will refer to in the database.  This is formed by joining the privilege name and the level (if present) with an underscore.'),
  ('base','priv','cmt','eng','Comment','Comments about this privilege allocation to this user'),
  ('base','priv_v','std_name','eng','Entity Name','The name of the entity being granted the privilege'),
  ('base','priv_v','priv_list','eng','Priv List','In the case where the privilege refers to a group role, this shows which underlying privileges belong to that role.'),
  ('base','priv_v','username','eng','Username','The username within the database for this entity');

insert into wm.value_text (vt_sch,vt_tab,vt_col,value,language,title,help) values
  ('wylib','data','access','priv','eng','Private','Only the owner of this data can read, write or delete it'),
  ('wylib','data','access','read','eng','Public Read','The owner can read and write, all others can read, or see it'),
  ('wylib','data','access','write','eng','Public Write','Anyone can read, write, or delete this data'),
  ('wylib','data','access','priv','fin','Yksityinen','Vain näiden tietojen omistaja voi lukea, kirjoittaa tai poistaa sen'),
  ('wylib','data','access','read','fin','Julkinen Lukea','Omistaja voi lukea ja kirjoittaa, kaikki muut voivat lukea tai nähdä sen'),
  ('wylib','data','access','write','fin','Julkinen Kirjoittaa','Jokainen voi lukea, kirjoittaa tai poistaa näitä tietoja'),
  ('base','addr','addr_type','phys','eng','Physical','Where the entity has people living or working'),
  ('base','addr','addr_type','mail','eng','Mailing','Where mail and correspondence is received'),
  ('base','addr','addr_type','ship','eng','Shipping','Where materials are picked up or delivered'),
  ('base','addr','addr_type','bill','eng','Billing','Where invoices and other accounting information are sent'),
  ('base','comm','comm_type','phone','eng','Phone','A way to contact the entity via telephone'),
  ('base','comm','comm_type','email','eng','Email','A way to contact the entity via email'),
  ('base','comm','comm_type','cell','eng','Cell','A way to contact the entity via cellular telephone'),
  ('base','comm','comm_type','fax','eng','FAX','A way to contact the entity via faxsimile'),
  ('base','comm','comm_type','text','eng','Text Message','A way to contact the entity via email to text messaging'),
  ('base','comm','comm_type','web','eng','Web Address','A World Wide Web address URL for this entity'),
  ('base','comm','comm_type','pager','eng','Pager','A way to contact the entity via a mobile pager'),
  ('base','comm','comm_type','other','eng','Other','Some other contact method for the entity'),
  ('base','ent','ent_type','p','eng','Person','The entity is an individual'),
  ('base','ent','ent_type','o','eng','Organization','The entity is an organization (such as a company or partnership) which may employ or include members of individual people or other organizations'),
  ('base','ent','ent_type','g','eng','Group','The entity is a group of people, companies, and/or other groups'),
  ('base','ent','ent_type','r','eng','Role','The entity is a role or position that may not correspond to a particular person or company'),
  ('base','ent','gender','','eng','N/A','Gender is not applicable (such as for organizations or groups)'),
  ('base','ent','gender','m','eng','Male','The person is male'),
  ('base','ent','gender','f','eng','Female','The person is female'),
  ('base','ent','marital','','eng','N/A','Marital status is not applicable (such as for organizations or groups)'),
  ('base','ent','marital','m','eng','Married','The person is in a current marriage'),
  ('base','ent','marital','s','eng','Single','The person has never married or is divorced or is the survivor of a deceased spouse'),
  ('base','parm','type','int','eng','Integer','The parameter can contain only values of integer type (... -2, -1, 0, 1, 2 ...'),
  ('base','parm','type','date','eng','Date','The parameter can contain only date values'),
  ('base','parm','type','text','eng','Text','The parameter can contain any text value'),
  ('base','parm','type','float','eng','Float','The parameter can contain only values of floating point type (integer portion, decimal, fractional portion)'),
  ('base','parm','type','boolean','eng','Boolean','The parameter can contain only the values of true or false');

insert into wm.message_text (mt_sch,mt_tab,code,language,title,help) values
  ('wylib','data','IAT','eng','Invalid Access Type','Access type must be: priv, read, or write'),
  ('wylib','data','appSave','eng','Save State','Re-save the layout and operating state of the application to the current named configuration, if there is one'),
  ('wylib','data','appSaveAs','eng','Save State As','Save the layout and operating state of the application, and all its subordinate windows, using a named configuration'),
  ('wylib','data','appRestore','eng','Load State','Restore the application layout and operating state from a previously saved state'),
  ('wylib','data','appPrefs','eng','Preferences','View/edit settings for the application or for a subcomponent'),
  ('wylib','data','appDefault','eng','Default State','Reload the application to its default state (you will lose any unsaved configuration state, including connection keys)!'),
  ('wylib','data','appStatePrompt','eng','State ID Tag','The name or words you will use to identify this saved state when considering it for later recall'),
  ('wylib','data','appStateTag','eng','State Tag','The tag is a brief name you will refer to later when loading the saved state'),
  ('wylib','data','appStateDescr','eng','State Description','A full description of the saved state and what you use it for'),
  ('wylib','data','appEditState','eng','Edit States','Preview a list of saved states for this application'),
  ('wylib','data','appServer','eng','Server','Toggle menu for connecting to various servers'),
  ('wylib','data','appServerURL','eng','Server URL','The domain and port of the server you are currently connected to'),
  ('wylib','data','appNoConnect','eng','Not Connected','The application is not connected to a backend server'),
  ('wylib','data','appLocalAsk','eng','Store Data in Browser','OK means the app can store sensitive information in your browser, including your private connection key.  This could be snooped by others who may have access to this computer!  If they get your key, they can connect to your data, logged in as you!  Cancel to not store application data in the browser.'),
  ('wylib','data','appLocalPrompt','eng','Login Prompt','The app will show you this prompt each time you load the application in order to ask for your pass phrase'),
  ('wylib','data','appLocalP1','eng','Your Pass Phrase','Enter a pass phrase which will be used to unlock your local storage, including connection keys.  If you leave this blank and press OK, your data will be stored unencrypted!'),
  ('wylib','data','appLocalP2','eng','Pass Phrase Check','Enter the pass phrase a second time'),
  ('wylib','data','conmenu','eng','Connection Menu','Various helper functions to control how you connect to server sites, and manage your connection keys'),
  ('wylib','data','conTitle','eng','Connection Keys','A list of credentials, servers and ports where you normally connect.  Get a ticket from the site administrator where you want to connect.'),
  ('wylib','data','conConnect','eng','Connect','Attempt to connect to, or disconnect from the selected server'),
  ('wylib','data','conDelete','eng','Delete','Remove the selected server connections from the list'),
  ('wylib','data','conImport','eng','Import Keys','Drag/drop key files here, or click to import a connection key, or one-time connection ticket'),
  ('wylib','data','conExport','eng','Export Keys','Save the selected private connection keys out to a file.  Delete these files immediately after moving them to a private backup device.  Never leave them in the download area or on a live file system!'),
  ('wylib','data','conRetry','eng','Retrying in','Will attempt to automatically reconnect to the server'),
  ('wylib','data','conExpFile','eng','Key Filename','The file name to use for saving the selected private keys'),
  ('wylib','data','conUsername','eng','Username','Input the name you will use to connect to the backend database.  If you don''t know.  Ask the person who issued your connection ticket.'),
  ('wylib','data','conNoCrypto','eng','No Crypto Library','Cryptographic functions not found in browser API.  Make sure you are connected by https, or use a more modern browser.'),
  ('wylib','data','conCryptErr','eng','Generating Key','There was an error in the browser attempting to generate a connection key'),
  ('wylib','data','dbe','eng','Edit Records','Insert, change and delete records from the database view'),
  ('wylib','data','dbeColMenu','eng','Column','Operations you can perform on this column of the preview'),
  ('wylib','data','dbeMenu','eng','Editing','A menu of functions for editing a database record'),
  ('wylib','data','dbeInsert','eng','Add New','Insert a new record into the database table'),
  ('wylib','data','dbeUpdate','eng','Update','Modify changed fields in the existing database record'),
  ('wylib','data','dbeDelete','eng','Delete','Delete this database record (can not be un-done)'),
  ('wylib','data','dbeClear','eng','Clear','Empty the editing fields, discontinue editing any database record that may have been loaded'),
  ('wylib','data','dbeLoadRec','eng','Load Record','Load a specific record from the database by its primary key'),
  ('wylib','data','dbePrimary','eng','Primary Key','The value that uniquely identifies the current record among all the rows in the database table'),
  ('wylib','data','dbeActions','eng','Actions','Perform various commands pertaining to this particular view and record'),
  ('wylib','data','dbePreview','eng','Preview Document','Preview this record as a document'),
  ('wylib','data','dbeSubords','eng','Preview','Toggle the viewing of views and records which relate to the currently loaded record'),
  ('wylib','data','dbeLoadPrompt','eng','Primary Key Value(s)','Input the primary key field values for the record you want to load'),
  ('wylib','data','dbeRecordID','eng','Record ID','Load a record by specifying its primary key values directly'),
  ('wylib','data','dbePopupErr','eng','Popup Error','Error trying to open a child window.  Is the browser blocking popup windows?'),
  ('wylib','data','dbeOption','eng','Optional Fields','Show additional information about this record'),
  ('wylib','data','dbeNoPkey','eng','No Primary key','The report update could not determine the primary key fields for the record.  Any changes may be lost.'),
  ('wylib','data','winMenu','eng','Window Functions','A menu of functions for the display and operation of this window'),
  ('wylib','data','winSave','eng','Save State','Re-save the layout and operating state of this window to the current named configuration, if there is one'),
  ('wylib','data','winSaveAs','eng','Save State As','Save the layout and operating state of this window, and all its subordinate windows, to a named configuration'),
  ('wylib','data','winRestore','eng','Load State','Restore the the window''s layout and operating state from a previously saved state'),
  ('wylib','data','winGeom','eng','Default Geometry','Let this window size itself according to its default setting'),
  ('wylib','data','winDefault','eng','Default State','Erase locally stored configuration data for this window'),
  ('wylib','data','winModified','eng','Close Modified Pane','Changes may be lost if you close the window'),
  ('wylib','data','winPinned','eng','Window Pinned','Keep this window open until it is explicitly closed'),
  ('wylib','data','winClose','eng','Close Window','Close this window'),
  ('wylib','data','winToTop','eng','Move To Top','Make this window show above others of its peers (can also double click on a window header)'),
  ('wylib','data','winToBottom','eng','Move To Bottom','Place this window behind others of its peers'),
  ('wylib','data','winMinimize','eng','Minimize','Shrink window down to an icon by which it can be re-opened'),
  ('wylib','data','winPopUp','eng','Printable Popup','Make a copy, if possible, of this window in a separate popup window so it can be printed, separate from the rest of the page'),
  ('wylib','data','winPrint','eng','Print Document','Find the nearest independent document (iframe) within this component, and print it'),
  ('wylib','data','winUnknown','eng','Unknown Message','An error or query was generated that could not be understood by the program'),
  ('wylib','data','winUnCode','eng','Unknown Error Code','An error message was returned with an unrecognized code or status'),
  ('wylib','data','dbp','eng','Preview','A window for showing the records of a database table in a grid like a spreadsheet'),
  ('wylib','data','dbpMenu','eng','Preview Menu','A menu of functions for operating on the preview list below'),
  ('wylib','data','dbpReload','eng','Reload','Reload the records specified in the previous load'),
  ('wylib','data','dbpLoad','eng','Load Default','Load the records normally displayed in this view'),
  ('wylib','data','dbpLoadAll','eng','Load All','Load all records from this table'),
  ('wylib','data','dbpClear','eng','Clear Preview','Remove contents of the preview window, with no records loaded'),
  ('wylib','data','dbpDefault','eng','Default Columns','Set all column display and order to the database default'),
  ('wylib','data','dbpFilter','eng','Filter','Load records according to filter criteria'),
  ('wylib','data','dbpAutoLoad','eng','Auto Execute','Automatically execute the top row any time the preview is reloaded'),
  ('wylib','data','dbpLoaded','eng','Loaded Records','How many records are currently loaded in the preview'),
  ('wylib','data','dbpShowSum','eng','Show Summaries','Show a summary row at the bottom of the preview.  Use context menu in column to determine which summary function for each column.'),
  ('wylib','data','dbpColumn','eng','Column Menu','Menu of commands to control this column display'),
  ('wylib','data','dbpVisible','eng','Visible','Specify which columns are visible in the preview'),
  ('wylib','data','dbpVisCheck','eng','Visible','Check the box to make this column visible'),
  ('wylib','data','dbpColAuto','eng','Auto Size','Adjust the width of this column to be optimal for its contents'),
  ('wylib','data','dbpColHide','eng','Hide Column','Remove this column from the display'),
  ('wylib','data','dbpNext','eng','Next Record','Move the selection down one line and execute (normally edit) that new line'),
  ('wylib','data','dbpPrev','eng','Prior Record','Move the selection up one line and execute (normally edit) that new line'),
  ('wylib','data','dbpNoPkey','eng','No Primary key','The system could not determine the primary key fields for this table or view'),
  ('wylib','data','dbpExport','eng','Export Records','Save the selected records to a local file'),
  ('wylib','data','dbpExportAsk','eng','Export File','Supply a filename to use when exporting'),
  ('wylib','data','dbpExportFmt','eng','Pretty','Export the file with indentation to make it more easily readable by people'),
  ('wylib','data','X.dbpColSel','eng','Visible Columns','Show or hide individual columns'),
  ('wylib','data','X.dbpFooter','eng','Footer','Check the box to turn on column summaries, at the bottom'),
  ('wylib','data','dbs','eng','Filter Search','Load records according to filter criteria'),
  ('wylib','data','dbsSearch','eng','Query Search','Run the configured selection query, returning matching records'),
  ('wylib','data','dbsClear','eng','Clear Query','Clear all logic terms'),
  ('wylib','data','dbsDefault','eng','Default Load','Load the query indicating how records are normally loaded (by default) from this table'),
  ('wylib','data','dbsSave','eng','Save Query','Save the current query for future use'),
  ('wylib','data','dbsRecall','eng','Recall Query','Recall a named query which has been previously saved'),
  ('wylib','data','dbsEqual','eng','=','The left and right side of the comparison are equal'),
  ('wylib','data','dbsLess','eng','<','The left value is less than the value on the right'),
  ('wylib','data','dbsLessEq','eng','<=','The left value is less than or equal to the value on the right'),
  ('wylib','data','dbsMore','eng','>','The left value is greater than the value on the right'),
  ('wylib','data','dbsMoreEq','eng','>=','The left value is greater than or equal to the value on the right'),
  ('wylib','data','dbsRexExp','eng','~','The left value matches a regular expression given by the value on the right'),
  ('wylib','data','dbsDiff','eng','Diff','The left side is different from the right, in a comparison where two nulls (unassigned values) can be thought of as being the same'),
  ('wylib','data','dbsIn','eng','In','The left value exists in a comma separated list you specify, or an array in another database field'),
  ('wylib','data','dbsNull','eng','Null','The value on the left is a null, or not assigned'),
  ('wylib','data','dbsTrue','eng','True','The left value is a boolean with a true value'),
  ('wylib','data','dbsNop','eng','<Nop>','This operation causes the whole comparison clause to be ignored'),
  ('wylib','data','diaDialog','eng','Dialog','Query user for specified input values or parameters'),
  ('wylib','data','diaReport','eng','Report','Report window'),
  ('wylib','data','diaOK','eng','OK','Acknowledge you have seen the posted message'),
  ('wylib','data','diaYes','eng','OK','Proceed with the proposed operation and close the dialog'),
  ('wylib','data','diaCancel','eng','Cancel','Abandon the operation associated with the dialog'),
  ('wylib','data','diaApply','eng','Perform','Perform the action associated with this dialog, but do not close it'),
  ('wylib','data','diaError','eng','Error','Something went wrong'),
  ('wylib','data','diaNotice','eng','Notice','The message is a warning or advice for the user'),
  ('wylib','data','diaConfirm','eng','Confirm','The user is asked to confirm before proceeding, or cancel to abandon the operation'),
  ('wylib','data','diaQuery','eng','Input','The user is asked for certain input data, and a confirmation before proceeding'),
  ('wylib','data','mdewMore','eng','More Fields','Click to see more data fields pertaining to this record'),
  ('wylib','data','23505','eng','Key Violation','An operation would have resulted in multiple records having duplicated data, which is required to be unique'),
  ('wylib','data','subWindow','eng','Subordinate View','Open a preview of records in another table that relate to the currently loaded record from this view'),
  ('wylib','data','litToSub','eng','To Subgroup','Move this item to a deeper sub-group'),
  ('wylib','data','litLeft','eng','Left Side','Specify a field from the database to compare'),
  ('wylib','data','litRight','eng','Right Side','Specify a field from the database, or manual entry to compare'),
  ('wylib','data','litManual','eng','Manual Entry','Enter a value manually to the right'),
  ('wylib','data','litRightVal','eng','Right Value','Specify an explicit right-hand value for the comparision'),
  ('wylib','data','litRemove','eng','Remove Item','Remove this item from the comparison list'),
  ('wylib','data','litNot','eng','Not','If asserted, the sense of the comparison will be negated, or made opposite'),
  ('wylib','data','litCompare','eng','Comparison','Specify an operator for the comparison'),
  ('wylib','data','lstAndOr','eng','And/Or','Specify whether all conditions must be true (and), or just one or more (or)'),
  ('wylib','data','lstAddCond','eng','Add Condition','Add another condition for comparison'),
  ('wylib','data','lstRemove','eng','Remove Grouping','Remove this group of conditions'),
  ('wylib','data','lchAdd','eng','Launch Preview','Use this button to open as many new database previews as you like'),
  ('wylib','data','lchImport','eng','Importer','Drag/drop files here, or click and browse, to import data from a JSON formatted file'),
  ('wylib','data','sdc','eng','Structured Document','An editor for documents structured in an outline format'),
  ('wylib','data','sdcMenu','eng','Document Menu','A menu of functions for working with structured documents'),
  ('wylib','data','sdcUpdate','eng','Update','Save changes to this document back to the database'),
  ('wylib','data','sdcUndo','eng','Undo','Reverse the effect of a paragraph deletion or move'),
  ('wylib','data','sdcClear','eng','Clear','Delete the contents of the document on the screen.  Does not affect the database.'),
  ('wylib','data','sdcClearAsk','eng','Clear WorkSpace','Are you sure you want to clear the document data?'),
  ('wylib','data','sdcImport','eng','File Import','Load the workspace from an externally saved file'),
  ('wylib','data','sdcImportAsk','eng','Import From File','Select a file to Import, or drag it onto the import button'),
  ('wylib','data','sdcExport','eng','Export To File','Save the document to an external file'),
  ('wylib','data','sdcExportAsk','eng','Export File','Input a filename to use when exporting'),
  ('wylib','data','sdcExportFmt','eng','Pretty','Export the file with indentation to make it more easily readable by people'),
  ('wylib','data','sdcSpell','eng','Spell Checking','Enable/disable spell checking in on the screen'),
  ('wylib','data','sdcBold','eng','Bold','Mark the highlighted text as bold'),
  ('wylib','data','sdcItalic','eng','Italic','Mark the highlighted text as italic'),
  ('wylib','data','sdcUnder','eng','Underline','Underline highlighted text'),
  ('wylib','data','sdcCross','eng','Cross Reference','Wrap the highlighted text with a cross reference.  The text should be a tag name for another section.  That section number will be substituted for the tag name.'),
  ('wylib','data','sdcTitle','eng','Title','An optional title for this section or paragraph'),
  ('wylib','data','sdcSection','eng','Section','Click to edit text.  Double click at edge for direct editing mode.  Drag at edge to move.'),
  ('wylib','data','sdcTag','eng','Tag','An identifying word that can be used to cross-reference to this section or paragraph'),
  ('wylib','data','sdcText','eng','Paragraph Text','Insert/Edit the raw paragraph text directly here, including entering limited HTML tags, if desired'),
  ('wylib','data','sdcSource','eng','Source','The URL of another document which will be incorporated into this document by reference'),
  ('wylib','data','sdcReference','eng','Reference','The following external document is incorporated by reference, becoming a part of this document'),
  ('wylib','data','sdcTogSource','eng','Add Reference','Use this section to refer to some external document by its URL'),
  ('wylib','data','sdcEdit','eng','Direct Editing','This section or paragraph is in direct editing mode.  Double click on the background to return to preview mode.'),
  ('wylib','data','sdcPreview','eng','Preview Mode','This section or paragraph is in preview mode.  Double click on the background to go to editing mode.'),
  ('wylib','data','sdcAdd','eng','Add Subsection','Create a new paragraph or section nested below this one'),
  ('wylib','data','sdcDelete','eng','Delete Section','Delete this section of the document, and all its subsections'),
  ('wylib','data','sdcEditAll','eng','Edit All','Put all paragraphs or sections into direct editing mode.  This can be done one at a time by double clicking on the paragraph.'),
  ('wylib','data','sdcPrevAll','eng','Preview All','Take all paragraphs or sections out of direct editing mode, and into preview mode'),
  ('wylib','data','X','eng',null,null),
  ('wylib','data','IAT','fin','Virheellinen käyttötyyppi','Käytön tyypin on oltava: priv, lukea tai kirjoittaa'),
  ('wylib','data','dbpMenu','fin','Esikatselu','Toimintojen valikko, joka toimii alla olevassa esikatselussa'),
  ('wylib','data','dbpReload','fin','Ladata','Päivitä edellisessä kuormassa määritetyt tietueet'),
  ('wylib','data','dbpLoad','fin','Ladata Oletus','Aseta tässä näkymässä näkyvät kirjaukset oletuksena'),
  ('wylib','data','dbpLoadAll','fin','Loadata Kaikki','Lataa kaikki taulukon tiedot'),
  ('wylib','data','dbpFilter','fin','Suodattaa','Lataa tietueet suodatuskriteerien mukaisesti'),
  ('wylib','data','dbpVisible','fin','Näkyvyys','Sarakkeiden valikko, josta voit päättää, mitkä näkyvät esikatselussa'),
  ('wylib','data','dbpVisCheck','fin','Ilmoita näkyvyydestä','Kirjoita tämä ruutu näkyviin, jotta tämä sarake voidaan näyttää'),
  ('wylib','data','dbpFooter','fin','Yhteenveto','Ota ruutuun käyttöön sarakeyhteenveto'),
  ('wylib','data','dbeActions','fin','Tehköjä','Tehdä muutamia asioita tämän mukaisesti'),
  ('base','addr','CCO','eng','Country','The country must always be specified (and in standard form)'),
  ('base','addr','CPA','eng','Primary','There must be at least one address checked as primary'),
  ('base','comm','CPC','eng','Primary','There must be at least one communication point of each type checked as primary'),
  ('base','ent','CFN','eng','First Name','A first name is required for personal entities'),
  ('base','ent','CMN','eng','Middle Name','A middle name is prohibited for non-personal entities'),
  ('base','ent','CPN','eng','Pref Name','A preferred name is prohibited for non-personal entities'),
  ('base','ent','CTI','eng','Title','A preferred title is prohibited for non-personal entities'),
  ('base','ent','CGN','eng','Gender','Gender must not be specified for non-personal entities'),
  ('base','ent','CMS','eng','Marital','Marital status must not be specified for non-personal entities'),
  ('base','ent','CBD','eng','Born Date','A born date is required for inside people'),
  ('base','ent','CPA','eng','Prime Addr','A primary address must be active'),
  ('base','ent_v','directory','eng','Directory','Report showing basic contact data for the selected entities'),
  ('base','ent_link','NBP','eng','Illegal Entity Org','A personal entity can not be an organization (and have member entities)'),
  ('base','ent_link','PBC','eng','Illegal Entity Member','Only personal entities can belong to company entities'),
  ('base','parm_v','launch.title','eng','Settings','Site Operating Parameters'),
  ('base','parm_v','launch.instruct','eng','Basic Instructions','
      <p>These settings control all kinds of different options on your system.
      <p>Each setting is interpreted within the context of the module it is intended for.
         System settings have descriptions initialized in the table.  Although you may be
         able to change these, you probably shouldn''t as they are installed there by the
         schema author to help you understand what the setting controls.
    '),
  ('base','priv','CLV','eng','Illegal Level','The privilege level must be null or a positive integer between 1 and 9'),
  ('base','priv_v','suspend','eng','Suspend User','Disable permissions for this user (not yet implemented)');

insert into wm.table_style (ts_sch,ts_tab,sw_name,sw_value,inherit) values
  ('wm','table_text','focus','"code"','t'),
  ('wm','column_text','focus','"code"','t'),
  ('wm','value_text','focus','"code"','t'),
  ('wm','message_text','focus','"code"','t'),
  ('wm','column_pub','focus','"code"','t'),
  ('wm','objects','focus','"obj_nam"','t');

insert into wm.column_style (cs_sch,cs_tab,cs_col,sw_name,sw_value) values
  ('wm','table_text','language','size','4'),
  ('wm','table_text','title','size','40'),
  ('wm','table_text','help','size','40'),
  ('wm','table_text','help','special','edw'),
  ('wm','table_text','code','focus','true'),
  ('wm','column_text','language','size','4'),
  ('wm','column_text','title','size','40'),
  ('wm','column_text','help','size','40'),
  ('wm','column_text','help','special','edw'),
  ('wm','column_text','code','focus','true'),
  ('wm','value_text','language','size','4'),
  ('wm','value_text','title','size','40'),
  ('wm','value_text','help','size','40'),
  ('wm','value_text','help','special','edw'),
  ('wm','value_text','code','focus','true'),
  ('wm','message_text','language','size','4'),
  ('wm','message_text','title','size','40'),
  ('wm','message_text','help','size','40'),
  ('wm','message_text','help','special','edw'),
  ('wm','message_text','code','focus','true'),
  ('wm','column_pub','language','size','4'),
  ('wm','column_pub','title','size','40'),
  ('wm','column_pub','help','size','40'),
  ('wm','column_pub','help','special','edw'),
  ('wm','column_pub','code','focus','true'),
  ('wm','objects','name','size','40'),
  ('wm','objects','checked','size','4'),
  ('wm','objects','clean','size','4'),
  ('wm','objects','mod_ver','size','4'),
  ('wm','objects','deps','size','40'),
  ('wm','objects','deps','special','edw'),
  ('wm','objects','ndeps','size','40'),
  ('wm','objects','ndeps','special','edw'),
  ('wm','objects','grants','size','40'),
  ('wm','objects','grants','special','edw'),
  ('wm','objects','col_data','size','40'),
  ('wm','objects','col_data','special','edw'),
  ('wm','objects','crt_sql','size','40'),
  ('wm','objects','crt_sql','special','edw'),
  ('wm','objects','drp_sql','size','40'),
  ('wm','objects','drp_sql','special','edw'),
  ('wm','objects','min_rel','size','4'),
  ('wm','objects','max_rel','size','4'),
  ('wm','objects','obj_nam','focus','true');

insert into wm.column_native (cnt_sch,cnt_tab,cnt_col,nat_sch,nat_tab,nat_col,nat_exp,pkey) values
  ('base','country','cur_name','base','country','cur_name','f','f'),
  ('base','language','eng_name','base','language','eng_name','f','f'),
  ('base','comm_v','comm_inact','base','comm','comm_inact','f','f'),
  ('base','comm','comm_inact','base','comm','comm_inact','f','f'),
  ('wylib','data_v','mod_date','wylib','data','mod_date','f','f'),
  ('base','comm_v','mod_date','base','comm','mod_date','f','f'),
  ('base','addr_v','mod_date','base','addr','mod_date','f','f'),
  ('base','token_v','mod_date','base','token','mod_date','f','f'),
  ('wylib','data','mod_date','wylib','data','mod_date','f','f'),
  ('base','ent_v_pub','mod_date','base','ent','mod_date','f','f'),
  ('base','ent_link_v','mod_date','base','ent_link','mod_date','f','f'),
  ('base','parm_v','mod_date','base','parm','mod_date','f','f'),
  ('base','ent_v','mod_date','base','ent','mod_date','f','f'),
  ('base','token','mod_date','base','token','mod_date','f','f'),
  ('base','parm','mod_date','base','parm','mod_date','f','f'),
  ('base','ent_link','mod_date','base','ent_link','mod_date','f','f'),
  ('base','comm','mod_date','base','comm','mod_date','f','f'),
  ('base','addr','mod_date','base','addr','mod_date','f','f'),
  ('base','ent','mod_date','base','ent','mod_date','f','f'),
  ('wm','objects_v_depth','mod_date','wm','objects','mod_date','f','f'),
  ('wm','objects_v','mod_date','wm','objects','mod_date','f','f'),
  ('wm','objects','mod_date','wm','objects','mod_date','f','f'),
  ('base','addr_v_flat','ship_state','base','addr_v_flat','ship_state','f','f'),
  ('base','addr_v','addr_prim','base','addr_v','addr_prim','f','f'),
  ('base','addr','addr_prim','base','addr','addr_prim','f','f'),
  ('base','ent_v','ent_name','base','ent','ent_name','f','f'),
  ('base','ent','ent_name','base','ent','ent_name','f','f'),
  ('base','comm_v_flat','cell_comm','base','comm_v_flat','cell_comm','f','f'),
  ('base','addr_v_flat','phys_city','base','addr_v_flat','phys_city','f','f'),
  ('wm','column_native','nat_exp','wm','column_native','nat_exp','f','f'),
  ('wm','depends_v','od_release','wm','depends_v','od_release','f','f'),
  ('base','addr_v_flat','mail_addr','base','addr_v_flat','mail_addr','f','f'),
  ('base','parm_audit','a_column','base','parm_audit','a_column','f','f'),
  ('base','ent_audit','a_column','base','ent_audit','a_column','f','f'),
  ('base','ent_v','bank','base','ent','bank','f','f'),
  ('base','ent','bank','base','ent','bank','f','f'),
  ('base','addr_v_flat','phys_state','base','addr_v_flat','phys_state','f','f'),
  ('base','ent_v','giv_name','base','ent_v','giv_name','f','f'),
  ('wm','depends_v','od_typ','wm','depends_v','od_typ','f','f'),
  ('base','country','com_name','base','country','com_name','f','f'),
  ('wm','column_style','sw_value','wm','column_style','sw_value','f','f'),
  ('wm','table_style','sw_value','wm','table_style','sw_value','f','f'),
  ('base','token_v_ticket','token','base','token','token','f','f'),
  ('base','token_v','token','base','token','token','f','f'),
  ('base','ent_link_v','org_name','base','ent_link_v','org_name','f','f'),
  ('base','token','token','base','token','token','f','f'),
  ('base','country','cur_code','base','country','cur_code','f','f'),
  ('base','addr_v_flat','ship_country','base','addr_v_flat','ship_country','f','f'),
  ('base','parm_audit','a_value','base','parm_audit','a_value','f','f'),
  ('base','ent_audit','a_value','base','ent_audit','a_value','f','f'),
  ('base','addr_v_flat','phys_pcode','base','addr_v_flat','phys_pcode','f','f'),
  ('base','addr_v_flat','bill_state','base','addr_v_flat','bill_state','f','f'),
  ('base','ent_v','fir_name','base','ent','fir_name','f','f'),
  ('base','ent','fir_name','base','ent','fir_name','f','f'),
  ('base','addr_v_flat','ship_pcode','base','addr_v_flat','ship_pcode','f','f'),
  ('base','parm','v_int','base','parm','v_int','f','f'),
  ('wm','depends_v','fpath','wm','depends_v','fpath','f','f'),
  ('base','parm_audit','a_reason','base','parm_audit','a_reason','f','f'),
  ('base','ent_audit','a_reason','base','ent_audit','a_reason','f','f'),
  ('wm','depends_v','depend','wm','depends_v','depend','f','f'),
  ('base','addr_v_flat','bill_country','base','addr_v_flat','bill_country','f','f'),
  ('wm','depends_v','cycle','wm','depends_v','cycle','f','f'),
  ('wylib','data_v','descr','wylib','data','descr','f','f'),
  ('wylib','data','descr','wylib','data','descr','f','f'),
  ('wm','objects_v_depth','module','wm','objects','module','f','f'),
  ('wm','objects_v','module','wm','objects','module','f','f'),
  ('wm','objects','module','wm','objects','module','f','f'),
  ('base','ent_v','title','base','ent','title','f','f'),
  ('base','ent','title','base','ent','title','f','f'),
  ('wm','message_text','title','wm','message_text','title','f','f'),
  ('wm','value_text','title','wm','value_text','title','f','f'),
  ('wm','column_text','title','wm','column_text','title','f','f'),
  ('wm','table_text','title','wm','table_text','title','f','f'),
  ('base','token_v_ticket','allows','base','token','allows','f','f'),
  ('base','token_v','allows','base','token','allows','f','f'),
  ('base','token','allows','base','token','allows','f','f'),
  ('base','ent','_last_addr','base','ent','_last_addr','f','f'),
  ('wylib','data_v','component','wylib','data','component','f','f'),
  ('wylib','data','component','wylib','data','component','f','f'),
  ('wm','depends_v','path','wm','depends_v','path','f','f'),
  ('base','ent_v','frm_name','base','ent_v','frm_name','f','f'),
  ('wm','objects_v_depth','clean','wm','objects','clean','f','f'),
  ('wm','objects_v','clean','wm','objects','clean','f','f'),
  ('wm','objects','clean','wm','objects','clean','f','f'),
  ('wm','objects_v_depth','ndeps','wm','objects','ndeps','f','f'),
  ('wm','objects_v','ndeps','wm','objects','ndeps','f','f'),
  ('wm','objects','ndeps','wm','objects','ndeps','f','f'),
  ('base','ent_link_v','supr_path','base','ent_link','supr_path','f','f'),
  ('base','ent_link','supr_path','base','ent_link','supr_path','f','f'),
  ('base','ent_v','conn_pub','base','ent','conn_pub','f','f'),
  ('base','ent','conn_pub','base','ent','conn_pub','f','f'),
  ('wm','depends_v','od_nam','wm','depends_v','od_nam','f','f'),
  ('base','parm','v_date','base','parm','v_date','f','f'),
  ('wm','message_text','help','wm','message_text','help','f','f'),
  ('wm','value_text','help','wm','value_text','help','f','f'),
  ('wm','column_text','help','wm','column_text','help','f','f'),
  ('wm','table_text','help','wm','table_text','help','f','f'),
  ('base','country','iana','base','country','iana','f','f'),
  ('base','addr_v','addr_type','base','addr','addr_type','f','f'),
  ('base','addr','addr_type','base','addr','addr_type','f','f'),
  ('base','ent_v','marital','base','ent','marital','f','f'),
  ('base','ent','marital','base','ent','marital','f','f'),
  ('wm','objects_v_depth','object','wm','objects_v','object','f','f'),
  ('wm','objects_v','object','wm','objects_v','object','f','f'),
  ('wm','depends_v','object','wm','depends_v','object','f','f'),
  ('wylib','data_v','access','wylib','data','access','f','f'),
  ('wylib','data','access','wylib','data','access','f','f'),
  ('base','ent_v_pub','ent_type','base','ent','ent_type','f','f'),
  ('base','ent_v','ent_type','base','ent','ent_type','f','f'),
  ('base','ent','ent_type','base','ent','ent_type','f','f'),
  ('wm','objects_v_depth','checked','wm','objects','checked','f','f'),
  ('wm','objects_v','checked','wm','objects','checked','f','f'),
  ('wm','objects','checked','wm','objects','checked','f','f'),
  ('base','parm','v_text','base','parm','v_text','f','f'),
  ('wm','objects_v_depth','deps','wm','objects','deps','f','f'),
  ('wm','objects_v','deps','wm','objects','deps','f','f'),
  ('wm','objects','deps','wm','objects','deps','f','f'),
  ('base','ent_link_v','mem_name','base','ent_link_v','mem_name','f','f'),
  ('base','addr_v_flat','phys_addr','base','addr_v_flat','phys_addr','f','f'),
  ('base','comm_v_flat','other_comm','base','comm_v_flat','other_comm','f','f'),
  ('base','parm_audit','a_by','base','parm_audit','a_by','f','f'),
  ('base','ent_audit','a_by','base','ent_audit','a_by','f','f'),
  ('wm','column_native','pkey','wm','column_native','pkey','f','f'),
  ('base','comm_v','comm_spec','base','comm','comm_spec','f','f'),
  ('base','comm','comm_spec','base','comm','comm_spec','f','f'),
  ('wylib','data_v','crt_by','wylib','data','crt_by','f','f'),
  ('base','comm_v','crt_by','base','comm','crt_by','f','f'),
  ('base','addr_v','crt_by','base','addr','crt_by','f','f'),
  ('base','token_v','crt_by','base','token','crt_by','f','f'),
  ('wylib','data','crt_by','wylib','data','crt_by','f','f'),
  ('base','ent_v_pub','crt_by','base','ent','crt_by','f','f'),
  ('base','ent_link_v','crt_by','base','ent_link','crt_by','f','f'),
  ('base','parm_v','crt_by','base','parm','crt_by','f','f'),
  ('base','ent_v','crt_by','base','ent','crt_by','f','f'),
  ('base','token','crt_by','base','token','crt_by','f','f'),
  ('base','parm','crt_by','base','parm','crt_by','f','f'),
  ('base','ent_link','crt_by','base','ent_link','crt_by','f','f'),
  ('base','comm','crt_by','base','comm','crt_by','f','f'),
  ('base','addr','crt_by','base','addr','crt_by','f','f'),
  ('base','ent','crt_by','base','ent','crt_by','f','f'),
  ('base','priv_v','priv_list','base','priv_v','priv_list','f','f'),
  ('base','token_v','valid','base','token_v','valid','f','f'),
  ('base','ent_link_v','role','base','ent_link','role','f','f'),
  ('base','ent_link','role','base','ent_link','role','f','f'),
  ('base','token_v','expired','base','token_v','expired','f','f'),
  ('base','ent_v','age','base','ent_v','age','f','f'),
  ('base','comm_v','comm_type','base','comm','comm_type','f','f'),
  ('base','comm','comm_type','base','comm','comm_type','f','f'),
  ('base','comm_v','comm_cmt','base','comm','comm_cmt','f','f'),
  ('base','comm','comm_cmt','base','comm','comm_cmt','f','f'),
  ('base','ent_v_pub','ent_inact','base','ent','ent_inact','f','f'),
  ('base','ent_v','ent_inact','base','ent','ent_inact','f','f'),
  ('base','ent','ent_inact','base','ent','ent_inact','f','f'),
  ('base','language','fra_name','base','language','fra_name','f','f'),
  ('base','parm_v','value','base','parm_v','value','f','f'),
  ('base','language','iso_2','base','language','iso_2','f','f'),
  ('base','comm_v_flat','fax_comm','base','comm_v_flat','fax_comm','f','f'),
  ('wylib','data_v','name','wylib','data','name','f','f'),
  ('wylib','data','name','wylib','data','name','f','f'),
  ('base','addr_v','state','base','addr','state','f','f'),
  ('base','addr','state','base','addr','state','f','f'),
  ('base','addr_v','city','base','addr','city','f','f'),
  ('base','addr','city','base','addr','city','f','f'),
  ('base','ent_v_pub','ent_num','base','ent','ent_num','f','f'),
  ('base','ent_v','ent_num','base','ent','ent_num','f','f'),
  ('base','ent','ent_num','base','ent','ent_num','f','f'),
  ('wm','objects_v_depth','drp_sql','wm','objects','drp_sql','f','f'),
  ('wm','objects_v','drp_sql','wm','objects','drp_sql','f','f'),
  ('wm','objects','drp_sql','wm','objects','drp_sql','f','f'),
  ('base','priv_v','level','base','priv','level','f','f'),
  ('base','priv','level','base','priv','level','f','f'),
  ('base','ent_v','cas_name','base','ent_v','cas_name','f','f'),
  ('base','addr_v','country','base','addr','country','f','f'),
  ('base','token_v','used','base','token','used','f','f'),
  ('base','ent_v','country','base','ent','country','f','f'),
  ('base','token','used','base','token','used','f','f'),
  ('base','addr','country','base','addr','country','f','f'),
  ('base','ent','country','base','ent','country','f','f'),
  ('base','comm_v_flat','pager_comm','base','comm_v_flat','pager_comm','f','f'),
  ('wm','objects_v_depth','col_data','wm','objects','col_data','f','f'),
  ('wm','objects_v','col_data','wm','objects','col_data','f','f'),
  ('wm','objects','col_data','wm','objects','col_data','f','f'),
  ('wm','column_native','nat_col','wm','column_native','nat_col','f','f'),
  ('base','addr_v_flat','bill_city','base','addr_v_flat','bill_city','f','f'),
  ('base','comm_v_flat','email_comm','base','comm_v_flat','email_comm','f','f'),
  ('wm','table_style','inherit','wm','table_style','inherit','f','f'),
  ('base','addr_v_flat','mail_pcode','base','addr_v_flat','mail_pcode','f','f'),
  ('wm','objects_v_depth','max_rel','wm','objects','max_rel','f','f'),
  ('wm','objects_v','max_rel','wm','objects','max_rel','f','f'),
  ('wm','objects','max_rel','wm','objects','max_rel','f','f'),
  ('base','parm_v','type','base','parm','type','f','f'),
  ('base','parm','type','base','parm','type','f','f'),
  ('base','country','dial_code','base','country','dial_code','f','f'),
  ('base','ent_v','born_date','base','ent','born_date','f','f'),
  ('base','ent','born_date','base','ent','born_date','f','f'),
  ('base','parm','v_boolean','base','parm','v_boolean','f','f'),
  ('base','addr_v_flat','bill_pcode','base','addr_v_flat','bill_pcode','f','f'),
  ('base','token_v_ticket','host','base','token_v_ticket','host','f','f'),
  ('wm','objects_v_depth','grants','wm','objects','grants','f','f'),
  ('wm','objects_v','grants','wm','objects','grants','f','f'),
  ('wm','objects','grants','wm','objects','grants','f','f'),
  ('base','ent_v','ent_cmt','base','ent','ent_cmt','f','f'),
  ('base','ent','ent_cmt','base','ent','ent_cmt','f','f'),
  ('base','addr_v','pcode','base','addr','pcode','f','f'),
  ('base','addr','pcode','base','addr','pcode','f','f'),
  ('wm','objects_v_depth','mod_ver','wm','objects','mod_ver','f','f'),
  ('wm','objects_v','mod_ver','wm','objects','mod_ver','f','f'),
  ('wm','objects','mod_ver','wm','objects','mod_ver','f','f'),
  ('base','ent','_last_comm','base','ent','_last_comm','f','f'),
  ('base','country','capital','base','country','capital','f','f'),
  ('base','addr_v_flat','ship_city','base','addr_v_flat','ship_city','f','f'),
  ('base','addr_v_flat','mail_city','base','addr_v_flat','mail_city','f','f'),
  ('wylib','data_v','data','wylib','data','data','f','f'),
  ('wylib','data','data','wylib','data','data','f','f'),
  ('base','country','iso_3','base','country','iso_3','f','f'),
  ('wm','objects_v_depth','crt_sql','wm','objects','crt_sql','f','f'),
  ('wm','objects_v','crt_sql','wm','objects','crt_sql','f','f'),
  ('wm','objects','crt_sql','wm','objects','crt_sql','f','f'),
  ('wm','objects_v_depth','source','wm','objects','source','f','f'),
  ('wm','objects_v','source','wm','objects','source','f','f'),
  ('wm','objects','source','wm','objects','source','f','f'),
  ('base','comm_v','comm_prim','base','comm_v','comm_prim','f','f'),
  ('base','comm','comm_prim','base','comm','comm_prim','f','f'),
  ('wm','releases','sver_1','wm','releases','sver_1','f','f'),
  ('base','token_v','username','base','ent','username','f','f'),
  ('base','ent_v_pub','username','base','ent','username','f','f'),
  ('base','priv_v','username','base','ent','username','f','f'),
  ('base','ent_v','username','base','ent','username','f','f'),
  ('base','ent_v','mid_name','base','ent','mid_name','f','f'),
  ('base','ent','username','base','ent','username','f','f'),
  ('base','ent','mid_name','base','ent','mid_name','f','f'),
  ('base','parm_v','cmt','base','parm','cmt','f','f'),
  ('base','priv_v','cmt','base','priv','cmt','f','f'),
  ('base','ent_v','pref_name','base','ent','pref_name','f','f'),
  ('base','priv','cmt','base','priv','cmt','f','f'),
  ('base','parm','cmt','base','parm','cmt','f','f'),
  ('base','ent','pref_name','base','ent','pref_name','f','f'),
  ('base','comm_v_flat','text_comm','base','comm_v_flat','text_comm','f','f'),
  ('wm','column_native','nat_tab','wm','column_native','nat_tab','f','f'),
  ('base','token_v_ticket','port','base','token_v_ticket','port','f','f'),
  ('wylib','data_v','own_name','wylib','data_v','own_name','f','f'),
  ('wm','objects_v_depth','min_rel','wm','objects','min_rel','f','f'),
  ('wm','objects_v','min_rel','wm','objects','min_rel','f','f'),
  ('wm','objects','min_rel','wm','objects','min_rel','f','f'),
  ('wm','column_native','nat_sch','wm','column_native','nat_sch','f','f'),
  ('base','addr_v_flat','bill_addr','base','addr_v_flat','bill_addr','f','f'),
  ('base','ent_v','tax_id','base','ent','tax_id','f','f'),
  ('base','ent','tax_id','base','ent','tax_id','f','f'),
  ('base','addr_v_flat','mail_state','base','addr_v_flat','mail_state','f','f'),
  ('base','comm_v_flat','web_comm','base','comm_v_flat','web_comm','f','f'),
  ('base','addr_v_flat','ship_addr','base','addr_v_flat','ship_addr','f','f'),
  ('base','token_v_ticket','expires','base','token','expires','f','f'),
  ('base','token_v','expires','base','token','expires','f','f'),
  ('base','token','expires','base','token','expires','f','f'),
  ('base','ent_v','gender','base','ent','gender','f','f'),
  ('base','ent','gender','base','ent','gender','f','f'),
  ('base','addr_v','addr_spec','base','addr','addr_spec','f','f'),
  ('base','addr','addr_spec','base','addr','addr_spec','f','f'),
  ('base','parm_audit','a_action','base','parm_audit','a_action','f','f'),
  ('base','ent_audit','a_action','base','ent_audit','a_action','f','f'),
  ('base','language','iso_3b','base','language','iso_3b','f','f'),
  ('base','comm_v_flat','phone_comm','base','comm_v_flat','phone_comm','f','f'),
  ('base','addr_v_flat','phys_country','base','addr_v_flat','phys_country','f','f'),
  ('base','addr_v_flat','mail_country','base','addr_v_flat','mail_country','f','f'),
  ('base','comm_v','std_name','base','ent_v','std_name','f','f'),
  ('base','addr_v','std_name','base','ent_v','std_name','f','f'),
  ('base','token_v','std_name','base','ent_v','std_name','f','f'),
  ('base','ent_v_pub','std_name','base','ent_v','std_name','f','f'),
  ('base','priv_v','std_name','base','ent_v','std_name','f','f'),
  ('base','ent_v','std_name','base','ent_v','std_name','f','f'),
  ('base','parm_audit','a_date','base','parm_audit','a_date','f','f'),
  ('base','ent_audit','a_date','base','ent_audit','a_date','f','f'),
  ('wm','objects_v_depth','depth','wm','depends_v','depth','f','f'),
  ('wm','depends_v','depth','wm','depends_v','depth','f','f'),
  ('base','addr_v','addr_inact','base','addr','addr_inact','f','f'),
  ('base','addr','addr_inact','base','addr','addr_inact','f','f'),
  ('wylib','data_v','mod_by','wylib','data','mod_by','f','f'),
  ('base','comm_v','mod_by','base','comm','mod_by','f','f'),
  ('base','addr_v','mod_by','base','addr','mod_by','f','f'),
  ('base','token_v','mod_by','base','token','mod_by','f','f'),
  ('wylib','data','mod_by','wylib','data','mod_by','f','f'),
  ('base','ent_v_pub','mod_by','base','ent','mod_by','f','f'),
  ('base','ent_link_v','mod_by','base','ent_link','mod_by','f','f'),
  ('base','parm_v','mod_by','base','parm','mod_by','f','f'),
  ('base','ent_v','mod_by','base','ent','mod_by','f','f'),
  ('base','token','mod_by','base','token','mod_by','f','f'),
  ('base','parm','mod_by','base','parm','mod_by','f','f'),
  ('base','ent_link','mod_by','base','ent_link','mod_by','f','f'),
  ('base','comm','mod_by','base','comm','mod_by','f','f'),
  ('base','addr','mod_by','base','addr','mod_by','f','f'),
  ('base','ent','mod_by','base','ent','mod_by','f','f'),
  ('base','parm','v_float','base','parm','v_float','f','f'),
  ('base','addr_v','addr_cmt','base','addr','addr_cmt','f','f'),
  ('base','priv_v','priv_level','base','priv','priv_level','f','f'),
  ('base','priv','priv_level','base','priv','priv_level','f','f'),
  ('base','addr','addr_cmt','base','addr','addr_cmt','f','f'),
  ('wylib','data_v','owner','wylib','data','owner','f','f'),
  ('wylib','data','owner','wylib','data','owner','f','f'),
  ('wylib','data_v','crt_date','wylib','data','crt_date','f','f'),
  ('base','comm_v','crt_date','base','comm','crt_date','f','f'),
  ('base','addr_v','crt_date','base','addr','crt_date','f','f'),
  ('base','token_v','crt_date','base','token','crt_date','f','f'),
  ('wylib','data','crt_date','wylib','data','crt_date','f','f'),
  ('base','ent_v_pub','crt_date','base','ent','crt_date','f','f'),
  ('base','ent_link_v','crt_date','base','ent_link','crt_date','f','f'),
  ('base','parm_v','crt_date','base','parm','crt_date','f','f'),
  ('base','ent_v','crt_date','base','ent','crt_date','f','f'),
  ('base','token','crt_date','base','token','crt_date','f','f'),
  ('base','parm','crt_date','base','parm','crt_date','f','f'),
  ('base','ent_link','crt_date','base','ent_link','crt_date','f','f'),
  ('base','comm','crt_date','base','comm','crt_date','f','f'),
  ('base','addr','crt_date','base','addr','crt_date','f','f'),
  ('base','ent','crt_date','base','ent','crt_date','f','f'),
  ('wm','objects_v_depth','crt_date','wm','objects','crt_date','f','f'),
  ('wm','objects_v','crt_date','wm','objects','crt_date','f','f'),
  ('wm','objects','crt_date','wm','objects','crt_date','f','f'),
  ('wm','releases','crt_date','wm','releases','crt_date','f','f'),
  ('base','addr','addr_ent','base','addr','addr_ent','f','t'),
  ('base','addr','addr_seq','base','addr','addr_seq','f','t'),
  ('base','addr_prim','prim_ent','base','addr_prim','prim_ent','f','t'),
  ('base','addr_prim','prim_seq','base','addr_prim','prim_seq','f','t'),
  ('base','addr_prim','prim_type','base','addr_prim','prim_type','f','t'),
  ('base','addr_v','addr_seq','base','addr','addr_seq','f','t'),
  ('base','addr_v','addr_ent','base','addr','addr_ent','f','t'),
  ('base','addr_v_flat','id','base','ent','id','f','t'),
  ('base','comm','comm_seq','base','comm','comm_seq','f','t'),
  ('base','comm','comm_ent','base','comm','comm_ent','f','t'),
  ('base','comm_prim','prim_type','base','comm_prim','prim_type','f','t'),
  ('base','comm_prim','prim_seq','base','comm_prim','prim_seq','f','t'),
  ('base','comm_prim','prim_ent','base','comm_prim','prim_ent','f','t'),
  ('base','comm_v','comm_ent','base','comm','comm_ent','f','t'),
  ('base','comm_v','comm_seq','base','comm','comm_seq','f','t'),
  ('base','comm_v_flat','id','base','ent','id','f','t'),
  ('base','country','code','base','country','code','f','t'),
  ('base','ent','id','base','ent','id','f','t'),
  ('base','ent_audit','id','base','ent_audit','id','f','t'),
  ('base','ent_audit','a_seq','base','ent_audit','a_seq','f','t'),
  ('base','ent_link','mem','base','ent_link','mem','f','t'),
  ('base','ent_link','org','base','ent_link','org','f','t'),
  ('base','ent_link_v','mem','base','ent_link','mem','f','t'),
  ('base','ent_link_v','org','base','ent_link','org','f','t'),
  ('base','ent_v','id','base','ent','id','f','t'),
  ('base','ent_v_pub','id','base','ent','id','f','t'),
  ('base','language','code','base','language','code','f','t'),
  ('base','parm','parm','base','parm','parm','f','t'),
  ('base','parm','module','base','parm','module','f','t'),
  ('base','parm_audit','parm','base','parm_audit','parm','f','t'),
  ('base','parm_audit','module','base','parm_audit','module','f','t'),
  ('base','parm_audit','a_seq','base','parm_audit','a_seq','f','t'),
  ('base','parm_v','module','base','parm','module','f','t'),
  ('base','parm_v','parm','base','parm','parm','f','t'),
  ('base','priv','priv','base','priv','priv','f','t'),
  ('base','priv','grantee','base','priv','grantee','f','t'),
  ('base','priv_v','priv','base','priv','priv','f','t'),
  ('base','priv_v','grantee','base','priv','grantee','f','t'),
  ('base','token','token_ent','base','token','token_ent','f','t'),
  ('base','token','token_seq','base','token','token_seq','f','t'),
  ('base','token_v','token_seq','base','token','token_seq','f','t'),
  ('base','token_v','token_ent','base','token','token_ent','f','t'),
  ('base','token_v_ticket','token_ent','base','token','token_ent','f','t'),
  ('wm','column_native','cnt_tab','wm','column_native','cnt_tab','f','t'),
  ('wm','column_native','cnt_col','wm','column_native','cnt_col','f','t'),
  ('wm','column_native','cnt_sch','wm','column_native','cnt_sch','f','t'),
  ('wm','column_style','cs_tab','wm','column_style','cs_tab','f','t'),
  ('wm','column_style','cs_sch','wm','column_style','cs_sch','f','t'),
  ('wm','column_style','sw_name','wm','column_style','sw_name','f','t'),
  ('wm','column_style','cs_col','wm','column_style','cs_col','f','t'),
  ('wm','column_text','ct_sch','wm','column_text','ct_sch','f','t'),
  ('wm','column_text','ct_tab','wm','column_text','ct_tab','f','t'),
  ('wm','column_text','ct_col','wm','column_text','ct_col','f','t'),
  ('wm','column_text','language','wm','column_text','language','f','t'),
  ('wm','message_text','language','wm','message_text','language','f','t'),
  ('wm','message_text','mt_sch','wm','message_text','mt_sch','f','t'),
  ('wm','message_text','mt_tab','wm','message_text','mt_tab','f','t'),
  ('wm','message_text','code','wm','message_text','code','f','t'),
  ('wm','objects','obj_typ','wm','objects','obj_typ','f','t'),
  ('wm','objects','obj_nam','wm','objects','obj_nam','f','t'),
  ('wm','objects','obj_ver','wm','objects','obj_ver','f','t'),
  ('wm','objects_v','obj_nam','wm','objects','obj_nam','f','t'),
  ('wm','objects_v','obj_typ','wm','objects','obj_typ','f','t'),
  ('wm','objects_v','obj_ver','wm','objects','obj_ver','f','t'),
  ('wm','objects_v','release','wm','releases','release','f','t'),
  ('wm','objects_v_depth','obj_typ','wm','objects','obj_typ','f','t'),
  ('wm','objects_v_depth','release','wm','releases','release','f','t'),
  ('wm','objects_v_depth','obj_ver','wm','objects','obj_ver','f','t'),
  ('wm','objects_v_depth','obj_nam','wm','objects','obj_nam','f','t'),
  ('wm','releases','release','wm','releases','release','f','t'),
  ('wm','table_style','ts_tab','wm','table_style','ts_tab','f','t'),
  ('wm','table_style','sw_name','wm','table_style','sw_name','f','t'),
  ('wm','table_style','ts_sch','wm','table_style','ts_sch','f','t'),
  ('wm','table_text','language','wm','table_text','language','f','t'),
  ('wm','table_text','tt_sch','wm','table_text','tt_sch','f','t'),
  ('wm','table_text','tt_tab','wm','table_text','tt_tab','f','t'),
  ('wm','value_text','vt_tab','wm','value_text','vt_tab','f','t'),
  ('wm','value_text','vt_sch','wm','value_text','vt_sch','f','t'),
  ('wm','value_text','value','wm','value_text','value','f','t'),
  ('wm','value_text','language','wm','value_text','language','f','t'),
  ('wm','value_text','vt_col','wm','value_text','vt_col','f','t'),
  ('wylib','data','ruid','wylib','data','ruid','f','t'),
  ('wylib','data_v','ruid','wylib','data','ruid','f','t'),
  ('wm','role_members','level','wm','role_members','level','f','f'),
  ('wm','role_members','member','wm','role_members','member','f','t'),
  ('wm','role_members','priv','wm','role_members','priv','f','f'),
  ('wm','role_members','role','wm','role_members','role','f','t'),
  ('wm','view_column_usage','column_name','information_schema','view_column_usage','column_name','f','f'),
  ('wm','view_column_usage','table_catalog','information_schema','view_column_usage','table_catalog','f','f'),
  ('wm','view_column_usage','table_name','information_schema','view_column_usage','table_name','f','f'),
  ('wm','view_column_usage','table_schema','information_schema','view_column_usage','table_schema','f','f'),
  ('wm','view_column_usage','view_catalog','information_schema','view_column_usage','view_catalog','f','f'),
  ('wm','view_column_usage','view_name','information_schema','view_column_usage','view_name','f','t'),
  ('wm','view_column_usage','view_schema','information_schema','view_column_usage','view_schema','f','t'),
  ('wm','fkey_data','conname','wm','fkey_data','conname','f','t'),
  ('wm','fkey_data','key','wm','fkey_data','key','f','f'),
  ('wm','fkey_data','keys','wm','fkey_data','keys','f','f'),
  ('wm','fkey_data','kyf_col','wm','fkey_data','kyf_col','f','f'),
  ('wm','fkey_data','kyf_field','wm','fkey_data','kyf_field','f','f'),
  ('wm','fkey_data','kyf_sch','wm','fkey_data','kyf_sch','f','f'),
  ('wm','fkey_data','kyf_tab','wm','fkey_data','kyf_tab','f','f'),
  ('wm','fkey_data','kyt_col','wm','fkey_data','kyt_col','f','f'),
  ('wm','fkey_data','kyt_field','wm','fkey_data','kyt_field','f','f'),
  ('wm','fkey_data','kyt_sch','wm','fkey_data','kyt_sch','f','f'),
  ('wm','fkey_data','kyt_tab','wm','fkey_data','kyt_tab','f','f'),
  ('wm','fkey_pub','conname','wm','fkey_data','conname','f','t'),
  ('wm','fkey_pub','fn_col','wm','fkey_pub','fn_col','f','f'),
  ('wm','fkey_pub','fn_obj','wm','fkey_pub','fn_obj','f','f'),
  ('wm','fkey_pub','fn_sch','wm','fkey_pub','fn_sch','f','f'),
  ('wm','fkey_pub','fn_tab','wm','fkey_pub','fn_tab','f','f'),
  ('wm','fkey_pub','ft_col','wm','fkey_pub','ft_col','f','f'),
  ('wm','fkey_pub','ft_obj','wm','fkey_pub','ft_obj','f','f'),
  ('wm','fkey_pub','ft_sch','wm','fkey_pub','ft_sch','f','f'),
  ('wm','fkey_pub','ft_tab','wm','fkey_pub','ft_tab','f','f'),
  ('wm','fkey_pub','key','wm','fkey_data','key','f','f'),
  ('wm','fkey_pub','keys','wm','fkey_data','keys','f','f'),
  ('wm','fkey_pub','tn_col','wm','fkey_pub','tn_col','f','f'),
  ('wm','fkey_pub','tn_obj','wm','fkey_pub','tn_obj','f','f'),
  ('wm','fkey_pub','tn_sch','wm','fkey_pub','tn_sch','f','f'),
  ('wm','fkey_pub','tn_tab','wm','fkey_pub','tn_tab','f','f'),
  ('wm','fkey_pub','tt_col','wm','fkey_pub','tt_col','f','f'),
  ('wm','fkey_pub','tt_obj','wm','fkey_pub','tt_obj','f','f'),
  ('wm','fkey_pub','tt_sch','wm','fkey_pub','tt_sch','f','f'),
  ('wm','fkey_pub','tt_tab','wm','fkey_pub','tt_tab','f','f'),
  ('wm','fkey_pub','unikey','wm','fkey_pub','unikey','f','f'),
  ('wm','column_data','cdt_col','wm','column_data','cdt_col','f','t'),
  ('wm','column_data','cdt_sch','wm','column_data','cdt_sch','f','t'),
  ('wm','column_data','cdt_tab','wm','column_data','cdt_tab','f','t'),
  ('wm','column_data','def','wm','column_data','def','f','f'),
  ('wm','column_data','field','wm','column_data','field','f','f'),
  ('wm','column_data','is_pkey','wm','column_data','is_pkey','f','f'),
  ('wm','column_data','length','wm','column_data','length','f','f'),
  ('wm','column_data','nat_col','wm','column_native','nat_col','f','f'),
  ('wm','column_data','nat_sch','wm','column_native','nat_sch','f','f'),
  ('wm','column_data','nat_tab','wm','column_native','nat_tab','f','f'),
  ('wm','column_data','nonull','wm','column_data','nonull','f','f'),
  ('wm','column_data','pkey','wm','column_native','pkey','f','f'),
  ('wm','column_data','tab_kind','wm','column_data','tab_kind','f','f'),
  ('wm','column_data','type','wm','column_data','type','f','f'),
  ('wm','column_ambig','col','wm','column_ambig','col','f','t'),
  ('wm','column_ambig','count','wm','column_ambig','count','f','f'),
  ('wm','column_ambig','natives','wm','column_ambig','natives','f','f'),
  ('wm','column_ambig','sch','wm','column_ambig','sch','f','t'),
  ('wm','column_ambig','spec','wm','column_ambig','spec','f','f'),
  ('wm','column_ambig','tab','wm','column_ambig','tab','f','t'),
  ('wm','fkeys_data','conname','wm','fkeys_data','conname','f','t'),
  ('wm','fkeys_data','ksf_cols','wm','fkeys_data','ksf_cols','f','f'),
  ('wm','fkeys_data','ksf_sch','wm','fkeys_data','ksf_sch','f','f'),
  ('wm','fkeys_data','ksf_tab','wm','fkeys_data','ksf_tab','f','f'),
  ('wm','fkeys_data','kst_cols','wm','fkeys_data','kst_cols','f','f'),
  ('wm','fkeys_data','kst_sch','wm','fkeys_data','kst_sch','f','f'),
  ('wm','fkeys_data','kst_tab','wm','fkeys_data','kst_tab','f','f'),
  ('wm','column_istyle','cs_col','wm','column_style','cs_col','f','t'),
  ('wm','column_istyle','cs_obj','wm','column_istyle','cs_obj','f','f'),
  ('wm','column_istyle','cs_sch','wm','column_style','cs_sch','f','t'),
  ('wm','column_istyle','cs_tab','wm','column_style','cs_tab','f','t'),
  ('wm','column_istyle','cs_value','wm','column_istyle','cs_value','f','f'),
  ('wm','column_istyle','nat_col','wm','column_native','nat_col','f','f'),
  ('wm','column_istyle','nat_sch','wm','column_native','nat_sch','f','f'),
  ('wm','column_istyle','nat_tab','wm','column_native','nat_tab','f','f'),
  ('wm','column_istyle','nat_value','wm','column_istyle','nat_value','f','f'),
  ('wm','column_istyle','sw_name','wm','column_style','sw_name','f','t'),
  ('wm','column_istyle','sw_value','wm','column_style','sw_value','f','f'),
  ('wm','fkeys_pub','conname','wm','fkeys_data','conname','f','t'),
  ('wm','fkeys_pub','fn_obj','wm','fkeys_pub','fn_obj','f','f'),
  ('wm','fkeys_pub','fn_sch','wm','fkeys_pub','fn_sch','f','f'),
  ('wm','fkeys_pub','fn_tab','wm','fkeys_pub','fn_tab','f','f'),
  ('wm','fkeys_pub','ft_cols','wm','fkeys_pub','ft_cols','f','f'),
  ('wm','fkeys_pub','ft_obj','wm','fkeys_pub','ft_obj','f','f'),
  ('wm','fkeys_pub','ft_sch','wm','fkeys_pub','ft_sch','f','f'),
  ('wm','fkeys_pub','ft_tab','wm','fkeys_pub','ft_tab','f','f'),
  ('wm','fkeys_pub','tn_obj','wm','fkeys_pub','tn_obj','f','f'),
  ('wm','fkeys_pub','tn_sch','wm','fkeys_pub','tn_sch','f','f'),
  ('wm','fkeys_pub','tn_tab','wm','fkeys_pub','tn_tab','f','f'),
  ('wm','fkeys_pub','tt_cols','wm','fkeys_pub','tt_cols','f','f'),
  ('wm','fkeys_pub','tt_obj','wm','fkeys_pub','tt_obj','f','f'),
  ('wm','fkeys_pub','tt_sch','wm','fkeys_pub','tt_sch','f','f'),
  ('wm','fkeys_pub','tt_tab','wm','fkeys_pub','tt_tab','f','f'),
  ('wm','table_data','cols','wm','table_data','cols','f','f'),
  ('wm','table_data','has_pkey','wm','table_data','has_pkey','f','f'),
  ('wm','table_data','obj','wm','table_data','obj','f','f'),
  ('wm','table_data','pkey','wm','column_native','pkey','f','f'),
  ('wm','table_data','system','wm','table_data','system','f','f'),
  ('wm','table_data','tab_kind','wm','table_data','tab_kind','f','f'),
  ('wm','table_data','td_sch','wm','table_data','td_sch','f','t'),
  ('wm','table_data','td_tab','wm','table_data','td_tab','f','t'),
  ('wm','column_lang','col','wm','column_lang','col','f','t'),
  ('wm','column_lang','help','wm','column_text','help','t','f'),
  ('wm','column_lang','language','wm','column_text','language','t','f'),
  ('wm','column_lang','nat','wm','column_lang','nat','f','f'),
  ('wm','column_lang','nat_col','wm','column_native','nat_col','f','f'),
  ('wm','column_lang','nat_sch','wm','column_native','nat_sch','f','f'),
  ('wm','column_lang','nat_tab','wm','column_native','nat_tab','f','f'),
  ('wm','column_lang','obj','wm','column_lang','obj','f','f'),
  ('wm','column_lang','sch','wm','column_lang','sch','f','t'),
  ('wm','column_lang','system','wm','column_lang','system','f','f'),
  ('wm','column_lang','tab','wm','column_lang','tab','f','t'),
  ('wm','column_lang','title','wm','column_text','title','t','f'),
  ('wm','column_lang','values','wm','column_lang','values','f','f'),
  ('wm','column_pub','col','wm','column_pub','col','f','t'),
  ('wm','column_pub','def','wm','column_data','def','f','f'),
  ('wm','column_pub','field','wm','column_data','field','f','f'),
  ('wm','column_pub','help','wm','column_text','help','f','f'),
  ('wm','column_pub','is_pkey','wm','column_data','is_pkey','f','f'),
  ('wm','column_pub','language','wm','column_text','language','f','f'),
  ('wm','column_pub','length','wm','column_data','length','f','f'),
  ('wm','column_pub','nat','wm','column_pub','nat','f','f'),
  ('wm','column_pub','nat_col','wm','column_native','nat_col','f','f'),
  ('wm','column_pub','nat_sch','wm','column_native','nat_sch','f','f'),
  ('wm','column_pub','nat_tab','wm','column_native','nat_tab','f','f'),
  ('wm','column_pub','nonull','wm','column_data','nonull','f','f'),
  ('wm','column_pub','obj','wm','column_pub','obj','f','f'),
  ('wm','column_pub','pkey','wm','column_native','pkey','f','f'),
  ('wm','column_pub','sch','wm','column_pub','sch','f','t'),
  ('wm','column_pub','tab','wm','column_pub','tab','f','t'),
  ('wm','column_pub','title','wm','column_text','title','f','f'),
  ('wm','column_pub','type','wm','column_data','type','f','f'),
  ('wm','column_meta','col','wm','column_meta','col','f','t'),
  ('wm','column_meta','def','wm','column_data','def','f','f'),
  ('wm','column_meta','field','wm','column_data','field','f','f'),
  ('wm','column_meta','is_pkey','wm','column_data','is_pkey','f','f'),
  ('wm','column_meta','length','wm','column_data','length','f','f'),
  ('wm','column_meta','nat','wm','column_meta','nat','f','f'),
  ('wm','column_meta','nat_col','wm','column_native','nat_col','f','f'),
  ('wm','column_meta','nat_sch','wm','column_native','nat_sch','f','f'),
  ('wm','column_meta','nat_tab','wm','column_native','nat_tab','f','f'),
  ('wm','column_meta','nonull','wm','column_data','nonull','f','f'),
  ('wm','column_meta','obj','wm','column_meta','obj','f','f'),
  ('wm','column_meta','pkey','wm','column_native','pkey','f','f'),
  ('wm','column_meta','sch','wm','column_meta','sch','f','t'),
  ('wm','column_meta','styles','wm','column_meta','styles','f','f'),
  ('wm','column_meta','tab','wm','column_meta','tab','f','t'),
  ('wm','column_meta','type','wm','column_data','type','f','f'),
  ('wm','column_meta','values','wm','column_meta','values','f','f'),
  ('wm','column_def','col','wm','column_pub','col','f','t'),
  ('wm','column_def','obj','wm','column_pub','obj','f','f'),
  ('wm','column_def','val','wm','column_def','val','f','f'),
  ('wm','table_pub','cols','wm','table_data','cols','f','f'),
  ('wm','table_pub','has_pkey','wm','table_data','has_pkey','f','f'),
  ('wm','table_pub','help','wm','table_text','help','f','f'),
  ('wm','table_pub','language','wm','table_text','language','f','t'),
  ('wm','table_pub','obj','wm','table_pub','obj','f','f'),
  ('wm','table_pub','pkey','wm','column_native','pkey','f','f'),
  ('wm','table_pub','sch','wm','table_pub','sch','f','t'),
  ('wm','table_pub','system','wm','table_data','system','f','f'),
  ('wm','table_pub','tab','wm','table_pub','tab','f','t'),
  ('wm','table_pub','tab_kind','wm','table_data','tab_kind','f','f'),
  ('wm','table_pub','title','wm','table_text','title','f','f'),
  ('wm','table_meta','cols','wm','table_data','cols','f','f'),
  ('wm','table_meta','columns','wm','table_meta','columns','f','f'),
  ('wm','table_meta','fkeys','wm','table_meta','fkeys','f','f'),
  ('wm','table_meta','has_pkey','wm','table_data','has_pkey','f','f'),
  ('wm','table_meta','obj','wm','table_meta','obj','f','f'),
  ('wm','table_meta','pkey','wm','table_data','pkey','t','f'),
  ('wm','table_meta','sch','wm','column_meta','sch','f','t'),
  ('wm','table_meta','styles','wm','column_meta','styles','f','f'),
  ('wm','table_meta','system','wm','table_data','system','f','f'),
  ('wm','table_meta','tab','wm','column_meta','tab','f','t'),
  ('wm','table_meta','tab_kind','wm','table_data','tab_kind','f','f'),
  ('wm','table_lang','columns','wm','table_lang','columns','f','f'),
  ('wm','table_lang','help','wm','table_text','help','t','f'),
  ('wm','table_lang','language','wm','table_text','language','t','t'),
  ('wm','table_lang','messages','wm','table_lang','messages','f','f'),
  ('wm','table_lang','obj','wm','table_lang','obj','f','f'),
  ('wm','table_lang','sch','wm','column_lang','sch','f','t'),
  ('wm','table_lang','tab','wm','column_lang','tab','f','t'),
  ('wm','table_lang','title','wm','table_text','title','t','f');

--Initialization SQL:
insert into base.country (code,com_name,capital,cur_code,cur_name,dial_code,iso_3,iana) values
 ('AF','Afghanistan','Kabul','AFN','Afghani','+93','AFG','.af'),
 ('AL','Albania','Tirana','ALL','Lek','+355','ALB','.al'),
 ('DZ','Algeria','Algiers','DZD','Dinar','+213','DZA','.dz'),
 ('AD','Andorra','Andorra la Vella','EUR','Euro','+376','AND','.ad'),
 ('AO','Angola','Luanda','AOA','Kwanza','+244','AGO','.ao'),
 ('AG','Antigua and Barbuda','Saint John''s','XCD','Dollar','+1-268','ATG','.ag'),
 ('AR','Argentina','Buenos Aires','ARS','Peso','+54','ARG','.ar'),
 ('AM','Armenia','Yerevan','AMD','Dram','+374','ARM','.am'),
 ('AU','Australia','Canberra','AUD','Dollar','+61','AUS','.au'),
 ('AT','Austria','Vienna','EUR','Euro','+43','AUT','.at'),
 ('AZ','Azerbaijan','Baku','AZN','Manat','+994','AZE','.az'),
 ('BS','Bahamas, The','Nassau','BSD','Dollar','+1-242','BHS','.bs'),
 ('BH','Bahrain','Manama','BHD','Dinar','+973','BHR','.bh'),
 ('BD','Bangladesh','Dhaka','BDT','Taka','+880','BGD','.bd'),
 ('BB','Barbados','Bridgetown','BBD','Dollar','+1-246','BRB','.bb'),
 ('BY','Belarus','Minsk','BYR','Ruble','+375','BLR','.by'),
 ('BE','Belgium','Brussels','EUR','Euro','+32','BEL','.be'),
 ('BZ','Belize','Belmopan','BZD','Dollar','+501','BLZ','.bz'),
 ('BJ','Benin','Porto-Novo','XOF','Franc','+229','BEN','.bj'),
 ('BT','Bhutan','Thimphu','BTN','Ngultrum','+975','BTN','.bt'),
 ('BO','Bolivia','La Paz (administrative/legislative) and Sucre (judical)','BOB','Boliviano','+591','BOL','.bo'),
 ('BA','Bosnia and Herzegovina','Sarajevo','BAM','Marka','+387','BIH','.ba'),
 ('BW','Botswana','Gaborone','BWP','Pula','+267','BWA','.bw'),
 ('BR','Brazil','Brasilia','BRL','Real','+55','BRA','.br'),
 ('BN','Brunei','Bandar Seri Begawan','BND','Dollar','+673','BRN','.bn'),
 ('BG','Bulgaria','Sofia','BGN','Lev','+359','BGR','.bg'),
 ('BF','Burkina Faso','Ouagadougou','XOF','Franc','+226','BFA','.bf'),
 ('BI','Burundi','Bujumbura','BIF','Franc','+257','BDI','.bi'),
 ('KH','Cambodia','Phnom Penh','KHR','Riels','+855','KHM','.kh'),
 ('CM','Cameroon','Yaounde','XAF','Franc','+237','CMR','.cm'),
 ('CA','Canada','Ottawa','CAD','Dollar','+1','CAN','.ca'),
 ('CV','Cape Verde','Praia','CVE','Escudo','+238','CPV','.cv'),
 ('CF','Central African Republic','Bangui','XAF','Franc','+236','CAF','.cf'),
 ('TD','Chad','N''Djamena','XAF','Franc','+235','TCD','.td'),
 ('CL','Chile','Santiago (administrative/judical) and Valparaiso (legislative)','CLP','Peso','+56','CHL','.cl'),
 ('CN','China, People''s Republic of','Beijing','CNY','Yuan Renminbi','+86','CHN','.cn'),
 ('CO','Colombia','Bogota','COP','Peso','+57','COL','.co'),
 ('KM','Comoros','Moroni','KMF','Franc','+269','COM','.km'),
 ('CD','Congo, Democratic Republic of the (Congo � Kinshasa)','Kinshasa','CDF','Franc','+243','COD','.cd'),
 ('CG','Congo, Republic of the (Congo � Brazzaville)','Brazzaville','XAF','Franc','+242','COG','.cg'),
 ('CR','Costa Rica','San Jose','CRC','Colon','+506','CRI','.cr'),
 ('CI','Cote d''Ivoire (Ivory Coast)','Yamoussoukro','XOF','Franc','+225','CIV','.ci'),
 ('HR','Croatia','Zagreb','HRK','Kuna','+385','HRV','.hr'),
 ('CU','Cuba','Havana','CUP','Peso','+53','CUB','.cu'),
 ('CY','Cyprus','Nicosia','CYP','Pound','+357','CYP','.cy'),
 ('CZ','Czech Republic','Prague','CZK','Koruna','+420','CZE','.cz'),
 ('DK','Denmark','Copenhagen','DKK','Krone','+45','DNK','.dk'),
 ('DJ','Djibouti','Djibouti','DJF','Franc','+253','DJI','.dj'),
 ('DM','Dominica','Roseau','XCD','Dollar','+1-767','DMA','.dm'),
 ('DO','Dominican Republic','Santo Domingo','DOP','Peso','+1-809','DOM','.do'),
 ('EC','Ecuador','Quito','USD','Dollar','+593','ECU','.ec'),
 ('EG','Egypt','Cairo','EGP','Pound','+20','EGY','.eg'),
 ('SV','El Salvador','San Salvador','USD','Dollar','+503','SLV','.sv'),
 ('GQ','Equatorial Guinea','Malabo','XAF','Franc','+240','GNQ','.gq'),
 ('ER','Eritrea','Asmara','ERN','Nakfa','+291','ERI','.er'),
 ('EE','Estonia','Tallinn','EEK','Kroon','+372','EST','.ee'),
 ('ET','Ethiopia','Addis Ababa','ETB','Birr','+251','ETH','.et'),
 ('FJ','Fiji','Suva','FJD','Dollar','+679','FJI','.fj'),
 ('FI','Finland','Helsinki','EUR','Euro','+358','FIN','.fi'),
 ('FR','France','Paris','EUR','Euro','+33','FRA','.fr'),
 ('GA','Gabon','Libreville','XAF','Franc','+241','GAB','.ga'),
 ('GM','Gambia, The','Banjul','GMD','Dalasi','+220','GMB','.gm'),
 ('GE','Georgia','Tbilisi','GEL','Lari','+995','GEO','.ge'),
 ('DE','Germany','Berlin','EUR','Euro','+49','DEU','.de'),
 ('GH','Ghana','Accra','GHS','Cedi','+233','GHA','.gh'),
 ('GR','Greece','Athens','EUR','Euro','+30','GRC','.gr'),
 ('GD','Grenada','Saint George''s','XCD','Dollar','+1-473','GRD','.gd'),
 ('GT','Guatemala','Guatemala','GTQ','Quetzal','+502','GTM','.gt'),
 ('GN','Guinea','Conakry','GNF','Franc','+224','GIN','.gn'),
 ('GW','Guinea-Bissau','Bissau','XOF','Franc','+245','GNB','.gw'),
 ('GY','Guyana','Georgetown','GYD','Dollar','+592','GUY','.gy'),
 ('HT','Haiti','Port-au-Prince','HTG','Gourde','+509','HTI','.ht'),
 ('HN','Honduras','Tegucigalpa','HNL','Lempira','+504','HND','.hn'),
 ('HU','Hungary','Budapest','HUF','Forint','+36','HUN','.hu'),
 ('IS','Iceland','Reykjavik','ISK','Krona','+354','ISL','.is'),
 ('IN','India','New Delhi','INR','Rupee','+91','IND','.in'),
 ('ID','Indonesia','Jakarta','IDR','Rupiah','+62','IDN','.id'),
 ('IR','Iran','Tehran','IRR','Rial','+98','IRN','.ir'),
 ('IQ','Iraq','Baghdad','IQD','Dinar','+964','IRQ','.iq'),
 ('IE','Ireland','Dublin','EUR','Euro','+353','IRL','.ie'),
 ('IL','Israel','Jerusalem','ILS','Shekel','+972','ISR','.il'),
 ('IT','Italy','Rome','EUR','Euro','+39','ITA','.it'),
 ('JM','Jamaica','Kingston','JMD','Dollar','+1-876','JAM','.jm'),
 ('JP','Japan','Tokyo','JPY','Yen','+81','JPN','.jp'),
 ('JO','Jordan','Amman','JOD','Dinar','+962','JOR','.jo'),
 ('KZ','Kazakhstan','Astana','KZT','Tenge','+7','KAZ','.kz'),
 ('KE','Kenya','Nairobi','KES','Shilling','+254','KEN','.ke'),
 ('KI','Kiribati','Tarawa','AUD','Dollar','+686','KIR','.ki'),
 ('KP','Korea, Democratic People''s Republic of (North Korea)','Pyongyang','KPW','Won','+850','PRK','.kp'),
 ('KR','Korea, Republic of  (South Korea)','Seoul','KRW','Won','+82','KOR','.kr'),
 ('KW','Kuwait','Kuwait','KWD','Dinar','+965','KWT','.kw'),
 ('KG','Kyrgyzstan','Bishkek','KGS','Som','+996','KGZ','.kg'),
 ('LA','Laos','Vientiane','LAK','Kip','+856','LAO','.la'),
 ('LV','Latvia','Riga','LVL','Lat','+371','LVA','.lv'),
 ('LB','Lebanon','Beirut','LBP','Pound','+961','LBN','.lb'),
 ('LS','Lesotho','Maseru','LSL','Loti','+266','LSO','.ls'),
 ('LR','Liberia','Monrovia','LRD','Dollar','+231','LBR','.lr'),
 ('LY','Libya','Tripoli','LYD','Dinar','+218','LBY','.ly'),
 ('LI','Liechtenstein','Vaduz','CHF','Franc','+423','LIE','.li'),
 ('LT','Lithuania','Vilnius','LTL','Litas','+370','LTU','.lt'),
 ('LU','Luxembourg','Luxembourg','EUR','Euro','+352','LUX','.lu'),
 ('MK','Macedonia','Skopje','MKD','Denar','+389','MKD','.mk'),
 ('MG','Madagascar','Antananarivo','MGA','Ariary','+261','MDG','.mg'),
 ('MW','Malawi','Lilongwe','MWK','Kwacha','+265','MWI','.mw'),
 ('MY','Malaysia','Kuala Lumpur (legislative/judical) and Putrajaya (administrative)','MYR','Ringgit','+60','MYS','.my'),
 ('MV','Maldives','Male','MVR','Rufiyaa','+960','MDV','.mv'),
 ('ML','Mali','Bamako','XOF','Franc','+223','MLI','.ml'),
 ('MT','Malta','Valletta','MTL','Lira','+356','MLT','.mt'),
 ('MH','Marshall Islands','Majuro','USD','Dollar','+692','MHL','.mh'),
 ('MR','Mauritania','Nouakchott','MRO','Ouguiya','+222','MRT','.mr'),
 ('MU','Mauritius','Port Louis','MUR','Rupee','+230','MUS','.mu'),
 ('MX','Mexico','Mexico','MXN','Peso','+52','MEX','.mx'),
 ('FM','Micronesia','Palikir','USD','Dollar','+691','FSM','.fm'),
 ('MD','Moldova','Chisinau','MDL','Leu','+373','MDA','.md'),
 ('MC','Monaco','Monaco','EUR','Euro','+377','MCO','.mc'),
 ('MN','Mongolia','Ulaanbaatar','MNT','Tugrik','+976','MNG','.mn'),
 ('MA','Morocco','Rabat','MAD','Dirham','+212','MAR','.ma'),
 ('MZ','Mozambique','Maputo','MZM','Meticail','+258','MOZ','.mz'),
 ('MM','Myanmar (Burma)','Naypyidaw','MMK','Kyat','+95','MMR','.mm'),
 ('NA','Namibia','Windhoek','NAD','Dollar','+264','NAM','.na'),
 ('NR','Nauru','Yaren','AUD','Dollar','+674','NRU','.nr'),
 ('NP','Nepal','Kathmandu','NPR','Rupee','+977','NPL','.np'),
 ('NL','Netherlands','Amsterdam (administrative) and The Hague (legislative/judical)','EUR','Euro','+31','NLD','.nl'),
 ('NZ','New Zealand','Wellington','NZD','Dollar','+64','NZL','.nz'),
 ('NI','Nicaragua','Managua','NIO','Cordoba','+505','NIC','.ni'),
 ('NE','Niger','Niamey','XOF','Franc','+227','NER','.ne'),
 ('NG','Nigeria','Abuja','NGN','Naira','+234','NGA','.ng'),
 ('NO','Norway','Oslo','NOK','Krone','+47','NOR','.no'),
 ('OM','Oman','Muscat','OMR','Rial','+968','OMN','.om'),
 ('PK','Pakistan','Islamabad','PKR','Rupee','+92','PAK','.pk'),
 ('PW','Palau','Melekeok','USD','Dollar','+680','PLW','.pw'),
 ('PA','Panama','Panama','PAB','Balboa','+507','PAN','.pa'),
 ('PG','Papua New Guinea','Port Moresby','PGK','Kina','+675','PNG','.pg'),
 ('PY','Paraguay','Asuncion','PYG','Guarani','+595','PRY','.py'),
 ('PE','Peru','Lima','PEN','Sol','+51','PER','.pe'),
 ('PH','Philippines','Manila','PHP','Peso','+63','PHL','.ph'),
 ('PL','Poland','Warsaw','PLN','Zloty','+48','POL','.pl'),
 ('PT','Portugal','Lisbon','EUR','Euro','+351','PRT','.pt'),
 ('QA','Qatar','Doha','QAR','Rial','+974','QAT','.qa'),
 ('RO','Romania','Bucharest','RON','Leu','+40','ROU','.ro'),
 ('RW','Rwanda','Kigali','RWF','Franc','+250','RWA','.rw'),
 ('KN','Saint Kitts and Nevis','Basseterre','XCD','Dollar','+1-869','KNA','.kn'),
 ('LC','Saint Lucia','Castries','XCD','Dollar','+1-758','LCA','.lc'),
 ('VC','Saint Vincent and the Grenadines','Kingstown','XCD','Dollar','+1-784','VCT','.vc'),
 ('WS','Samoa','Apia','WST','Tala','+685','WSM','.ws'),
 ('SM','San Marino','San Marino','EUR','Euro','+378','SMR','.sm'),
 ('ST','Sao Tome and Principe','Sao Tome','STD','Dobra','+239','STP','.st'),
 ('SA','Saudi Arabia','Riyadh','SAR','Rial','+966','SAU','.sa'),
 ('SN','Senegal','Dakar','XOF','Franc','+221','SEN','.sn'),
 ('SC','Seychelles','Victoria','SCR','Rupee','+248','SYC','.sc'),
 ('SL','Sierra Leone','Freetown','SLL','Leone','+232','SLE','.sl'),
 ('SG','Singapore','Singapore','SGD','Dollar','+65','SGP','.sg'),
 ('SK','Slovakia','Bratislava','SKK','Koruna','+421','SVK','.sk'),
 ('SI','Slovenia','Ljubljana','EUR','Euro','+386','SVN','.si'),
 ('SB','Solomon Islands','Honiara','SBD','Dollar','+677','SLB','.sb'),
 ('SO','Somalia','Mogadishu','SOS','Shilling','+252','SOM','.so'),
 ('ZA','South Africa','Pretoria (administrative), Cape Town (legislative), and Bloemfontein (judical)','ZAR','Rand','+27','ZAF','.za'),
 ('ES','Spain','Madrid','EUR','Euro','+34','ESP','.es'),
 ('LK','Sri Lanka','Colombo (administrative/judical) and Sri Jayewardenepura Kotte (legislative)','LKR','Rupee','+94','LKA','.lk'),
 ('SD','Sudan','Khartoum','SDG','Pound','+249','SDN','.sd'),
 ('SR','Suriname','Paramaribo','SRD','Dollar','+597','SUR','.sr'),
 ('SZ','Swaziland','Mbabane (administrative) and Lobamba (legislative)','SZL','Lilangeni','+268','SWZ','.sz'),
 ('SE','Sweden','Stockholm','SEK','Kronoa','+46','SWE','.se'),
 ('CH','Switzerland','Bern','CHF','Franc','+41','CHE','.ch'),
 ('SY','Syria','Damascus','SYP','Pound','+963','SYR','.sy'),
 ('TJ','Tajikistan','Dushanbe','TJS','Somoni','+992','TJK','.tj'),
 ('TZ','Tanzania','Dar es Salaam (administrative/judical) and Dodoma (legislative)','TZS','Shilling','+255','TZA','.tz'),
 ('TH','Thailand','Bangkok','THB','Baht','+66','THA','.th'),
 ('TG','Togo','Lome','XOF','Franc','+228','TGO','.tg'),
 ('TO','Tonga','Nuku''alofa','TOP','Pa''anga','+676','TON','.to'),
 ('TT','Trinidad and Tobago','Port-of-Spain','TTD','Dollar','+1-868','TTO','.tt'),
 ('TN','Tunisia','Tunis','TND','Dinar','+216','TUN','.tn'),
 ('TR','Turkey','Ankara','TRY','Lira','+90','TUR','.tr'),
 ('TM','Turkmenistan','Ashgabat','TMM','Manat','+993','TKM','.tm'),
 ('TV','Tuvalu','Funafuti','AUD','Dollar','+688','TUV','.tv'),
 ('UG','Uganda','Kampala','UGX','Shilling','+256','UGA','.ug'),
 ('UA','Ukraine','Kiev','UAH','Hryvnia','+380','UKR','.ua'),
 ('AE','United Arab Emirates','Abu Dhabi','AED','Dirham','+971','ARE','.ae'),
 ('GB','United Kingdom','London','GBP','Pound','+44','GBR','.uk'),
 ('US','United States','Washington','USD','Dollar','+1','USA','.us'),
 ('UY','Uruguay','Montevideo','UYU','Peso','+598','URY','.uy'),
 ('UZ','Uzbekistan','Tashkent','UZS','Som','+998','UZB','.uz'),
 ('VU','Vanuatu','Port-Vila','VUV','Vatu','+678','VUT','.vu'),
 ('VA','Vatican City','Vatican City','EUR','Euro','+379','VAT','.va'),
 ('VE','Venezuela','Caracas','VEB','Bolivar','+58','VEN','.ve'),
 ('VN','Vietnam','Hanoi','VND','Dong','+84','VNM','.vn'),
 ('YE','Yemen','Sanaa','YER','Rial','+967','YEM','.ye'),
 ('ZM','Zambia','Lusaka','ZMK','Kwacha','+260','ZMB','.zm'),
 ('ZW','Zimbabwe','Harare','ZWD','Dollar','+263','ZWE','.zw'),
 ('TW','China, Republic of (Taiwan)','Taipei','TWD','Dollar','+886','TWN','.tw'),
 ('CX','Christmas Island','The Settlement (Flying Fish Cove)','AUD','Dollar','+61','CXR','.cx'),
 ('CC','Cocos (Keeling) Islands','West Island','AUD','Dollar','+61','CCK','.cc'),
 ('HM','Heard Island and McDonald Islands','','','','','HMD','.hm'),
 ('NF','Norfolk Island','Kingston','AUD','Dollar','+672','NFK','.nf'),
 ('NC','New Caledonia','Noumea','XPF','Franc','+687','NCL','.nc'),
 ('PF','French Polynesia','Papeete','XPF','Franc','+689','PYF','.pf'),
 ('YT','Mayotte','Mamoudzou','EUR','Euro','+262','MYT','.yt'),
 ('GP','Saint Barthelemy','Gustavia','EUR','Euro','+590','GLP','.gp'),
 ('PM','Saint Pierre and Miquelon','Saint-Pierre','EUR','Euro','+508','SPM','.pm'),
 ('WF','Wallis and Futuna','Mata''utu','XPF','Franc','+681','WLF','.wf'),
 ('TF','French Southern and Antarctic Lands','Martin-de-Vivi�s','','','','ATF','.tf'),
 ('BV','Bouvet Island','','','','','BVT','.bv'),
 ('CK','Cook Islands','Avarua','NZD','Dollar','+682','COK','.ck'),
 ('NU','Niue','Alofi','NZD','Dollar','+683','NIU','.nu'),
 ('TK','Tokelau','','NZD','Dollar','+690','TKL','.tk'),
 ('GG','Guernsey','Saint Peter Port','GGP','Pound','+44','GGY','.gg'),
 ('IM','Isle of Man','Douglas','IMP','Pound','+44','IMN','.im'),
 ('JE','Jersey','Saint Helier','JEP','Pound','+44','JEY','.je'),
 ('AI','Anguilla','The Valley','XCD','Dollar','+1-264','AIA','.ai'),
 ('BM','Bermuda','Hamilton','BMD','Dollar','+1-441','BMU','.bm'),
 ('IO','British Indian Ocean Territory','','','','+246','IOT','.io'),
 ('VG','British Virgin Islands','Road Town','USD','Dollar','+1-284','VGB','.vg'),
 ('KY','Cayman Islands','George Town','KYD','Dollar','+1-345','CYM','.ky'),
 ('FK','Falkland Islands (Islas Malvinas)','Stanley','FKP','Pound','+500','FLK','.fk'),
 ('GI','Gibraltar','Gibraltar','GIP','Pound','+350','GIB','.gi'),
 ('MS','Montserrat','Plymouth','XCD','Dollar','+1-664','MSR','.ms'),
 ('PN','Pitcairn Islands','Adamstown','NZD','Dollar','','PCN','.pn'),
 ('SH','Saint Helena','Jamestown','SHP','Pound','+290','SHN','.sh'),
 ('GS','South Georgia and the South Sandwich Islands','','','','','SGS','.gs'),
 ('TC','Turks and Caicos Islands','Grand Turk','USD','Dollar','+1-649','TCA','.tc'),
 ('MP','Northern Mariana Islands','Saipan','USD','Dollar','+1-670','MNP','.mp'),
 ('PR','Puerto Rico','San Juan','USD','Dollar','+1-787','PRI','.pr'),
 ('AS','American Samoa','Pago Pago','USD','Dollar','+1-684','ASM','.as'),
 ('UM','Baker Island','','','','','UMI',''),
 ('GU','Guam','Hagatna','USD','Dollar','+1-671','GUM','.gu'),
 ('VI','U.S. Virgin Islands','Charlotte Amalie','USD','Dollar','+1-340','VIR','.vi'),
 ('HK','Hong Kong','','HKD','Dollar','+852','HKG','.hk'),
 ('MO','Macau','Macau','MOP','Pataca','+853','MAC','.mo'),
 ('FO','Faroe Islands','Torshavn','DKK','Krone','+298','FRO','.fo'),
 ('GL','Greenland','Nuuk (Godthab)','DKK','Krone','+299','GRL','.gl'),
 ('GF','French Guiana','Cayenne','EUR','Euro','+594','GUF','.gf'),
 ('MQ','Martinique','Fort-de-France','EUR','Euro','+596','MTQ','.mq'),
 ('RE','Reunion','Saint-Denis','EUR','Euro','+262','REU','.re'),
 ('AX','Aland','Mariehamn','EUR','Euro','+358-18','ALA','.ax'),
 ('AW','Aruba','Oranjestad','AWG','Guilder','+297','ABW','.aw'),
 ('AN','Netherlands Antilles','Willemstad','ANG','Guilder','+599','ANT','.an'),
 ('SJ','Svalbard','Longyearbyen','NOK','Krone','+47','SJM','.sj'),
 ('AC','Ascension','Georgetown','SHP','Pound','+247','ASC','.ac'),
 ('TA','Tristan da Cunha','Edinburgh','SHP','Pound','+290','TAA',''),
 ('AQ','Antarctica','','','','','ATA','.aq'),
 ('PS','Palestinian Territories (Gaza Strip and West Bank)','Gaza City (Gaza Strip) and Ramallah (West Bank)','ILS','Shekel','+970','PSE','.ps'),
 ('EH','Western Sahara','El-Aaiun','MAD','Dirham','+212','ESH','.eh')
on conflict do nothing;
insert into base.ent (ent_name,ent_type,username,country) values ('Admin','r','admin','US')
on conflict do nothing;
insert into base.language (code,iso_3b,iso_2,eng_name,fra_name) values
 ('aar'  , 'aar'  , 'aa'  , 'Afar'  , 'afar'),
 ('abk'  , 'abk'  , 'ab'  , 'Abkhazian'  , 'abkhaze'),
 ('ace'  , 'ace'  , null  , 'Achinese'  , 'aceh'),
 ('ach'  , 'ach'  , null  , 'Acoli'  , 'acoli'),
 ('ada'  , 'ada'  , null  , 'Adangme'  , 'adangme'),
 ('ady'  , 'ady'  , null  , 'Adyghe; Adygei'  , 'adyghé'),
 ('afa'  , 'afa'  , null  , 'Afro-Asiatic languages'  , 'afro-asiatiques, langues'),
 ('afh'  , 'afh'  , null  , 'Afrihili'  , 'afrihili'),
 ('afr'  , 'afr'  , 'af'  , 'Afrikaans'  , 'afrikaans'),
 ('ain'  , 'ain'  , null  , 'Ainu'  , 'aïnou'),
 ('aka'  , 'aka'  , 'ak'  , 'Akan'  , 'akan'),
 ('akk'  , 'akk'  , null  , 'Akkadian'  , 'akkadien'),
 ('sqi'  , 'alb'  , 'sq'  , 'Albanian'  , 'albanais'),
 ('ale'  , 'ale'  , null  , 'Aleut'  , 'aléoute'),
 ('alg'  , 'alg'  , null  , 'Algonquian languages'  , 'algonquines, langues'),
 ('alt'  , 'alt'  , null  , 'Southern Altai'  , 'altai du Sud'),
 ('amh'  , 'amh'  , 'am'  , 'Amharic'  , 'amharique'),
 ('ang'  , 'ang'  , null  , 'English, Old (ca.450-1100)'  , 'anglo-saxon (ca.450-1100)'),
 ('anp'  , 'anp'  , null  , 'Angika'  , 'angika'),
 ('apa'  , 'apa'  , null  , 'Apache languages'  , 'apaches, langues'),
 ('ara'  , 'ara'  , 'ar'  , 'Arabic'  , 'arabe'),
 ('arc'  , 'arc'  , null  , 'Official Aramaic (700-300 BCE); Imperial Aramaic (700-300 BCE)'  , 'araméen d''empire (700-300 BCE)'),
 ('arg'  , 'arg'  , 'an'  , 'Aragonese'  , 'aragonais'),
 ('hye'  , 'arm'  , 'hy'  , 'Armenian'  , 'arménien'),
 ('arn'  , 'arn'  , null  , 'Mapudungun; Mapuche'  , 'mapudungun; mapuche; mapuce'),
 ('arp'  , 'arp'  , null  , 'Arapaho'  , 'arapaho'),
 ('art'  , 'art'  , null  , 'Artificial languages'  , 'artificielles, langues'),
 ('arw'  , 'arw'  , null  , 'Arawak'  , 'arawak'),
 ('asm'  , 'asm'  , 'as'  , 'Assamese'  , 'assamais'),
 ('ast'  , 'ast'  , null  , 'Asturian; Bable; Leonese; Asturleonese'  , 'asturien; bable; léonais; asturoléonais'),
 ('ath'  , 'ath'  , null  , 'Athapascan languages'  , 'athapascanes, langues'),
 ('aus'  , 'aus'  , null  , 'Australian languages'  , 'australiennes, langues'),
 ('ava'  , 'ava'  , 'av'  , 'Avaric'  , 'avar'),
 ('ave'  , 'ave'  , 'ae'  , 'Avestan'  , 'avestique'),
 ('awa'  , 'awa'  , null  , 'Awadhi'  , 'awadhi'),
 ('aym'  , 'aym'  , 'ay'  , 'Aymara'  , 'aymara'),
 ('aze'  , 'aze'  , 'az'  , 'Azerbaijani'  , 'azéri'),
 ('bad'  , 'bad'  , null  , 'Banda languages'  , 'banda, langues'),
 ('bai'  , 'bai'  , null  , 'Bamileke languages'  , 'bamiléké, langues'),
 ('bak'  , 'bak'  , 'ba'  , 'Bashkir'  , 'bachkir'),
 ('bal'  , 'bal'  , null  , 'Baluchi'  , 'baloutchi'),
 ('bam'  , 'bam'  , 'bm'  , 'Bambara'  , 'bambara'),
 ('ban'  , 'ban'  , null  , 'Balinese'  , 'balinais'),
 ('eus'  , 'baq'  , 'eu'  , 'Basque'  , 'basque'),
 ('bas'  , 'bas'  , null  , 'Basa'  , 'basa'),
 ('bat'  , 'bat'  , null  , 'Baltic languages'  , 'baltes, langues'),
 ('bej'  , 'bej'  , null  , 'Beja; Bedawiyet'  , 'bedja'),
 ('bel'  , 'bel'  , 'be'  , 'Belarusian'  , 'biélorusse'),
 ('bem'  , 'bem'  , null  , 'Bemba'  , 'bemba'),
 ('ben'  , 'ben'  , 'bn'  , 'Bengali'  , 'bengali'),
 ('ber'  , 'ber'  , null  , 'Berber languages'  , 'berbères, langues'),
 ('bho'  , 'bho'  , null  , 'Bhojpuri'  , 'bhojpuri'),
 ('bih'  , 'bih'  , 'bh'  , 'Bihari languages'  , 'langues biharis'),
 ('bik'  , 'bik'  , null  , 'Bikol'  , 'bikol'),
 ('bin'  , 'bin'  , null  , 'Bini; Edo'  , 'bini; edo'),
 ('bis'  , 'bis'  , 'bi'  , 'Bislama'  , 'bichlamar'),
 ('bla'  , 'bla'  , null  , 'Siksika'  , 'blackfoot'),
 ('bnt'  , 'bnt'  , null  , 'Bantu (Other)'  , 'bantoues, autres langues'),
 ('bos'  , 'bos'  , 'bs'  , 'Bosnian'  , 'bosniaque'),
 ('bra'  , 'bra'  , null  , 'Braj'  , 'braj'),
 ('bre'  , 'bre'  , 'br'  , 'Breton'  , 'breton'),
 ('btk'  , 'btk'  , null  , 'Batak languages'  , 'batak, langues'),
 ('bua'  , 'bua'  , null  , 'Buriat'  , 'bouriate'),
 ('bug'  , 'bug'  , null  , 'Buginese'  , 'bugi'),
 ('bul'  , 'bul'  , 'bg'  , 'Bulgarian'  , 'bulgare'),
 ('mya'  , 'bur'  , 'my'  , 'Burmese'  , 'birman'),
 ('byn'  , 'byn'  , null  , 'Blin; Bilin'  , 'blin; bilen'),
 ('cad'  , 'cad'  , null  , 'Caddo'  , 'caddo'),
 ('cai'  , 'cai'  , null  , 'Central American Indian languages'  , 'amérindiennes de L''Amérique centrale, langues'),
 ('car'  , 'car'  , null  , 'Galibi Carib'  , 'karib; galibi; carib'),
 ('cat'  , 'cat'  , 'ca'  , 'Catalan; Valencian'  , 'catalan; valencien'),
 ('cau'  , 'cau'  , null  , 'Caucasian languages'  , 'caucasiennes, langues'),
 ('ceb'  , 'ceb'  , null  , 'Cebuano'  , 'cebuano'),
 ('cel'  , 'cel'  , null  , 'Celtic languages'  , 'celtiques, langues; celtes, langues'),
 ('cha'  , 'cha'  , 'ch'  , 'Chamorro'  , 'chamorro'),
 ('chb'  , 'chb'  , null  , 'Chibcha'  , 'chibcha'),
 ('che'  , 'che'  , 'ce'  , 'Chechen'  , 'tchétchène'),
 ('chg'  , 'chg'  , null  , 'Chagatai'  , 'djaghataï'),
 ('zho'  , 'chi'  , 'zh'  , 'Chinese'  , 'chinois'),
 ('chk'  , 'chk'  , null  , 'Chuukese'  , 'chuuk'),
 ('chm'  , 'chm'  , null  , 'Mari'  , 'mari'),
 ('chn'  , 'chn'  , null  , 'Chinook jargon'  , 'chinook, jargon'),
 ('cho'  , 'cho'  , null  , 'Choctaw'  , 'choctaw'),
 ('chp'  , 'chp'  , null  , 'Chipewyan; Dene Suline'  , 'chipewyan'),
 ('chr'  , 'chr'  , null  , 'Cherokee'  , 'cherokee'),
 ('chu'  , 'chu'  , 'cu'  , 'Church Slavic; Old Slavonic; Church Slavonic; Old Bulgarian; Old Church Slavonic'  , 'slavon d''église; vieux slave; slavon liturgique; vieux bulgare'),
 ('chv'  , 'chv'  , 'cv'  , 'Chuvash'  , 'tchouvache'),
 ('chy'  , 'chy'  , null  , 'Cheyenne'  , 'cheyenne'),
 ('cmc'  , 'cmc'  , null  , 'Chamic languages'  , 'chames, langues'),
 ('cnr'  , 'cnr'  , null  , 'Montenegrin'  , 'monténégrin'),
 ('cop'  , 'cop'  , null  , 'Coptic'  , 'copte'),
 ('cor'  , 'cor'  , 'kw'  , 'Cornish'  , 'cornique'),
 ('cos'  , 'cos'  , 'co'  , 'Corsican'  , 'corse'),
 ('cpe'  , 'cpe'  , null  , 'Creoles and pidgins, English based'  , 'créoles et pidgins basés sur l''anglais'),
 ('cpf'  , 'cpf'  , null  , 'Creoles and pidgins, French-based'  , 'créoles et pidgins basés sur le français'),
 ('cpp'  , 'cpp'  , null  , 'Creoles and pidgins, Portuguese-based'  , 'créoles et pidgins basés sur le portugais'),
 ('cre'  , 'cre'  , 'cr'  , 'Cree'  , 'cree'),
 ('crh'  , 'crh'  , null  , 'Crimean Tatar; Crimean Turkish'  , 'tatar de Crimé'),
 ('crp'  , 'crp'  , null  , 'Creoles and pidgins'  , 'créoles et pidgins'),
 ('csb'  , 'csb'  , null  , 'Kashubian'  , 'kachoube'),
 ('cus'  , 'cus'  , null  , 'Cushitic languages'  , 'couchitiques, langues'),
 ('ces'  , 'cze'  , 'cs'  , 'Czech'  , 'tchèque'),
 ('dak'  , 'dak'  , null  , 'Dakota'  , 'dakota'),
 ('dan'  , 'dan'  , 'da'  , 'Danish'  , 'danois'),
 ('dar'  , 'dar'  , null  , 'Dargwa'  , 'dargwa'),
 ('day'  , 'day'  , null  , 'Land Dayak languages'  , 'dayak, langues'),
 ('del'  , 'del'  , null  , 'Delaware'  , 'delaware'),
 ('den'  , 'den'  , null  , 'Slave (Athapascan)'  , 'esclave (athapascan)'),
 ('dgr'  , 'dgr'  , null  , 'Dogrib'  , 'dogrib'),
 ('din'  , 'din'  , null  , 'Dinka'  , 'dinka'),
 ('div'  , 'div'  , 'dv'  , 'Divehi; Dhivehi; Maldivian'  , 'maldivien'),
 ('doi'  , 'doi'  , null  , 'Dogri'  , 'dogri'),
 ('dra'  , 'dra'  , null  , 'Dravidian languages'  , 'dravidiennes, langues'),
 ('dsb'  , 'dsb'  , null  , 'Lower Sorbian'  , 'bas-sorabe'),
 ('dua'  , 'dua'  , null  , 'Duala'  , 'douala'),
 ('dum'  , 'dum'  , null  , 'Dutch, Middle (ca.1050-1350)'  , 'néerlandais moyen (ca. 1050-1350)'),
 ('nld'  , 'dut'  , 'nl'  , 'Dutch; Flemish'  , 'néerlandais; flamand'),
 ('dyu'  , 'dyu'  , null  , 'Dyula'  , 'dioula'),
 ('dzo'  , 'dzo'  , 'dz'  , 'Dzongkha'  , 'dzongkha'),
 ('efi'  , 'efi'  , null  , 'Efik'  , 'efik'),
 ('egy'  , 'egy'  , null  , 'Egyptian (Ancient)'  , 'égyptien'),
 ('eka'  , 'eka'  , null  , 'Ekajuk'  , 'ekajuk'),
 ('elx'  , 'elx'  , null  , 'Elamite'  , 'élamite'),
 ('eng'  , 'eng'  , 'en'  , 'English'  , 'anglais'),
 ('enm'  , 'enm'  , null  , 'English, Middle (1100-1500)'  , 'anglais moyen (1100-1500)'),
 ('epo'  , 'epo'  , 'eo'  , 'Esperanto'  , 'espéranto'),
 ('est'  , 'est'  , 'et'  , 'Estonian'  , 'estonien'),
 ('ewe'  , 'ewe'  , 'ee'  , 'Ewe'  , 'éwé'),
 ('ewo'  , 'ewo'  , null  , 'Ewondo'  , 'éwondo'),
 ('fan'  , 'fan'  , null  , 'Fang'  , 'fang'),
 ('fao'  , 'fao'  , 'fo'  , 'Faroese'  , 'féroïen'),
 ('fat'  , 'fat'  , null  , 'Fanti'  , 'fanti'),
 ('fij'  , 'fij'  , 'fj'  , 'Fijian'  , 'fidjien'),
 ('fil'  , 'fil'  , null  , 'Filipino; Pilipino'  , 'filipino; pilipino'),
 ('fin'  , 'fin'  , 'fi'  , 'Finnish'  , 'finnois'),
 ('fiu'  , 'fiu'  , null  , 'Finno-Ugrian languages'  , 'finno-ougriennes, langues'),
 ('fon'  , 'fon'  , null  , 'Fon'  , 'fon'),
 ('fra'  , 'fre'  , 'fr'  , 'French'  , 'français'),
 ('frm'  , 'frm'  , null  , 'French, Middle (ca.1400-1600)'  , 'français moyen (1400-1600)'),
 ('fro'  , 'fro'  , null  , 'French, Old (842-ca.1400)'  , 'français ancien (842-ca.1400)'),
 ('frr'  , 'frr'  , null  , 'Northern Frisian'  , 'frison septentrional'),
 ('frs'  , 'frs'  , null  , 'Eastern Frisian'  , 'frison oriental'),
 ('fry'  , 'fry'  , 'fy'  , 'Western Frisian'  , 'frison occidental'),
 ('ful'  , 'ful'  , 'ff'  , 'Fulah'  , 'peul'),
 ('fur'  , 'fur'  , null  , 'Friulian'  , 'frioulan'),
 ('gaa'  , 'gaa'  , null  , 'Ga'  , 'ga'),
 ('gay'  , 'gay'  , null  , 'Gayo'  , 'gayo'),
 ('gba'  , 'gba'  , null  , 'Gbaya'  , 'gbaya'),
 ('gem'  , 'gem'  , null  , 'Germanic languages'  , 'germaniques, langues'),
 ('kat'  , 'geo'  , 'ka'  , 'Georgian'  , 'géorgien'),
 ('deu'  , 'ger'  , 'de'  , 'German'  , 'allemand'),
 ('gez'  , 'gez'  , null  , 'Geez'  , 'guèze'),
 ('gil'  , 'gil'  , null  , 'Gilbertese'  , 'kiribati'),
 ('gla'  , 'gla'  , 'gd'  , 'Gaelic; Scottish Gaelic'  , 'gaélique; gaélique écossais'),
 ('gle'  , 'gle'  , 'ga'  , 'Irish'  , 'irlandais'),
 ('glg'  , 'glg'  , 'gl'  , 'Galician'  , 'galicien'),
 ('glv'  , 'glv'  , 'gv'  , 'Manx'  , 'manx; mannois'),
 ('gmh'  , 'gmh'  , null  , 'German, Middle High (ca.1050-1500)'  , 'allemand, moyen haut (ca. 1050-1500)'),
 ('goh'  , 'goh'  , null  , 'German, Old High (ca.750-1050)'  , 'allemand, vieux haut (ca. 750-1050)'),
 ('gon'  , 'gon'  , null  , 'Gondi'  , 'gond'),
 ('gor'  , 'gor'  , null  , 'Gorontalo'  , 'gorontalo'),
 ('got'  , 'got'  , null  , 'Gothic'  , 'gothique'),
 ('grb'  , 'grb'  , null  , 'Grebo'  , 'grebo'),
 ('grc'  , 'grc'  , null  , 'Greek, Ancient (to 1453)'  , 'grec ancien (jusqu''à 1453)'),
 ('ell'  , 'gre'  , 'el'  , 'Greek, Modern (1453-)'  , 'grec moderne (après 1453)'),
 ('grn'  , 'grn'  , 'gn'  , 'Guarani'  , 'guarani'),
 ('gsw'  , 'gsw'  , null  , 'Swiss German; Alemannic; Alsatian'  , 'suisse alémanique; alémanique; alsacien'),
 ('guj'  , 'guj'  , 'gu'  , 'Gujarati'  , 'goudjrati'),
 ('gwi'  , 'gwi'  , null  , 'Gwich''in'  , 'gwich''in'),
 ('hai'  , 'hai'  , null  , 'Haida'  , 'haida'),
 ('hat'  , 'hat'  , 'ht'  , 'Haitian; Haitian Creole'  , 'haïtien; créole haïtien'),
 ('hau'  , 'hau'  , 'ha'  , 'Hausa'  , 'haoussa'),
 ('haw'  , 'haw'  , null  , 'Hawaiian'  , 'hawaïen'),
 ('heb'  , 'heb'  , 'he'  , 'Hebrew'  , 'hébreu'),
 ('her'  , 'her'  , 'hz'  , 'Herero'  , 'herero'),
 ('hil'  , 'hil'  , null  , 'Hiligaynon'  , 'hiligaynon'),
 ('him'  , 'him'  , null  , 'Himachali languages; Western Pahari languages'  , 'langues himachalis; langues paharis occidentales'),
 ('hin'  , 'hin'  , 'hi'  , 'Hindi'  , 'hindi'),
 ('hit'  , 'hit'  , null  , 'Hittite'  , 'hittite'),
 ('hmn'  , 'hmn'  , null  , 'Hmong; Mong'  , 'hmong'),
 ('hmo'  , 'hmo'  , 'ho'  , 'Hiri Motu'  , 'hiri motu'),
 ('hrv'  , 'hrv'  , 'hr'  , 'Croatian'  , 'croate'),
 ('hsb'  , 'hsb'  , null  , 'Upper Sorbian'  , 'haut-sorabe'),
 ('hun'  , 'hun'  , 'hu'  , 'Hungarian'  , 'hongrois'),
 ('hup'  , 'hup'  , null  , 'Hupa'  , 'hupa'),
 ('iba'  , 'iba'  , null  , 'Iban'  , 'iban'),
 ('ibo'  , 'ibo'  , 'ig'  , 'Igbo'  , 'igbo'),
 ('isl'  , 'ice'  , 'is'  , 'Icelandic'  , 'islandais'),
 ('ido'  , 'ido'  , 'io'  , 'Ido'  , 'ido'),
 ('iii'  , 'iii'  , 'ii'  , 'Sichuan Yi; Nuosu'  , 'yi de Sichuan'),
 ('ijo'  , 'ijo'  , null  , 'Ijo languages'  , 'ijo, langues'),
 ('iku'  , 'iku'  , 'iu'  , 'Inuktitut'  , 'inuktitut'),
 ('ile'  , 'ile'  , 'ie'  , 'Interlingue; Occidental'  , 'interlingue'),
 ('ilo'  , 'ilo'  , null  , 'Iloko'  , 'ilocano'),
 ('ina'  , 'ina'  , 'ia'  , 'Interlingua (International Auxiliary Language Association)'  , 'interlingua (langue auxiliaire internationale)'),
 ('inc'  , 'inc'  , null  , 'Indic languages'  , 'indo-aryennes, langues'),
 ('ind'  , 'ind'  , 'id'  , 'Indonesian'  , 'indonésien'),
 ('ine'  , 'ine'  , null  , 'Indo-European languages'  , 'indo-européennes, langues'),
 ('inh'  , 'inh'  , null  , 'Ingush'  , 'ingouche'),
 ('ipk'  , 'ipk'  , 'ik'  , 'Inupiaq'  , 'inupiaq'),
 ('ira'  , 'ira'  , null  , 'Iranian languages'  , 'iraniennes, langues'),
 ('iro'  , 'iro'  , null  , 'Iroquoian languages'  , 'iroquoises, langues'),
 ('ita'  , 'ita'  , 'it'  , 'Italian'  , 'italien'),
 ('jav'  , 'jav'  , 'jv'  , 'Javanese'  , 'javanais'),
 ('jbo'  , 'jbo'  , null  , 'Lojban'  , 'lojban'),
 ('jpn'  , 'jpn'  , 'ja'  , 'Japanese'  , 'japonais'),
 ('jpr'  , 'jpr'  , null  , 'Judeo-Persian'  , 'judéo-persan'),
 ('jrb'  , 'jrb'  , null  , 'Judeo-Arabic'  , 'judéo-arabe'),
 ('kaa'  , 'kaa'  , null  , 'Kara-Kalpak'  , 'karakalpak'),
 ('kab'  , 'kab'  , null  , 'Kabyle'  , 'kabyle'),
 ('kac'  , 'kac'  , null  , 'Kachin; Jingpho'  , 'kachin; jingpho'),
 ('kal'  , 'kal'  , 'kl'  , 'Kalaallisut; Greenlandic'  , 'groenlandais'),
 ('kam'  , 'kam'  , null  , 'Kamba'  , 'kamba'),
 ('kan'  , 'kan'  , 'kn'  , 'Kannada'  , 'kannada'),
 ('kar'  , 'kar'  , null  , 'Karen languages'  , 'karen, langues'),
 ('kas'  , 'kas'  , 'ks'  , 'Kashmiri'  , 'kashmiri'),
 ('kau'  , 'kau'  , 'kr'  , 'Kanuri'  , 'kanouri'),
 ('kaw'  , 'kaw'  , null  , 'Kawi'  , 'kawi'),
 ('kaz'  , 'kaz'  , 'kk'  , 'Kazakh'  , 'kazakh'),
 ('kbd'  , 'kbd'  , null  , 'Kabardian'  , 'kabardien'),
 ('kha'  , 'kha'  , null  , 'Khasi'  , 'khasi'),
 ('khi'  , 'khi'  , null  , 'Khoisan languages'  , 'khoïsan, langues'),
 ('khm'  , 'khm'  , 'km'  , 'Central Khmer'  , 'khmer central'),
 ('kho'  , 'kho'  , null  , 'Khotanese; Sakan'  , 'khotanais; sakan'),
 ('kik'  , 'kik'  , 'ki'  , 'Kikuyu; Gikuyu'  , 'kikuyu'),
 ('kin'  , 'kin'  , 'rw'  , 'Kinyarwanda'  , 'rwanda'),
 ('kir'  , 'kir'  , 'ky'  , 'Kirghiz; Kyrgyz'  , 'kirghiz'),
 ('kmb'  , 'kmb'  , null  , 'Kimbundu'  , 'kimbundu'),
 ('kok'  , 'kok'  , null  , 'Konkani'  , 'konkani'),
 ('kom'  , 'kom'  , 'kv'  , 'Komi'  , 'kom'),
 ('kon'  , 'kon'  , 'kg'  , 'Kongo'  , 'kongo'),
 ('kor'  , 'kor'  , 'ko'  , 'Korean'  , 'coréen'),
 ('kos'  , 'kos'  , null  , 'Kosraean'  , 'kosrae'),
 ('kpe'  , 'kpe'  , null  , 'Kpelle'  , 'kpellé'),
 ('krc'  , 'krc'  , null  , 'Karachay-Balkar'  , 'karatchai balkar'),
 ('krl'  , 'krl'  , null  , 'Karelian'  , 'carélien'),
 ('kro'  , 'kro'  , null  , 'Kru languages'  , 'krou, langues'),
 ('kru'  , 'kru'  , null  , 'Kurukh'  , 'kurukh'),
 ('kua'  , 'kua'  , 'kj'  , 'Kuanyama; Kwanyama'  , 'kuanyama; kwanyama'),
 ('kum'  , 'kum'  , null  , 'Kumyk'  , 'koumyk'),
 ('kur'  , 'kur'  , 'ku'  , 'Kurdish'  , 'kurde'),
 ('kut'  , 'kut'  , null  , 'Kutenai'  , 'kutenai'),
 ('lad'  , 'lad'  , null  , 'Ladino'  , 'judéo-espagnol'),
 ('lah'  , 'lah'  , null  , 'Lahnda'  , 'lahnda'),
 ('lam'  , 'lam'  , null  , 'Lamba'  , 'lamba'),
 ('lao'  , 'lao'  , 'lo'  , 'Lao'  , 'lao'),
 ('lat'  , 'lat'  , 'la'  , 'Latin'  , 'latin'),
 ('lav'  , 'lav'  , 'lv'  , 'Latvian'  , 'letton'),
 ('lez'  , 'lez'  , null  , 'Lezghian'  , 'lezghien'),
 ('lim'  , 'lim'  , 'li'  , 'Limburgan; Limburger; Limburgish'  , 'limbourgeois'),
 ('lin'  , 'lin'  , 'ln'  , 'Lingala'  , 'lingala'),
 ('lit'  , 'lit'  , 'lt'  , 'Lithuanian'  , 'lituanien'),
 ('lol'  , 'lol'  , null  , 'Mongo'  , 'mongo'),
 ('loz'  , 'loz'  , null  , 'Lozi'  , 'lozi'),
 ('ltz'  , 'ltz'  , 'lb'  , 'Luxembourgish; Letzeburgesch'  , 'luxembourgeois'),
 ('lua'  , 'lua'  , null  , 'Luba-Lulua'  , 'luba-lulua'),
 ('lub'  , 'lub'  , 'lu'  , 'Luba-Katanga'  , 'luba-katanga'),
 ('lug'  , 'lug'  , 'lg'  , 'Ganda'  , 'ganda'),
 ('lui'  , 'lui'  , null  , 'Luiseno'  , 'luiseno'),
 ('lun'  , 'lun'  , null  , 'Lunda'  , 'lunda'),
 ('luo'  , 'luo'  , null  , 'Luo (Kenya and Tanzania)'  , 'luo (Kenya et Tanzanie)'),
 ('lus'  , 'lus'  , null  , 'Lushai'  , 'lushai'),
 ('mkd'  , 'mac'  , 'mk'  , 'Macedonian'  , 'macédonien'),
 ('mad'  , 'mad'  , null  , 'Madurese'  , 'madourais'),
 ('mag'  , 'mag'  , null  , 'Magahi'  , 'magahi'),
 ('mah'  , 'mah'  , 'mh'  , 'Marshallese'  , 'marshall'),
 ('mai'  , 'mai'  , null  , 'Maithili'  , 'maithili'),
 ('mak'  , 'mak'  , null  , 'Makasar'  , 'makassar'),
 ('mal'  , 'mal'  , 'ml'  , 'Malayalam'  , 'malayalam'),
 ('man'  , 'man'  , null  , 'Mandingo'  , 'mandingue'),
 ('mri'  , 'mao'  , 'mi'  , 'Maori'  , 'maori'),
 ('map'  , 'map'  , null  , 'Austronesian languages'  , 'austronésiennes, langues'),
 ('mar'  , 'mar'  , 'mr'  , 'Marathi'  , 'marathe'),
 ('mas'  , 'mas'  , null  , 'Masai'  , 'massaï'),
 ('msa'  , 'may'  , 'ms'  , 'Malay'  , 'malais'),
 ('mdf'  , 'mdf'  , null  , 'Moksha'  , 'moksa'),
 ('mdr'  , 'mdr'  , null  , 'Mandar'  , 'mandar'),
 ('men'  , 'men'  , null  , 'Mende'  , 'mendé'),
 ('mga'  , 'mga'  , null  , 'Irish, Middle (900-1200)'  , 'irlandais moyen (900-1200)'),
 ('mic'  , 'mic'  , null  , 'Mi''kmaq; Micmac'  , 'mi''kmaq; micmac'),
 ('min'  , 'min'  , null  , 'Minangkabau'  , 'minangkabau'),
 ('mis'  , 'mis'  , null  , 'Uncoded languages'  , 'langues non codées'),
 ('mkh'  , 'mkh'  , null  , 'Mon-Khmer languages'  , 'môn-khmer, langues'),
 ('mlg'  , 'mlg'  , 'mg'  , 'Malagasy'  , 'malgache'),
 ('mlt'  , 'mlt'  , 'mt'  , 'Maltese'  , 'maltais'),
 ('mnc'  , 'mnc'  , null  , 'Manchu'  , 'mandchou'),
 ('mni'  , 'mni'  , null  , 'Manipuri'  , 'manipuri'),
 ('mno'  , 'mno'  , null  , 'Manobo languages'  , 'manobo, langues'),
 ('moh'  , 'moh'  , null  , 'Mohawk'  , 'mohawk'),
 ('mon'  , 'mon'  , 'mn'  , 'Mongolian'  , 'mongol'),
 ('mos'  , 'mos'  , null  , 'Mossi'  , 'moré'),
 ('mul'  , 'mul'  , null  , 'Multiple languages'  , 'multilingue'),
 ('mun'  , 'mun'  , null  , 'Munda languages'  , 'mounda, langues'),
 ('mus'  , 'mus'  , null  , 'Creek'  , 'muskogee'),
 ('mwl'  , 'mwl'  , null  , 'Mirandese'  , 'mirandais'),
 ('mwr'  , 'mwr'  , null  , 'Marwari'  , 'marvari'),
 ('myn'  , 'myn'  , null  , 'Mayan languages'  , 'maya, langues'),
 ('myv'  , 'myv'  , null  , 'Erzya'  , 'erza'),
 ('nah'  , 'nah'  , null  , 'Nahuatl languages'  , 'nahuatl, langues'),
 ('nai'  , 'nai'  , null  , 'North American Indian languages'  , 'nord-amérindiennes, langues'),
 ('nap'  , 'nap'  , null  , 'Neapolitan'  , 'napolitain'),
 ('nau'  , 'nau'  , 'na'  , 'Nauru'  , 'nauruan'),
 ('nav'  , 'nav'  , 'nv'  , 'Navajo; Navaho'  , 'navaho'),
 ('nbl'  , 'nbl'  , 'nr'  , 'Ndebele, South; South Ndebele'  , 'ndébélé du Sud'),
 ('nde'  , 'nde'  , 'nd'  , 'Ndebele, North; North Ndebele'  , 'ndébélé du Nord'),
 ('ndo'  , 'ndo'  , 'ng'  , 'Ndonga'  , 'ndonga'),
 ('nds'  , 'nds'  , null  , 'Low German; Low Saxon; German, Low; Saxon, Low'  , 'bas allemand; bas saxon; allemand, bas; saxon, bas'),
 ('nep'  , 'nep'  , 'ne'  , 'Nepali'  , 'népalais'),
 ('new'  , 'new'  , null  , 'Nepal Bhasa; Newari'  , 'nepal bhasa; newari'),
 ('nia'  , 'nia'  , null  , 'Nias'  , 'nias'),
 ('nic'  , 'nic'  , null  , 'Niger-Kordofanian languages'  , 'nigéro-kordofaniennes, langues'),
 ('niu'  , 'niu'  , null  , 'Niuean'  , 'niué'),
 ('nno'  , 'nno'  , 'nn'  , 'Norwegian Nynorsk; Nynorsk, Norwegian'  , 'norvégien nynorsk; nynorsk, norvégien'),
 ('nob'  , 'nob'  , 'nb'  , 'Bokmål, Norwegian; Norwegian Bokmål'  , 'norvégien bokmål'),
 ('nog'  , 'nog'  , null  , 'Nogai'  , 'nogaï; nogay'),
 ('non'  , 'non'  , null  , 'Norse, Old'  , 'norrois, vieux'),
 ('nor'  , 'nor'  , 'no'  , 'Norwegian'  , 'norvégien'),
 ('nqo'  , 'nqo'  , null  , 'N''Ko'  , 'n''ko'),
 ('nso'  , 'nso'  , null  , 'Pedi; Sepedi; Northern Sotho'  , 'pedi; sepedi; sotho du Nord'),
 ('nub'  , 'nub'  , null  , 'Nubian languages'  , 'nubiennes, langues'),
 ('nwc'  , 'nwc'  , null  , 'Classical Newari; Old Newari; Classical Nepal Bhasa'  , 'newari classique'),
 ('nya'  , 'nya'  , 'ny'  , 'Chichewa; Chewa; Nyanja'  , 'chichewa; chewa; nyanja'),
 ('nym'  , 'nym'  , null  , 'Nyamwezi'  , 'nyamwezi'),
 ('nyn'  , 'nyn'  , null  , 'Nyankole'  , 'nyankolé'),
 ('nyo'  , 'nyo'  , null  , 'Nyoro'  , 'nyoro'),
 ('nzi'  , 'nzi'  , null  , 'Nzima'  , 'nzema'),
 ('oci'  , 'oci'  , 'oc'  , 'Occitan (post 1500); Provençal'  , 'occitan (après 1500); provençal'),
 ('oji'  , 'oji'  , 'oj'  , 'Ojibwa'  , 'ojibwa'),
 ('ori'  , 'ori'  , 'or'  , 'Oriya'  , 'oriya'),
 ('orm'  , 'orm'  , 'om'  , 'Oromo'  , 'galla'),
 ('osa'  , 'osa'  , null  , 'Osage'  , 'osage'),
 ('oss'  , 'oss'  , 'os'  , 'Ossetian; Ossetic'  , 'ossète'),
 ('ota'  , 'ota'  , null  , 'Turkish, Ottoman (1500-1928)'  , 'turc ottoman (1500-1928)'),
 ('oto'  , 'oto'  , null  , 'Otomian languages'  , 'otomi, langues'),
 ('paa'  , 'paa'  , null  , 'Papuan languages'  , 'papoues, langues'),
 ('pag'  , 'pag'  , null  , 'Pangasinan'  , 'pangasinan'),
 ('pal'  , 'pal'  , null  , 'Pahlavi'  , 'pahlavi'),
 ('pam'  , 'pam'  , null  , 'Pampanga; Kapampangan'  , 'pampangan'),
 ('pan'  , 'pan'  , 'pa'  , 'Panjabi; Punjabi'  , 'pendjabi'),
 ('pap'  , 'pap'  , null  , 'Papiamento'  , 'papiamento'),
 ('pau'  , 'pau'  , null  , 'Palauan'  , 'palau'),
 ('peo'  , 'peo'  , null  , 'Persian, Old (ca.600-400 B.C.)'  , 'perse, vieux (ca. 600-400 av. J.-C.)'),
 ('fas'  , 'per'  , 'fa'  , 'Persian'  , 'persan'),
 ('phi'  , 'phi'  , null  , 'Philippine languages'  , 'philippines, langues'),
 ('phn'  , 'phn'  , null  , 'Phoenician'  , 'phénicien'),
 ('pli'  , 'pli'  , 'pi'  , 'Pali'  , 'pali'),
 ('pol'  , 'pol'  , 'pl'  , 'Polish'  , 'polonais'),
 ('pon'  , 'pon'  , null  , 'Pohnpeian'  , 'pohnpei'),
 ('por'  , 'por'  , 'pt'  , 'Portuguese'  , 'portugais'),
 ('pra'  , 'pra'  , null  , 'Prakrit languages'  , 'prâkrit, langues'),
 ('pro'  , 'pro'  , null  , 'Provençal, Old (to 1500)'  , 'provençal ancien (jusqu''à 1500)'),
 ('pus'  , 'pus'  , 'ps'  , 'Pushto; Pashto'  , 'pachto'),
 ('que'  , 'que'  , 'qu'  , 'Quechua'  , 'quechua'),
 ('raj'  , 'raj'  , null  , 'Rajasthani'  , 'rajasthani'),
 ('rap'  , 'rap'  , null  , 'Rapanui'  , 'rapanui'),
 ('rar'  , 'rar'  , null  , 'Rarotongan; Cook Islands Maori'  , 'rarotonga; maori des îles Cook'),
 ('roa'  , 'roa'  , null  , 'Romance languages'  , 'romanes, langues'),
 ('roh'  , 'roh'  , 'rm'  , 'Romansh'  , 'romanche'),
 ('rom'  , 'rom'  , null  , 'Romany'  , 'tsigane'),
 ('ron'  , 'rum'  , 'ro'  , 'Romanian; Moldavian; Moldovan'  , 'roumain; moldave'),
 ('run'  , 'run'  , 'rn'  , 'Rundi'  , 'rundi'),
 ('rup'  , 'rup'  , null  , 'Aromanian; Arumanian; Macedo-Romanian'  , 'aroumain; macédo-roumain'),
 ('rus'  , 'rus'  , 'ru'  , 'Russian'  , 'russe'),
 ('sad'  , 'sad'  , null  , 'Sandawe'  , 'sandawe'),
 ('sag'  , 'sag'  , 'sg'  , 'Sango'  , 'sango'),
 ('sah'  , 'sah'  , null  , 'Yakut'  , 'iakoute'),
 ('sai'  , 'sai'  , null  , 'South American Indian (Other)'  , 'indiennes d''Amérique du Sud, autres langues'),
 ('sal'  , 'sal'  , null  , 'Salishan languages'  , 'salishennes, langues'),
 ('sam'  , 'sam'  , null  , 'Samaritan Aramaic'  , 'samaritain'),
 ('san'  , 'san'  , 'sa'  , 'Sanskrit'  , 'sanskrit'),
 ('sas'  , 'sas'  , null  , 'Sasak'  , 'sasak'),
 ('sat'  , 'sat'  , null  , 'Santali'  , 'santal'),
 ('scn'  , 'scn'  , null  , 'Sicilian'  , 'sicilien'),
 ('sco'  , 'sco'  , null  , 'Scots'  , 'écossais'),
 ('sel'  , 'sel'  , null  , 'Selkup'  , 'selkoupe'),
 ('sem'  , 'sem'  , null  , 'Semitic languages'  , 'sémitiques, langues'),
 ('sga'  , 'sga'  , null  , 'Irish, Old (to 900)'  , 'irlandais ancien (jusqu''à 900)'),
 ('sgn'  , 'sgn'  , null  , 'Sign Languages'  , 'langues des signes'),
 ('shn'  , 'shn'  , null  , 'Shan'  , 'chan'),
 ('sid'  , 'sid'  , null  , 'Sidamo'  , 'sidamo'),
 ('sin'  , 'sin'  , 'si'  , 'Sinhala; Sinhalese'  , 'singhalais'),
 ('sio'  , 'sio'  , null  , 'Siouan languages'  , 'sioux, langues'),
 ('sit'  , 'sit'  , null  , 'Sino-Tibetan languages'  , 'sino-tibétaines, langues'),
 ('sla'  , 'sla'  , null  , 'Slavic languages'  , 'slaves, langues'),
 ('slk'  , 'slo'  , 'sk'  , 'Slovak'  , 'slovaque'),
 ('slv'  , 'slv'  , 'sl'  , 'Slovenian'  , 'slovène'),
 ('sma'  , 'sma'  , null  , 'Southern Sami'  , 'sami du Sud'),
 ('sme'  , 'sme'  , 'se'  , 'Northern Sami'  , 'sami du Nord'),
 ('smi'  , 'smi'  , null  , 'Sami languages'  , 'sames, langues'),
 ('smj'  , 'smj'  , null  , 'Lule Sami'  , 'sami de Lule'),
 ('smn'  , 'smn'  , null  , 'Inari Sami'  , 'sami d''Inari'),
 ('smo'  , 'smo'  , 'sm'  , 'Samoan'  , 'samoan'),
 ('sms'  , 'sms'  , null  , 'Skolt Sami'  , 'sami skolt'),
 ('sna'  , 'sna'  , 'sn'  , 'Shona'  , 'shona'),
 ('snd'  , 'snd'  , 'sd'  , 'Sindhi'  , 'sindhi'),
 ('snk'  , 'snk'  , null  , 'Soninke'  , 'soninké'),
 ('sog'  , 'sog'  , null  , 'Sogdian'  , 'sogdien'),
 ('som'  , 'som'  , 'so'  , 'Somali'  , 'somali'),
 ('son'  , 'son'  , null  , 'Songhai languages'  , 'songhai, langues'),
 ('sot'  , 'sot'  , 'st'  , 'Sotho, Southern'  , 'sotho du Sud'),
 ('spa'  , 'spa'  , 'es'  , 'Spanish; Castilian'  , 'espagnol; castillan'),
 ('srd'  , 'srd'  , 'sc'  , 'Sardinian'  , 'sarde'),
 ('srn'  , 'srn'  , null  , 'Sranan Tongo'  , 'sranan tongo'),
 ('srp'  , 'srp'  , 'sr'  , 'Serbian'  , 'serbe'),
 ('srr'  , 'srr'  , null  , 'Serer'  , 'sérère'),
 ('ssa'  , 'ssa'  , null  , 'Nilo-Saharan languages'  , 'nilo-sahariennes, langues'),
 ('ssw'  , 'ssw'  , 'ss'  , 'Swati'  , 'swati'),
 ('suk'  , 'suk'  , null  , 'Sukuma'  , 'sukuma'),
 ('sun'  , 'sun'  , 'su'  , 'Sundanese'  , 'soundanais'),
 ('sus'  , 'sus'  , null  , 'Susu'  , 'soussou'),
 ('sux'  , 'sux'  , null  , 'Sumerian'  , 'sumérien'),
 ('swa'  , 'swa'  , 'sw'  , 'Swahili'  , 'swahili'),
 ('swe'  , 'swe'  , 'sv'  , 'Swedish'  , 'suédois'),
 ('syc'  , 'syc'  , null  , 'Classical Syriac'  , 'syriaque classique'),
 ('syr'  , 'syr'  , null  , 'Syriac'  , 'syriaque'),
 ('tah'  , 'tah'  , 'ty'  , 'Tahitian'  , 'tahitien'),
 ('tai'  , 'tai'  , null  , 'Tai languages'  , 'tai, langues'),
 ('tam'  , 'tam'  , 'ta'  , 'Tamil'  , 'tamoul'),
 ('tat'  , 'tat'  , 'tt'  , 'Tatar'  , 'tatar'),
 ('tel'  , 'tel'  , 'te'  , 'Telugu'  , 'télougou'),
 ('tem'  , 'tem'  , null  , 'Timne'  , 'temne'),
 ('ter'  , 'ter'  , null  , 'Tereno'  , 'tereno'),
 ('tet'  , 'tet'  , null  , 'Tetum'  , 'tetum'),
 ('tgk'  , 'tgk'  , 'tg'  , 'Tajik'  , 'tadjik'),
 ('tgl'  , 'tgl'  , 'tl'  , 'Tagalog'  , 'tagalog'),
 ('tha'  , 'tha'  , 'th'  , 'Thai'  , 'thaï'),
 ('bod'  , 'tib'  , 'bo'  , 'Tibetan'  , 'tibétain'),
 ('tig'  , 'tig'  , null  , 'Tigre'  , 'tigré'),
 ('tir'  , 'tir'  , 'ti'  , 'Tigrinya'  , 'tigrigna'),
 ('tiv'  , 'tiv'  , null  , 'Tiv'  , 'tiv'),
 ('tkl'  , 'tkl'  , null  , 'Tokelau'  , 'tokelau'),
 ('tlh'  , 'tlh'  , null  , 'Klingon; tlhIngan-Hol'  , 'klingon'),
 ('tli'  , 'tli'  , null  , 'Tlingit'  , 'tlingit'),
 ('tmh'  , 'tmh'  , null  , 'Tamashek'  , 'tamacheq'),
 ('tog'  , 'tog'  , null  , 'Tonga (Nyasa)'  , 'tonga (Nyasa)'),
 ('ton'  , 'ton'  , 'to'  , 'Tonga (Tonga Islands)'  , 'tongan (Îles Tonga)'),
 ('tpi'  , 'tpi'  , null  , 'Tok Pisin'  , 'tok pisin'),
 ('tsi'  , 'tsi'  , null  , 'Tsimshian'  , 'tsimshian'),
 ('tsn'  , 'tsn'  , 'tn'  , 'Tswana'  , 'tswana'),
 ('tso'  , 'tso'  , 'ts'  , 'Tsonga'  , 'tsonga'),
 ('tuk'  , 'tuk'  , 'tk'  , 'Turkmen'  , 'turkmène'),
 ('tum'  , 'tum'  , null  , 'Tumbuka'  , 'tumbuka'),
 ('tup'  , 'tup'  , null  , 'Tupi languages'  , 'tupi, langues'),
 ('tur'  , 'tur'  , 'tr'  , 'Turkish'  , 'turc'),
 ('tut'  , 'tut'  , null  , 'Altaic languages'  , 'altaïques, langues'),
 ('tvl'  , 'tvl'  , null  , 'Tuvalu'  , 'tuvalu'),
 ('twi'  , 'twi'  , 'tw'  , 'Twi'  , 'twi'),
 ('tyv'  , 'tyv'  , null  , 'Tuvinian'  , 'touva'),
 ('udm'  , 'udm'  , null  , 'Udmurt'  , 'oudmourte'),
 ('uga'  , 'uga'  , null  , 'Ugaritic'  , 'ougaritique'),
 ('uig'  , 'uig'  , 'ug'  , 'Uighur; Uyghur'  , 'ouïgour'),
 ('ukr'  , 'ukr'  , 'uk'  , 'Ukrainian'  , 'ukrainien'),
 ('umb'  , 'umb'  , null  , 'Umbundu'  , 'umbundu'),
 ('und'  , 'und'  , null  , 'Undetermined'  , 'indéterminée'),
 ('urd'  , 'urd'  , 'ur'  , 'Urdu'  , 'ourdou'),
 ('uzb'  , 'uzb'  , 'uz'  , 'Uzbek'  , 'ouszbek'),
 ('vai'  , 'vai'  , null  , 'Vai'  , 'vaï'),
 ('ven'  , 'ven'  , 've'  , 'Venda'  , 'venda'),
 ('vie'  , 'vie'  , 'vi'  , 'Vietnamese'  , 'vietnamien'),
 ('vol'  , 'vol'  , 'vo'  , 'Volapük'  , 'volapük'),
 ('vot'  , 'vot'  , null  , 'Votic'  , 'vote'),
 ('wak'  , 'wak'  , null  , 'Wakashan languages'  , 'wakashanes, langues'),
 ('wal'  , 'wal'  , null  , 'Walamo'  , 'walamo'),
 ('war'  , 'war'  , null  , 'Waray'  , 'waray'),
 ('was'  , 'was'  , null  , 'Washo'  , 'washo'),
 ('cym'  , 'wel'  , 'cy'  , 'Welsh'  , 'gallois'),
 ('wen'  , 'wen'  , null  , 'Sorbian languages'  , 'sorabes, langues'),
 ('wln'  , 'wln'  , 'wa'  , 'Walloon'  , 'wallon'),
 ('wol'  , 'wol'  , 'wo'  , 'Wolof'  , 'wolof'),
 ('xal'  , 'xal'  , null  , 'Kalmyk; Oirat'  , 'kalmouk; oïrat'),
 ('xho'  , 'xho'  , 'xh'  , 'Xhosa'  , 'xhosa'),
 ('yao'  , 'yao'  , null  , 'Yao'  , 'yao'),
 ('yap'  , 'yap'  , null  , 'Yapese'  , 'yapois'),
 ('yid'  , 'yid'  , 'yi'  , 'Yiddish'  , 'yiddish'),
 ('yor'  , 'yor'  , 'yo'  , 'Yoruba'  , 'yoruba'),
 ('ypk'  , 'ypk'  , null  , 'Yupik languages'  , 'yupik, langues'),
 ('zap'  , 'zap'  , null  , 'Zapotec'  , 'zapotèque'),
 ('zbl'  , 'zbl'  , null  , 'Blissymbols; Blissymbolics; Bliss'  , 'symboles Bliss; Bliss'),
 ('zen'  , 'zen'  , null  , 'Zenaga'  , 'zenaga'),
 ('zgh'  , 'zgh'  , null  , 'Standard Moroccan Tamazight'  , 'amazighe standard marocain'),
 ('zha'  , 'zha'  , 'za'  , 'Zhuang; Chuang'  , 'zhuang; chuang'),
 ('znd'  , 'znd'  , null  , 'Zande languages'  , 'zandé, langues'),
 ('zul'  , 'zul'  , 'zu'  , 'Zulu'  , 'zoulou'),
 ('zun'  , 'zun'  , null  , 'Zuni'  , 'zuni'),
 ('zxx'  , 'zxx'  , null  , 'No linguistic content; Not applicable'  , 'pas de contenu linguistique; non applicable'),
 ('zza'  , 'zza'  , null  , 'Zaza; Dimili; Dimli; Kirdki; Kirmanjki; Zazaki'  , 'zaza; dimili; dimli; kirdki; kirmanjki; zazaki')
on conflict do nothing;
insert into base.parm (module, parm, type, v_int, v_text) values 
 ('wylib', 'host', 'text', null, 'localhost'),
 ('wylib', 'port', 'int', 54320, null)

on conflict do nothing;
select base.priv_grants();
