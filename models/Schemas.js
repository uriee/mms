//db connection configuration
const {db} = require('../DBConfig.js')
const {flatten} = require('lodash')

const {employees} = require('../schemas/employees.js')
const {parts} = require('../schemas/parts.js')
const {serials} = require('../schemas/serials.js') 
const {serial_statuses} = require('../schemas/serial_statuses.js') 
const {part_status} = require('../schemas/part_status.js') 
const {actions} = require('../schemas/actions.js') 
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
	actions : actions,
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
	const sql = `select * from mymes.tagable
					where exists
					(select * from (select unnest(mymes.tagable.tags)) x(tag) where x.tag like '%${request.query.tags}%');`

	try{
		const ret =  await db.any(sql).then(x=>x)	
		response.status(200).json({main:ret})
	}catch(e){
		console.log(e)
	}
}

const fetchRoutes = async(request, response) =>{
	const sql = `select routes from routes`

	try{
		const ret =  await db.any(sql).then(x=>x)	
		response.status(200).json({main:ret})
	}catch(e){
		console.log(e)
	}
}

const fetchNotifications = async(request, response) =>{
	const sql = `select id as identifier,name as id,title,type 
				 from mymes.notifications 
				 where read is not true;`
	try{
		const ret =  await db.any(sql).then(x=>x)	
		response.status(200).json(ret)
	}catch(e){
		console.log(e)
	}
}
/*
Populate the response data from DB with the requested data of a certain entity
*/
const fetch = async (request, response, entity) => {
	const {lang/*pageSize,currentPage*/,zoom,name,parent,user} = request.query
	const tables = schemas[entity].schema.tables	
	const filters = flatten(	
							Object.keys(tables)
							.map(table=> tables[table].fields
								.map(x => ({field : `${x.table || table}.${x.filterField || x.field || x.key}`,value : request.query[x.filterValue || x.field || x.key]}))
								)
							).filter(field => field.value)
	
	try {
		const filterSql = filters.reduce((string, filter)=> string+` and UPPER(${filter.field}::text) like '%${filter.value.toString().toUpperCase()}%'` , '')
		const zoomSql = filters.reduce((string, filter)=> string+` and ${filter.field} = '${filter.value}'`, '')
		//const pageSql = pageSize ? ` offset ${(currentPage - 1) * pageSize} ` : ''
		const sql = `${schemas[entity].sql.all} ${(zoom === '1' ? zoomSql  : filterSql)} ${(schemas[entity].sql.final || '')} limit 100;`
		console.log("fetch sql:",sql,request.query)
		const main = await db.any(sql,[lang || '1',name || '',parent || '0' ,user || '']).then(x=>x)
		const type = !main[0] ? 200 : 200
		const chooserId = Object.keys(schemas[entity].sql.choosers)
		const chooserQueries = Object.values(schemas[entity].sql.choosers)	
	    const chooserResaults = await Promise.all(chooserQueries.map(choose => db.any(choose,[request.query.lang])))
	    const choosers = {}
	    chooserId.map((ch,i) => { choosers[ch] = chooserResaults[i] }) 
	    const ret = {
	    	main : main,
	    	choosers: choosers
	    	}
	    response.status(type).json(ret)
	    return ret
		} catch(err) {
			response.status(403).json(err)
			console.log("testetststetetsts s:   ",err)
		}
}

const runQuery = async (query) => {
	try{
		return await db.any(query).then(x => x)
	} catch(err) {
		console.log(err)
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

			console.log("**********",query.query, parameters)
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
		console.log(err)
		throw new error(err)
		}
	return keys;
}



