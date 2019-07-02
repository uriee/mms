//db connection configuration
const {db} = require('../DBConfig.js')
const {flatten} = require('lodash')
const {changeUserPassword} = require('./User.js')

const {employees} = require('../schemas/employees.js')
const {parts} = require('../schemas/parts.js')
const {serials} = require('../schemas/serials.js') 
const {serial_statuses} = require('../schemas/serial_statuses.js') 
const {part_status} = require('../schemas/part_status.js') 
const {actions} = require('../schemas/actions.js') 
const {act_resources} = require('../schemas/act_resources.js') 
const {positions} = require('../schemas/positions.js') 
const {work_report} = require('../schemas/work_report.js') 
const {process} = require('../schemas/process.js') 
const {locations} = require('../schemas/locations.js') 
const {kit} = require('../schemas/kit.js') 
const {bom} = require('../schemas/bom.js') 
const {iden} = require('../schemas/iden.js') 
const {identifier} = require('../schemas/identifier.js') 
const {proc_act} = require('../schemas/proc_act.js') 
const {serial_act} = require('../schemas/serial_act.js') 
const {preferences} = require('../schemas/preferences.js') 
const {departments} = require('../schemas/departments.js')
const {users} = require('../schemas/users.js')
const {profiles} = require('../schemas/profiles.js')
const {equipments} = require('../schemas/equipments.js')
const {resource_groups} = require('../schemas/resource_groups.js')
const {resources} = require('../schemas/resources.js')
const {availability_profiles} = require('../schemas/availability_profiles.js')
const {availabilities} = require('../schemas/availabilities.js') 
const {resource_timeoff} = require('../schemas/resource_timeoff.js') 
const {employee_timeoff} = require('../schemas/employee_timeoff.js') 
const {malfunctions} = require('../schemas/malfunctions.js') 
const {malfunction_types} = require('../schemas/malfunction_types.js') 
const {repairs} = require('../schemas/repairs.js') 
const {repair_types} = require('../schemas/repair_types.js') 
const {mnt_plans} = require('../schemas/mnt_plans.js') 
const {mnt_plan_items} = require('../schemas/mnt_plan_items.js') 
const {fault} = require('../schemas/fault.js') 
const {fault_type} = require('../schemas/fault_type.js')
const {fault_status} = require('../schemas/fault_status.js')
const {tags} = require('../schemas/tags.js') 

const schemas = {
	employees : employees,
	parts : parts,
	departments : departments,
	users : users,
	profiles : profiles,
	equipments: equipments,
	resource_groups : resource_groups,
	resources : resources,	
	availability_profiles : availability_profiles,
	availabilities : availabilities,
	resource_timeoff : resource_timeoff,	
	employee_timeoff : employee_timeoff,		
	malfunctions : malfunctions,
	malfunction_types : malfunction_types,
	repairs : repairs,
	repair_types : repair_types,
	mnt_plans : mnt_plans,
	mnt_plan_items : mnt_plan_items,
	serials : serials, 
	serial_statuses : serial_statuses,
	part_status : part_status,	
	act_resources: act_resources, 	
	actions : actions,
	positions : positions,	
	process : process,
	proc_act: proc_act,
	serial_act: serial_act,	
	kit : kit,
	bom : bom,
	iden : iden,
	locations : locations,
	work_report : work_report,
	identifier : identifier,
	preferences : preferences,
	fault_status,
	fault_type,
	fault : fault
}

const fillTemplate = function(templateString, templateVars){
	
    return new Function("return `"+templateString +"`;").call(templateVars);
}

//fetches Employee data from db 
const fetchByName = (request, response, entity) => {
	const param = request.body

  	return db.one(schemas[entity].sql.single
				, [param.name,param.lang]
				).then((emp) => response.status(200).json({ emp }))
 				 .catch((err) => {
      				response.status(401).json(user)
      				console.error(err)
    			})
}

const fetchTags = async(request, response) =>{
	const sql = `select id::Integer,name,row_type,tags from mymes.tagable
					where exists
					(select * from (select unnest(mymes.tagable.tags)) x(tag) where x.tag like '%${request.query.tags}%');`

	try{
		const ret =  await db.any(sql).then(x=>x)	
		response.status(200).json({main:ret})
	}catch(e){
		console.error(e)
	}
}

