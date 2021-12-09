//Wyseman schema file parser; A wrapper around the TCL core parser
//Copyright WyattERP.org; See license in root of this package
// -----------------------------------------------------------------------------
//TODO:
//- Prior Ruby TODO's:
//- What if I define text for a nonexistent table or column?
//- An application can initialize its own database
//- Implement run-time libs in ruby classes (ruby/tk?)
//- Module versions vs/ object versions (see TODOs in bootstrap.sql)
//- Code/schema to commit schema versions
//- More TODOs in wmparse.tcl (implement text, defaults)
//- 

const Path = require('path')
const Child = require('child_process')
const Format = require('pg-format')
const Tcl = require('tcl').Tcl

module.exports = class {
  constructor(db) {
    this.db = db
    this.tcl = new Tcl()
    this.fileName = ''

    this.tcl.jsFunc("hand_object",	(...a) => this.pObject(...a))
    this.tcl.jsFunc("hand_priv",	(...a) => this.pPriv(...a))
    this.tcl.jsFunc("hand_query",	(...a) => this.pQuery(...a))
    this.tcl.jsFunc("hand_cnat",	(...a) => this.pCnat(...a))
    this.tcl.jsFunc("hand_pkey",	(...a) => this.pPkey(...a))

    this.tcl.source(Path.join(__dirname, 'wylib.tcl'))
    this.tcl.source(Path.join(__dirname, 'wmparse.tcl'))

    if (!this.db.one("select obj_nam from wm.objects where obj_typ = 'table' and obj_nam = 'wm.table_text'")) {
//console.log("Build runtime:")
      this.parse(Path.join(__dirname, 'run_time.wms'))
      this.db.x("select case when wm.check_drafts(true) then wm.check_deps() end;")	//Check versions/dependencies
      this.db.x("select wm.make(null, false, true);")		//And build it
      this.parse(Path.join(__dirname, 'run_time.wmt'))	//Read text descriptions
      this.parse(Path.join(__dirname, 'run_time.wmd'))	//Read display switches
    }
      this.db.x('delete from wm.objects where obj_ver <= 0;')	//Remove any failed working entries
  }		//Constructor
    
  parse(file) {
//console.log('file:', file, "ext:", Path.extname(file), 'res:', Path.resolve(file))
    this.fileName = Path.basename(file)
    if (Path.extname(file) == '.wmi') {
      let full = Path.resolve(file)
        , sql = Child.execFileSync(full).toString()
//console.log('sql:', sql)
      return sql
    }
    try {
      let res = this.tcl.$("wmparse::parse " + file)
    } catch(e) {
      console.error('Tcl parse error: ', e.message)
      return null
    }
    return ''
  }
  
  check(prune = true) {
    this.db.x(`select case when wm.check_drafts(${prune}) then wm.check_deps() end;`)	//Check versions/dependencies
  }
  
  pObject(...args) {
    let [name, obj, mod, deps, create, drop] = args
      , depList = "'{}'"
    if (deps)
      depList = `'{${deps.split(' ').map(s => Format.ident(s)).join(',')}}'`
    let sql = Format(`insert into wm.objects (obj_typ, obj_nam, deps, module, source, crt_sql, drp_sql) values (%L, %L, %s, %L, %L, %L, %L);`, obj, name, depList, mod, this.fileName, create, drop)
//console.log('sql:', sql)
    this.db.x(sql)
  }

  pPriv(...args) {
    let [name, obj, lev, group, give] = args
    let sql = Format('select wm.grant(%L, %L, %L, %s, %L);', obj, name, group, parseInt(lev), give)
    this.db.x(sql)
  }
  
  pQuery(...args) {
    let [name, sql] = args
    this.db.x(sql)
  }
  
  pCnat(...args) {
    let [name, obj, col, nat, ncol] = args
    let sql = Format(`update wm.objects set col_data = array_append(col_data,'nat,${[col,nat,ncol].join(',')}') where obj_typ = %L and obj_nam = %L and obj_ver = 0;`, obj, name)
    this.db.x(sql)
  }

  pPkey(...args) {
    let [name, obj, cols]  = args
    let sql = Format(`update wm.objects set col_data = array_prepend('pri,${cols.split(' ').join(',')}',col_data) where obj_typ = %L and obj_nam = %L and obj_ver = 0;`, obj, name)
    this.db.x(sql)
  }
  
  destroy() {
    this.tcl.cmdSync("wmparse::cleanup")
  }
  
}	//class