const insert = async (req, res, entity) => {
let params = {}
	Object.keys(req.body).forEach(x=> params[x] = typeof req.body[x] === 'string' ?  req.body[x].replace(/'/g,"") : req.body[x]) //Protection againt sql injection
	console.log("___---__-:",params)
	Object.keys(params).forEach(x => {
		params[x] = Array.isArray(params[x]) ? (params[x].length === 1 ? `{${params[x][0]}}` : `{${params[x]}}`) : params[x]
	})
	const schema = schemas[entity].schema
	const isPublic = !!schemas[entity].public
	const id  = schema.pkey
	var new_id = 0
	const pre_insert = schemas[entity].pre_insert	

	try{						
		const parameters = pre_insert && pre_insert.parameters.map(x => params[x])
		const pre = pre_insert && parameters && await db.func(pre_insert.function, parameters)
											    .then(data => {
											        console.log(`Return from function - ${pre_insert.function} : ${data}`); 
											    })									    
		}catch(err) {
			console.log("pre_insert:",err)
			res.status(406).json({error: 'pre_insert : '+err})
			return 0
		}
		
	try{
		const keys = await getFkeys(schema.fkeys,params)
	    const tables = Object.keys(schema.tables)
	console.log('===========3:',keys,params)    

		/*Check to see if all required fields has value*/
		const required = tables.reduce(
			(ret,table) => ret + schema.tables[table].fields.filter(field => field.required).reduce(
				(o,field)=>{
				console.log("_-_:",o,field,params[field.field]);
				return o + (params[field.field] ? 1 : 0)} , 0) 	,0
			) || 1
		if(!required) throw new Error('There are some required fields with no value!');
		
		const maintable = schema.tables[tables[0]]
		const insertFields = maintable.fields.filter(x => x.field && (x.value || keys[x.fkey]>'' ||params[x.variable]>''))
		let fields = insertFields.map(x => x.field)

		let values = insertFields
					.map(x => {

						params[x.variable] = x.func ? x.func(params[x.variable]) : params[x.variable] /* format  the value with the formating function from schema*/

						return x.hasOwnProperty('value') ? 
						`'${x.value}'` :
						x.hasOwnProperty('fkey') ?
						(Array.isArray(keys[x.fkey]) && keys[x.fkey].length > 1 ? `'{${keys[x.fkey]}}'` : keys[x.fkey]) :
						`'${params[x.variable]}'${x.conv ? x.conv: ''}`
					})
		let sql = `insert into ${!isPublic ? 'mymes.' : ''}${tables[0]}(${fields}) values(${values}) returning id;`
		console.log("insert query maintable",sql)
		new_id = keys[id] = await db.one(sql).then(x => x.id)
		tables.shift()
		const ret  = await Promise.all(tables.map(async (tablename)=>{
			const table = schema.tables[tablename]
			const fields = table.fields.filter(x => x.field).map(x => x.field)
			if (table.hasOwnProperty('fill')) {
				let field = table.fill.field
				return await Promise.all(table.fill.values.map(val => {
					let values = table.fields.filter(x => x.field )
											 .map(x =>  x.field === field ?
											 	 val : x.hasOwnProperty('fkey') ?
											 	 keys[x.fkey] : `'${params[x.variable+(val === params['lang_id'] || !params[x.variable] ? '' : '_t')]}'`
											 )
					let sql = `insert into ${!isPublic ? 'mymes.' : ''}${tablename}(${fields}) values(${values}) returning *;`
					console.log("insert query if",sql)
					return db.one(sql).then(x => x)
				}))

			}
			else {
				let values = table.fields.filter(x => x.field).map(x =>  x.hasOwnProperty('fkey') ? keys[x.fkey] : `'${params[x.variable]}'`)
				let sql = `insert into ${!isPublic ? 'mymes.' : ''}${tablename}(${fields}) values(${values}) returning *;`
				console.log("insert query else",sql)				
				let ret =  await db.one(sql).then(x => x)
				return ret
			}
		}))
						// Execeute the Post-Insert Statement from the schema
		const post_insert = schemas[entity].post_insert						
		params.id = new_id
		console.log('params:',params)
		const parameters = post_insert && post_insert.parameters.map(x => params[x])
		const post = post_insert && parameters && db.func(post_insert.function, parameters)
											    .then(data => {
											        console.log(`Return from function - ${post_insert.function} : ${data}`); 
											    })
											    .catch(error => {
											        console.log('ERROR:', error); 
											    });

		res.status(201).json(ret)
	} catch(err) {
		console.log("123:",err)
		res.status(406).json({error: err})
	}
}

const update = async (req, res, entity) => {
	let params = {}
	Object.keys(req.body).forEach(x=> params[x] = typeof req.body[x] === 'string' ?  req.body[x].replace(/'/g,"") : req.body[x]) //Protection againt sql injection
	const schema = schemas[entity].schema
	const isPublic = !!schemas[entity].public
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
			fkeys[key] =  Array.isArray(value) && value.length === 1 ? value[0] : value
			})		

		var allParams = Object.assign({},params,fkeys)
		Object.keys(allParams).forEach(key => {
			value = allParams[key]
			allParams[key] =  Array.isArray(value) ? `{${value}}` : value
			})

		const ret = Promise.all(tableNames.filter(tn => tables[tn].fields.some(field => allParams.hasOwnProperty(field.field)))
				  .map(tn =>{
				  	const table = schema.tables[tn]
				  	const sets = table.fields.filter(field => allParams.hasOwnProperty(field.field) && (allParams[field.field] || allParams[field.field] === false))
				  							 .map(field => ({set : field.field, to: allParams[field.field], conv: field.conv }))
					/*console.log('~~~********:',sets)*/
				  	const wheres = table.fields.filter(field => params.hasOwnProperty(field.key))
				  							   .map(field => ({where : field.field > '' ? field.field : field.key , equals: params[field.key]}))
				  	const sqlSet = sets.reduce((old,set) => old + `"${set.set}" = '${set.to}'${set.conv ? set.conv: ''},`,'').slice(0,-1)
				  	const sqlWhere = wheres.reduce((old,where) => old + `${where.where} = '${where.equals}' and `,'').slice(0,-5)
				  	//const keyField = table.fields.filter(x => x.key && !x.field)[0].key
					/*const sql = `UPDATE mymes.${tn}
								SET  ${sqlSet} 
								WHERE  ${keyField} = (
								         SELECT ${keyField}
								         FROM   mymes.${tn}
								         WHERE  ${sqlWhere}
								         LIMIT  1
								         FOR UPDATE SKIP LOCKED
								         )
								RETURNING 1;`				  	
								*/
				  	const sql = `update ${!isPublic ? 'mymes.' : ''}${tn} set ${sqlSet} where ${sqlWhere} returning 1;`
				  	console.log("update sql:",sql)
				  	const ret  = runQuery(sql)
				  	return ret
		}))

						// Execeute the Post-Insert Statement from the schema
		const post_update = schemas[entity].post_update
		console.log('params:',params)
		const parameters = post_update && post_update.parameters.map(x => params[x])
		const post = post_update && parameters && db.func(post_update.function, parameters)
											    .then(data => {
											        console.log(`Return from function - ${post_update.function} : ${data}`); 
											    })
											    .catch(error => {
											        console.log('ERROR:', error); 
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
	const isPublic = !!schemas[entity].public	
	let table = Object.keys(schema.tables)[0] /*all  translation tables are now deleted by DB constarint */
	const key = schema.tables[table].fields.filter(x =>  x.key)[0].key
	console.log("ooooo:",key)
	const {pre_delete, post_delete} = schemas[entity]

	/* cascading delete is preformed by DB foreign keys constraints*
	/*tables = pre_delete && pre_delete.tables ? [...tables, ...pre_delete.tables] : tables*/
	const sql = `delete from ${!isPublic ? 'mymes.' : ''}${table} where ${key} = `
	const finalSqls	 = params.keys && sql && params.keys.reduce((o,x) => {
															//o.push(sql + x + ' returning 1;')
															return [...o , `${sql}${x} returning 1; `]
															}
														,[])

	try {
   	console.log("Param:",params)
	const pre = pre_delete && pre_delete.function && params.keys && await db.func(pre_delete.function, [params.keys])
											    .then(data => {
											        console.log(`Return from function - ${pre_delete.function} : ${data[0]}`); 
											    })	

   	const ret  = await Promise.all(finalSqls.map(sql => runQuery(sql)))

	const post = post_delete && params.keys && await db.func(post_delete.function, [params.keys])
											    .then(data => {
											        console.log(`Return from function - ${post_delete.function} : ${data[0]}`); 
											    })	
	res.status(205).json(ret)
		return 
	} catch(err) {
		console.log("delete:",err)
		res.status(406).json({error:'delete : '+err})
	}
}

const func = async (req, res, entity) => {
	let { funcName, keys }  = req.body
	const schema = schemas[entity].schema
	console.log("func:", funcName, keys,req.body)
	try {
   	const ret  = await Promise.all(keys.map(key => db.func(`${funcName}_${entity}`, key)))
		res.status(230).json(ret)
		return 
	} catch(err) {
		console.log(err)
		res.status(406).json({error:err})
	}

}

module.exports = {
  fetch, fetchRoutes, fetchTags,fetchByName, update, insert, remove, runQuery ,func, fetchNotifications
}