const fetchResources = async(request, response) =>{
	const DBToTree = (resources,barnches) => {
	    let raw = resources //JSON.parse(string)
	    let raw2 = [...raw]
	    rg = raw.filter(x=> x.resource_ids)   
		rg.map(ri => {
			//ri.children = raw2.filter(r=> ri.resource_ids.includes(r.id))
			ri.children = ri.resource_ids.map(r => raw2.filter(res=> res.id === r)[0])
			raw = raw.filter(r=> !ri.resource_ids.includes(r.id))
			return ri
		})

	    return raw
	} 

	const sql = `select r.id,r.name as name,ap.name as ap_name,r.resource_ids,r.dragable , r.row_type, e.sname || ' ' || e.fname as sname ,pos.manager as manager ,pos.name as position
				from mymes.resources as r
				left join mymes.employees_t e on e.emp_id = r.id and e.lang_id = 1
				left join mymes.employees emp on emp.id = r.id 
				left join mymes.positions pos on pos.id = emp.position_id 
				, mymes.availability_profiles as ap
				where ap.id = r.availability_profile_id
				and r.active is true;`
	const sql2 = `select r.id,r.name as name,ap.name as ap_name,r.resource_ids,dragable , r.row_type, des.description as sname
				from mymes.resources as r ,mymes.availability_profiles as ap, mymes.resource_desc as des
				where ap.id = r.availability_profile_id
				and des.resource_id = r.id
				and des.lang_id = 1
				and r.active is true;`				
	try{
		const ret =  await db.any(sql).then(x=>x.map(x=> ({... x, name :  x.sname ? `${x.name}: ${x.sname}` : x.name})))	
		branches = ret.filter(x=>x.resource_ids)
		tree = DBToTree(ret)
		dbroot = branches.filter(x=>ret[0].id)
		response.status(200).json({main:DBToTree(ret)})
	}catch(e){
		console.error(e)
	}
}


const fetchRoutes = async(request, response) =>{
	const sql = `select routes from routes`

	try{
		const ret =  await db.any(sql).then(x=>x)	
		response.status(200).json({main:ret})
	}catch(e){
		console.error(e)
	}
}

const fetchWorkPaths = async(request, response) =>{
	const {user} = request.query
	const sql = `select r.name as resourcename,serial.name as serialname,act.name as actname ,seract.balance , seract.quant
	from mymes.actions as act,
	mymes.serials as serial , mymes.serial_act as seract
	join mymes.act_resources as ar on (ar.act_id = seract.id and type = 3)
	join mymes.resources as r on r.id = ar.resource_id 
	where serial.id = seract.serial_id and act.id = seract.act_id 
	and serial.active=true and act.active=true
	and r.id in (select resource from user_parent_resources('${user}'))
	and seract.balance > 0 
	order by serial.name,seract.pos;`

	try{
		const ret =  await db.any(sql).then(x=>x)	
		response.status(200).json({main:ret})
	}catch(e){
		console.error(e)
	}
}

const fetchWR = async(request, response) =>{
	const {serialname,actname} = request.query
	const WRsql = `select sig_date, wr.quant, users.username , identifier.name as serial , resources.name as resourcename , wr.row_type
	from mymes.resources , mymes.actions , mymes.serials ,users,
	mymes.work_report wr left join mymes.identifier_links il on il.parent_id = wr.id 
	left join mymes.identifier on identifier.id = il.identifier_id
	where wr.resource_id = resources.id
	and wr.act_id = actions.id
	and wr.serial_id = serials.id
	and users.id = wr.sig_user
	and serials.name = '${serialname}'
	and actions.name = '${actname}'
	UNION 
	select sig_date, wr.quant, users.username , identifier.name as serial , resources.name as resourcename, wr.row_type
	from mymes.resources , mymes.serials ,users,
	mymes.fault wr left join mymes.identifier_links il on il.parent_id = wr.id 
	left join mymes.identifier on identifier.id = il.identifier_id
	left join mymes.actions  on actions.id = wr.act_id	
	where wr.resource_id = resources.id
	and wr.serial_id = serials.id
	and users.id = wr.user_id
	and serials.name = '${serialname}'
	and actions.name = '${actname}'
	order by sig_date desc;`

	const locsql = `select loc.location
	from mymes.locations loc left join mymes.actions act on loc.act_id = act.id, mymes.serials ser
	where ser.name = '${serialname}'
	and (act.name  = '${actname}' or loc.act_id is null)
	and loc.part_id = ser.part_id;`

	const typesql = `select name from mymes.fault_type where active = true;`

	try{
		const WR =  await db.any(WRsql).then(x=>x)	
		const loc = await db.any(locsql).then(x=>x)
		const type = await db.any(typesql).then(x=>x)
		response.status(200).json({main:{WR,type,loc}})
	}catch(e){
		console.error(e)
	}
}

const fetchNotifications = async(request, response) =>{
	const {user} = request.query
	const sql = `select id ,title,type ,status,extra, schema
				 from mymes.notifications 
				 where read is not true
				 and username = '${user}';`
	try{
		const ret =  await db.any(sql).then(x=>x)	
		response.status(200).json(ret)
	}catch(e){
		console.error(e)
		response.status(200).json(ret)
	}
}
/*****
/* getField: Enables the schema fields field property to be a Function or a String
*****/
const getField = (field,flag) => typeof field === 'function' ? field(flag || 0) : field

/*
Populate the response data from DB with the requested data of a certain entity
*/
const fetch = async (request, response, entity) => {
	const {lang/*pageSize,currentPage*/,zoom,name,parent,user,flag,parentSchema} = request.query
	const tables = schemas[entity].schema.tables
	const limit =  schemas[entity].limit || 50
	const filters = flatten(	
							Object.keys(tables)
							.map(table=> tables[table].fields
								.map(x => ({field : `${x.table || table}.${x.filterField || getField(x.field) || x.key}`,value : request.query[x.filterValue || getField(x.field) || x.key]}))
								)
							).filter(field => field.value)
	
	try {
		const filterSql = filters.reduce((string, filter)=> string+` and UPPER(${getField(filter.field)}::text) like '%${filter.value.toString().toUpperCase().replace(/\$/g,"%")}%'` , '')
		const zoomSql = filters.reduce((string, filter)=> string+` and ${getField(filter.field)} = '${filter.value}'`, '')
		//const pageSql = pageSize ? ` offset ${(currentPage - 1) * pageSize} ` : ''
		const sql = `${schemas[entity].sql.all} ${(zoom === '1' ? zoomSql  : filterSql)} ${(schemas[entity].sql.final || '')} limit ${limit};`
		console.log("fetch sql:",sql,request.query)
		const main = await db.any(sql,[lang || '1',name || '',parent || '0' ,user || '',flag || 0,parentSchema || entity]).then(x=>x)
		const chooserId = Object.keys(schemas[entity].sql.choosers)
		const chooserQueries = Object.values(schemas[entity].sql.choosers)	
	    const chooserResaults = await Promise.all(chooserQueries.map(choose => db.any(choose,[request.query.lang , request.query.user])))
	    const choosers = {}
	    chooserId.map((ch,i) => { choosers[ch] = chooserResaults[i] }) 
	    const ret = {
	    	main : main,
	    	choosers: choosers
	    	}
	    response.status(200).json(ret)
	    return ret
		} catch(err) {
			console.error(err)
			response.status(406).json(err)
		}
}

const runQuery = async (query) => {
	try{
		return await db.any(query).then(x => x)
	} catch(err) {
		console.error(err)
		throw new Error(err)
	}
}

const getFkeys = async (fkeys,params) => {

	const keys = {}
	try{
		const fkeysNames = Object.keys(fkeys)
		const keyValues = await Promise.all(fkeysNames.map(async (key) => {
			const query = fkeys[key]
	
			/*const parameter = Array.isArray(params[query.value]) ? params[query.value].toString() :
								[params[query.value]]*/
			const parameters = Array.isArray(query.value) ? 
				query.value.map(value =>  Array.isArray(params[value]) ? params[value].toString() :	params[value]) :
				Array.isArray(params[query.value]) ? params[query.value].toString() :[params[query.value]]
			
				console.log('********************************************',params[query.value],query)
			var res = query.hasOwnProperty('query') ?
						await db.any(query.query, parameters).then(x => Array.isArray(x)? x.map(x=> x.id) : x.id) :
					    params[query.value]
	
			return res
		})).then(x => x)

		fkeysNames.map((name,i) => {
			keys[name] = keyValues[i]
		})

	} catch(err) {
		err = 'ERROR in fkeys() :' + err
		console.error(err)
		throw new error(err)
		}
	return keys;
}

const insertIdentifier = async (req, res, user)  => {
	const body = req.body
	console.log("BBBOOODDDY:",body)
	sql = `select part_id from  mymes.identifier i , mymes.work_report w where i.name = ${body.identifier}  and w.id = i.parent; `
	const part_id  = await db.one(sql)
	var xxx
	if (part_id) { 
		sql = `select id from identifier_links where `
	}
	const ret = await user.authenticate(req,res,() => insert(req,res,getEntity(req.body.entity)))
	res.status(200).json({inserted:'true'})
}

const InsertToTables = async (params,schema) => {
	const keys = await getFkeys(schema.fkeys,params)
	const tables = Object.keys(schema.tables)
	const chain = schema.chain
	const isPublic = !!schema.public
	const id  = schema.pkey
	var new_id = 0    
	/*Check to see if all required fields has value*/

	const required = tables.reduce(
		(ret,table) => ret + schema.tables[table].fields.filter(field => field.required).reduce(
			(o,field)=>{
			return o + (params[getField(field.field,params['flag'])] ? 1 : 0)} , 0) 	,0
		) || 1
	if(!required) throw new Error('There are some required fields with no value!');

	const maintable = schema.tables[tables[0]]
	const insertFields = maintable.fields.filter(x => x.field && (x.value || keys[x.fkey]>'' || params[x.variable]))
	let fields = insertFields.map(x => getField(x.field,params['flag']))
	console.log('Inser5t params',params,insertFields,fields)	
	let values = insertFields
				.map(x => {

					params[x.variable] = x.func ? x.func(params[x.variable]) : params[x.variable] /* format  the value with the formating function from schema*/
					return x.hasOwnProperty('value') ? 
					`'${x.value}'` :
					x.hasOwnProperty('fkey') ?
					(Array.isArray(keys[x.fkey]) && (keys[x.fkey].length > 1 || x.field ===  'resource_ids') ? `'{${keys[x.fkey]}}'` : keys[x.fkey]) :
					`'${params[x.variable]}'${x.conv ? x.conv: ''}`
				})
	let mainTableSql = `insert into ${!isPublic ? 'mymes.' : ''}${tables[0]}(${fields}) values(${values}) returning id;`
	console.log("insert query maintable",mainTableSql)
	new_id = keys[id] = '$1'
	tables.shift()

	var sqls  = tables.map( tablename => {		
		const table = schema.tables[tablename]
		const fields = table.fields.filter(x => x.field).map(x => getField(x.field,params['flag']))
		if (table.hasOwnProperty('fill')) {
			let field = table.fill.field
			return table.fill.values.map(val => {	
				let values = table.fields.filter(x => x.field )
										 .map(x =>  getField(x.field,params['flag']) === field ?
										 	 val : x.hasOwnProperty('fkey') ?
										 	 keys[x.fkey] : `'${params[x.variable+(val === params['lang_id'] || !params[x.variable] ? '' : '_t')]}'`
										 )
				let sql = `insert into ${!isPublic ? 'mymes.' : ''}${tablename}(${fields}) values(${values}) returning *;`
				//sqls.push(sql)
				return sql
			})

		}
		else {
			let values = table.fields.filter(x => x.field).map(x =>  x.hasOwnProperty('fkey') ? keys[x.fkey] : `'${params[x.variable]}'`)
			let checkValues = table.fields.filter(x => x.field).map(x =>  x.hasOwnProperty('fkey') ? keys[x.fkey] : params[x.variable])
			let sql = `insert into ${!isPublic ? 'mymes.' : ''}${tablename}(${fields}) values(${values}) returning *;`	
			return checkValues.every(x=>x) ? sql : null
		}
	}).filter(x=>x).flat()

	console.log("main : ",mainTableSql," sqls : ", sqls)	
	
	var new_id = await db.tx( async t => {
		new_key = await t.oneOrNone(mainTableSql)
		const c = await Promise.all(sqls.map(sql => t.any(sql,[new_key.id])))
		return new_key
	}).catch(error => {
			console.error(error)
			throw new Error("Error in inset to tables : ",error)
	});

	const ChainInsert = chain && chain.map(async (chainSchema) => await insert({body : {...params, parent : new_id.id}}, null , chainSchema , mute = true))
	
	return new_id.id
}

const insert = async (req, res, entity , mute = false) => {
	let params = {}
	Object.keys(req.body).forEach(x=> params[x] = typeof req.body[x] === 'string' ?  req.body[x].replace(/'/g,"") : req.body[x]) //Protection againt sql injection
	Object.keys(params).forEach(x => {
		params[x] = Array.isArray(params[x]) ? (params[x].length === 1 ? `{${params[x][0]}}` : `{${params[x]}}`) : params[x]
	})
	const schema = schemas[entity].schema
	const pre_insert = schemas[entity].pre_insert	

	try{						
		const parameters = pre_insert && pre_insert.parameters.map(x => params[x])
		const pre = pre_insert && parameters && await db.func(pre_insert.function, parameters)
											    .then(data => {
											        console.log(`Return from function - ${pre_insert.function} : ${data}`); 
											    })									    
		}catch(err) {
			console.error("pre_insert:",err)
			if (!mute) res.status(406).json({error: 'pre_insert : '+err})
			throw new Error("PreInsert fault")
		}

	try{											    
		const new_id = await InsertToTables(params,schema)
		if (!mute) res.status(201).json(new_id)
						// Execeute the Post-Insert Statement from the schema
		const post_insert = schemas[entity].post_insert						
		params.id = new_id
		const parameters = post_insert && post_insert.parameters.map(x => params[x])
		const post = post_insert && parameters && db.func(post_insert.function, parameters)
											    .then(data => {
											        console.log(`Return from function - ${post_insert.function} : ${data}`); 
											    })
											    .catch(error => {
											        console.error('ERROR:', error); 
											        throw new Error("PostInsert fault")
											    });
		return new_id											    
	} catch(err) {
		console.error("error in Insert:",err)
		if (!mute) res.status(406).json({error: err})
		throw new Error("Insert fault :" + err.toString())
	}
}

const update = async (req, res, entity) => {
	let params = {}
	Object.keys(req.body).forEach(x=> params[x] = typeof req.body[x] === 'string' ?  req.body[x].replace(/'/g,"") : req.body[x]) //Protection againt sql injection
	const schema = schemas[entity].schema
	const isPublic = !!schema.public
	const tables= schema.tables
	const tableNames  = Object.keys(tables)
	let  fkSchema = {}
	const fkeysNames = Object.keys(schema.fkeys).filter(key => schema.fkeys[key].value in params)
	fkeysNames.map((key) => {
			fkSchema[key] = schema.fkeys[key]
		})
	try {
		var fkeys = await getFkeys(fkSchema, params)
		Object.keys(fkeys).forEach(key => {
			value = fkeys[key]
			fkeys[key] =  key !== 'resource_ids' && Array.isArray(value) && value.length === 1 ? value[0] : value
			})		

		var allParams = Object.assign({},params,fkeys)
		Object.keys(allParams).forEach(key => {
			value = allParams[key]
			allParams[key] =  Array.isArray(value) ? `{${value}}` : value
			})

		const ret = Promise.all(tableNames.filter(tn => tables[tn].fields.some(field => allParams.hasOwnProperty(getField(field.field,params['flag']))))
				  .map(tn =>{
				  	const table = schema.tables[tn]
				  	const sets = table.fields.filter(field => {
							const fname = getField(field.field,params['flag'])
									return allParams.hasOwnProperty(fname) && (allParams[fname] || allParams[fname] === false)
										})
										.map(field => {
											const fname = getField(field.field,params['flag'])
											return {set : fname, to: allParams[fname], conv: field.conv }
										})
				  	const wheres = table.fields.filter(field => params.hasOwnProperty(field.key))
				  							   .map(field => ({where : getField(field.field,params['flag']) > '' ? getField(field.field,params['flag']) : field.key , equals: params[field.key]}))
				  	const sqlSet = sets.reduce((old,set) => old + `"${set.set}" = '${set.to}'${set.conv ? set.conv: ''},`,'').slice(0,-1)
				  	const sqlWhere = wheres.reduce((old,where) => old + `${where.where} = '${where.equals}' and `,'').slice(0,-5)
				  	const sql = `update ${!isPublic ? 'mymes.' : ''}${tn} set ${sqlSet} where ${sqlWhere} returning 1;`
				  	console.log("update sql:",sql)
				  	const ret  = runQuery(sql)
				  	return ret
		}))

						// Execeute the Post-Insert Statement from the schema
		const post_update = schemas[entity].post_update
		const parameters = post_update && post_update.parameters && post_update.parameters.map(x => params[x])
		const post = post_update && params.password && entity === 'users' ? changeUserPassword(params.name,params.password) : 
			post_update && parameters && db.func(post_update.function, parameters)
											    .then(data => {
											        console.log(`Return from function - ${post_update.function} : ${data}`); 
											    })
											    .catch(error => {
											        console.error('ERROR in post_update:', error); 
											    });

		res.status(202).json(ret)
		return
	} catch(err) {
		console.log(err)
		res.status(406).json({error:err})
	}
}


const remove = async (req, res, entity) => {
let params = {}
	Object.keys(req.body).forEach(x=> params[x] = typeof req.body[x] === 'string' ?  req.body[x].replace(/'/g,"") : req.body[x]) //Protection againt sql injection
	const schema = schemas[entity].schema
	const isPublic = !!schema.public	
	let table = Object.keys(schema.tables)[0] /*all  translation tables are now deleted by DB constarint */
	const key = schema.tables[table].fields.filter(x =>  x.key)[0].key
	const {pre_delete, post_delete} = schemas[entity]

	/* cascading delete is preformed by DB foreign keys constraints*/
	const sql = `delete from ${!isPublic ? 'mymes.' : ''}${table} where ${key} = `
	const finalSqls	 = params.keys && sql && params.keys.reduce((o,x) => {
															//o.push(sql + x + ' returning 1;')
															return [...o , `${sql}${x} returning 1; `]
															}
														,[])

	try {
	const pre = pre_delete && pre_delete.function && params.keys && await db.func(pre_delete.function, [params.keys,[params.parent,params.parent_schema]])
											    .then(data => {
											        console.log(`Return from function - ${pre_delete.function} : ${data}`); 
											    })	
	//console.log("~~~----~~~----~~~:",sql,finalSqls,pre)		
   	const ret  = await Promise.all(finalSqls.map(sql => runQuery(sql)))
								
	const post = post_delete && params.keys && await db.func(post_delete.function, [params.keys])
											    .then(data => {
											        console.log(`Return from function - ${post_delete.function} : ${data[0]}`); 
											    })	
	res.status(205).json(ret)
		return 
	} catch(err) {
		console.error("delete:",err)
		res.status(406).json({error:'delete : '+err})
	}
}

const func = async (req, res, entity) => {
	let { funcName, keys }  = req.body
	const schema = schemas[entity].schema
	try {
   	const ret  = await Promise.all(keys.map(key => db.func(`${funcName}_${entity}`, key)))
		res.status(230).json(ret)
		return 
	} catch(err) {
		console.error(err)
		res.status(406).json({error:err})
	}

}

const runFunc = async (req, res, funcname) => {
	let { params } = req.body
	try {
   	const ret  = await db.func(funcName, params)
		res.status(230).json(ret)
		return 
	} catch(err) {
		console.error(err)
		res.status(406).json({error:err})
	}
}

/***
* @param : body => {table => table name,data => data rows to insert}
****/
const batchInsert = async (req,res,entity) => {
	try {
		const ret = await Promise.all(await batchInsert_(req.body.data,entity))
		res.status(200).json({inserted:ret})
	}catch(err){
		console.error("Error in batchInsert",err)
		res.status(406).json({error:err})
	}	
}

const batchInsert_ = async (data,entity) => {
	const schema = schemas[entity].schema
	var ret = null
	try {
		ret = await data.map(async row => {
			let params = {}
			Object.keys(row).forEach(x=> params[x] = typeof row[x] === 'string' ?  row[x].replace(/'/g,"") : row[x]) //Protection againt sql injection
			Object.keys(params).forEach(x => {
				params[x] = Array.isArray(params[x]) ? (params[x].length === 1 ? `{${params[x][0]}}` : `{${params[x]}}`) : params[x]
			})
			return await InsertToTables(params,schema)
		})
		return ret
	}catch(err){
		console.error("Error in batchInsert_",ret,err)
		return 0
	}
}

/***
* @param : body => {table => table name,data => fields to update (must include id field)}
****/
const batchUpdate = async (body,res) => {
	const sqls = body.data.map(r => (
		{set : Object.keys(r)
			.filter(x=> x != 'id')
			.map(x=> ({set : x, to:r[x]}))
			.reduce((o,e) => o + `${e.set} = ${Array.isArray(e.to) ? 'array['+e.to+']' : e.to},`,'')
			.slice(0,-1),
		 id: r.id}
		 )
	)
	const table = body.table
	const sql = sqls.reduce((o,r) => [...o,`UPDATE mymes.${table} set ${r.set} where id=${r.id};`] ,[])
	db.tx(t => {
        // this.ctx = transaction config + state context;
        return t.batch(sql.map(r => t.none(r)));
    })
    .then(data => {
        res.status(230).json(data)
		return 
    })
    .catch(error => {
        console.error('ERROR:', error);
        res.status(406).json({error:err})
    });
    
}

/***
* get notification id and username 
* marks the notification as read if username = notification.user
****/
const markNotificationAsRead = async (req,res) => {
	var data = {}
	try {
		data = req.body
	}catch(e){
		res.status(406).json({})
	}
	const {id,user} = data

	let sql = `update mymes.notifications
				set read = true
				where id = ${id} and username = '${user}'`

	try{
		res.status(200).json(await db.one(sql))
	}catch(e){
		console.error("error in markNotificationAsRead : ",e)
		res.status(200).json({error : e})
	}
}

const changeUserLang = async (req,res) => {
	var data = {}
	try {
		data = req.body
	}catch(e){
		res.status(406).json({})
	}
	const {locale,user} = data
	
	let sql = `update users
				set locale = '${locale}'
				where username = '${user}'`
	try{
		res.status(200).json(await db.one(sql))
	}catch(e){
		console.error("error in changeUserLang : ",e)
		res.status(200).json({error : e})
	}
}

/***
* Get the approval of the erp acceptance of the work reports
* And set approve propety of the reports to true
****/
const approveWorkReports = async (req,res) => {
	var data = {}

	try {
		data = JSON.parse(req.body.data)
	}catch(e){
		res.status(406).json({})
	}
	const ids = data[0].REPORTS.map(x => x.MESID);
	let sql = `update mymes.work_report
				set approved = true
				where id = any (ARRAY[${ids}]) returning 1`
	try{
		lines = await db.any(sql)
		res.status(200).json(lines)
	}catch(e){
		console.error("error in approveWorkReport : ",e)
		res.status(406).json({error : e})
	}
}

/***
* Exports the Work Reports that are not yet Sent to the Erp server
* And set Sent propety of the reports to true
****/
const exportWorkReport = async (req,res) => {
	const option = {year:'2-digit', month: '2-digit', day: "2-digit" }
	const date = new Date().toLocaleDateString("he",option).replace(/-/g,'/')
	let sql = `select w.id as id ,extserial as wo,erpact as act,w.quant
				from mymes.work_report as w,mymes.serials as s ,mymes.actions as a
				where a.id = w.act_id
				and s.id = w.serial_id
				and extserial is not null
				and erpact is not null
				and (sent is null or sent is false);`
	try{
		lines = await db.any(sql)
		const data = {
			date : date,
			data: lines
		}

		if (lines.length) {
			res.status(200).json(data)
		
			const ids = lines.map(x=>x.id).toString()
			sql = `update mymes.work_report
				set sent = true
				where id = any (ARRAY[${ids}]) returning 1`
			db.any(sql).catch(e=> console.error(e))	
		}
		else {
			res.status(405).json({massage : 'no data found'})
		}
	}catch(e){
		console.error("error in exportWorkReport : ",e)
		res.status(406).json({error : e})
	}
}

const importSerial = (req,res) => {
	const part_schema = schemas['parts'].schema
	const serial_schema = schemas['serials'].schema	
 	var data = {}
  	try {
    data = JSON.parse(req.body.data)
 	 }catch(e){
    res.status(406).json({})
	  }
 	data.map(async (serial) => {
 		var sql = `select id,part_id from mymes.serials where name = '${serial.SERIAL.SERIALNAME}';`
 		var serial_id,parent_id,part_id
 		var process = {}
 		try{
	    	const xxx = await db.one(sql)  
	    	serial_id = xxx.id
	    	part_id = xxx.part_id

	    }catch(e){ /*serial_id can be null*/ }	
 		try{
	 		process = serial.SERIAL.PROCNAME ?  await db.one(`select id,name from mymes.process where erpproc = '${serial.SERIAL.PROCNAME}';`)  : process
	    }catch(e){ /*prosecc_id can be null*/ }	 
 		try{
	 	 	parent_id = serial.SERIAL.PARENT ? await db.one(`select id from mymes.serials where name = '${serial.SERIAL.PARENT}';`): null 
	    }catch(e){ /*parent_serial_id can be null*/ }
 		try{
 			sql = `select id from mymes.part where name = '${serial.PART.PARTNAME}' and revision = '${serial.PART.REVISION}';`
	 	 	part_id = !part_id && serial.PART.PARTNAME ? (await db.one(sql)).id : part_id 
	    }catch(e){ /*parent_serial_id can be null*/ }	    

	    const partAllreadyExists = part_id > 0 


	    if(serial_id) {
	    	console.warn('all ready exists')
			serial.KIT = serial.KIT && serial.KIT.map(x => ({ lang_id: 1,lot: x.LOT, partname: x.PARTNAME, quant: x.QUANT,  parent : serial_id}))
			const kit = serial.KIT && serial.KIT.length ? await Promise.all( await batchInsert_(serial.KIT,'kit')) : []			   	
	    }
	    else{
	    	try {
	    		if(!partAllreadyExists) {
		    		try {
    			
				    	const partParams = {
				    		name : serial.PART.PARTNAME,
							active: true,
							part_status : 'Active',
				    		revision: serial.PART.REVISION,
				    		doc_revision: serial.PART.DOCREV,
				    		row_type : 'part',
				    		description : serial.PART.PARTDES,
				    		lang_id :  1,
				    	}
						part_id = await InsertToTables(partParams,part_schema)
					}catch(e){
						console.warn('part allready exists',e)
					}
				}

				let procName = ''
				if(!process.id) {
					serial.SERACT = await Promise.all(serial.SERACT && serial.SERACT.map(async (x) => {
						const sql = `select id,name from mymes.actions where erpact = '${x.ACTNAME}';`
						const act = await db.one(sql)
						return {act_name: act.name, pos : x.POS}
					})).then(actions => actions,e => null)

					if (serial.SERACT) {
						const processParams = {
							name : serial.SERIAL.PROCNAME,
							erpproc : serial.SERIAL.PROCNAME,
							active : true,
							description :  `Loadded with the WorkOrder: ${serial.SERIAL.SERIALNAME}`,
							lang_id: 1
						}						
						const proc_id = await insert({body :processParams},res,'process',mute = true)					
						serial.SERACT = serial.SERACT.map(x=> ({...x , parent: proc_id}))				
						//const ret = proc_id ? await Promise.all( await batchInsert_(serial.SERACT,'proc_act')) : []
						const ret = proc_id ? await Promise.all(serial.SERACT.map(act => insert({body:act},res,'proc_act',mute = true))) : []
						procName = serial.SERIAL.PROCNAME
					}
				}

	    		const end_date = serial.SERIAL.PEDATE ? {end_date : serial.SERIAL.PEDATE} : {}			
		    	const serialParams = {
		    		name : serial.SERIAL.SERIALNAME,
		    		quant : serial.SERIAL.SERIALQUANT,
		    		active: true,
		    		partname : serial.PART.PARTNAME+':'+serial.PART.REVISION,
		    		status: 'Released',
		    		procname : process.id ? process.name : procName,
		    		part_serial_name: parent_id ? serial.SERIAL.PARENT : '',
		    		row_type : 'serial',
		    		end_date : null, 
		    		extserial: serial.SERIAL.SERIALNAME,
		    		description : serial.SERIAL.SERIALDES,
		    		lang_id :  1,
				    ...end_date		    		
		    	}
				serial_id = await insert({body :serialParams},res,'serials',mute = true)	

				if(!partAllreadyExists){
					serial.BOM = serial.BOM && serial.BOM.map(x => ({ lang_id: 1, partname : x.PARTNAME,	coef : x.COEF, parent : part_id}))
					serial.LOC = serial.LOC && serial.LOC.map(x => ({ lang_id: 1, location : x.LOCATION, x :x.X, y: x.Y, z:x.Z,partname: x.PARTNAME,quant: x.QUANT, act_name :x.ACTNAME, parent : part_id}))
					const bom = serial.BOM && serial.BOM.length ? await Promise.all( await batchInsert_(serial.BOM,'bom')) : []
					const loc = serial.LOC && serial.LOC.length ? await Promise.all( await batchInsert_(serial.LOC,'locations')) : []		
				}
				serial.KIT = serial.KIT && serial.KIT.map(x => ({ lang_id: 1,lot: x.LOT, partname: x.PARTNAME, quant: x.QUANT,  parent : serial_id}))
				const kit = serial.KIT && serial.KIT.length ? await Promise.all( await batchInsert_(serial.KIT,'kit')) : []
			}catch(e){
				console.error('error in importSerial : ',e)
			}	
		}

    })	
  res.status(201).json({})
}

module.exports = {
  fetch, fetchRoutes, fetchResources, fetchTags,fetchByName, update, batchUpdate, batchInsert, insert, remove,
  runQuery ,runFunc, func, fetchNotifications, importSerial,  exportWorkReport ,approveWorkReports, markNotificationAsRead ,
  changeUserLang ,fetchWorkPaths , fetchWR
}