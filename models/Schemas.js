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
const {identifier_links} = require('../schemas/identifier_links.js') 
const {proc_act} = require('../schemas/proc_act.js') 
const {serial_act} = require('../schemas/serial_act.js') 
const {preferences} = require('../schemas/preferences.js') 
const {numerators} = require('../schemas/numerators.js')
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
const {fault_type_actions} = require('../schemas/fault_type_act.js')
const {fault_status} = require('../schemas/fault_status.js')
const {fix} = require('../schemas/fix.js')
const {fix_actions} = require('../schemas/fix_act.js')
const {lot_swap} = require('../schemas/lot_swap.js')
const schemas = {
	employees ,
	parts ,
	departments ,
	users ,
	profiles ,
	equipments,
	resource_groups ,
	resources ,	
	availability_profiles ,
	availabilities ,
	resource_timeoff ,	
	employee_timeoff ,		
	malfunctions ,
	malfunction_types ,
	repairs ,
	repair_types,
	mnt_plans  ,
	mnt_plan_items  ,
	serials , 
	serial_statuses,
	part_status,	
	act_resources, 	
	actions ,
	positions ,	
	process ,
	proc_act,
	serial_act,	
	kit ,
	bom ,
	iden ,
	locations ,
	work_report ,
	identifier,
	identifier_links, 
	preferences ,
	numerators,
	fault_status,
	fault_type,
	fault : fault,
	fault_type_actions,
	fix,
	fix_actions,
	lot_swap,
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

const fetchResources = async(response) =>{
	const DBToTree = (resources) => {
	    let raw = resources 
	    let raw2 = [...raw]
	    rg = raw.filter(x=> x.resource_ids)   
		rg.map(ri => {
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

/**
 * getField: Enables the schema fields field property to be a Function or a String
 * @param {*} field - the value of the field (might be a function)
 * @param {*} flag - the parameter to feed the function
 */
const getField = (field,flag) => typeof field === 'function' ? field(flag || 0) : field


/**
 *  Populate the response data from DB with the requested data of a certain entity
 * @param {*} request 
 * @param {*} response 
 * @param {*} entity 
 * @returns {Object} (main : the data of the main table, choosers : the choose lists to populate the input forms of this schema )
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

/**
 * @param {*} query 
 * @returns {Promise} the query result
 */
const runQuery = async (query) => {
	try{
		return await db.any(query).then(x => x)
	} catch(err) {
		console.error(err)
		throw new Error(err)
	}
}


/**
 * @param {*} fkeys - the fkeys quries from the schemas
 * @param {*} params - the parameters to feed the quries
 * @returns {Object} - the queries results (the Keys)
 */
const getFkeys = async (fkeys,params) => {

	const keys = {}
	try{
		const fkeysNames = Object.keys(fkeys)
		const keyValues = await Promise.all(fkeysNames.map(async (key) => {
			const query = fkeys[key]	
			const parameters = Array.isArray(query.value) ? 
				query.value.map(value =>  Array.isArray(params[value]) ? params[value].toString() :	params[value]) :
				Array.isArray(params[query.value]) ? params[query.value].toString() :[params[query.value]]
			
				
			var res = query.hasOwnProperty('query') ?
						await db.any(query.query, parameters).then(x => Array.isArray(x)? x.map(x=> x.id) : x.id).then(x => x.length == 0 ? query.default : x ) :
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

/**
 * 
 * @param {*} params - the data to be inseted
 * @param {*} schema - the main table that the raw will be inserted to
 * @returns id of the inserted row 
 */
const InsertToTables = async (params,schema) => {
	const keys = await getFkeys(schema.fkeys,params)
	const tables = Object.keys(schema.tables)
	const chain = schema.chain
	const chain_pre = schema.chain_pre
	const isPublic = !!schema.public
	const id  = schema.pkey
	var new_id = 0    

	if (chain_pre && Array.isArray(chain_pre)) {
		try{
		var mute
		const Chain_pre_Insert =  await Promise.all(chain_pre.map(async (chainSchema) => await insert({body : {...params, parent : new_id.id}}, null , chainSchema , mute = true)))
		}catch(err) {
			console.error("pre_chain:",err)
			if (!mute) res.status(406).json({error: 'pre_chain : '+err})
			throw new Error("PreChian fault")
		}
	}

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
	//console.log('Inser5t params',params,insertFields,fields)	
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

	var sqls  = flatten(tables.map( tablename => {		
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
	}).filter(x=>x))

	console.log("main : ",mainTableSql," sqls : ", sqls)	
	
	var new_id = await db.tx( async t => {
		new_key = await t.oneOrNone(mainTableSql)
		console.log(sqls)
		const c = new_key && await Promise.all(sqls.map(sql => t.any(sql,[new_key.id])))
		return new_key
	}).catch(error => {
			console.error(error)
			throw new Error(error)
	});

	const ChainInsert = chain && chain.map(async (chainSchema) => await insert({body : {...params, parent : new_id.id}}, null , chainSchema , mute = true))
	
	return new_id && new_id.id
}


/**
 * 
 * @param {Object} req 
 * @param {Object} res 
 * @param {text} entity - the schema type
 * @param {boolean} mute - if true  will suppress any answer to the client.
 * @returns {integer} - the id of the raw.
 */
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
													return data[0]
												})
												.catch(error => {
											        console.error('ERROR:', error); 
											        throw new Error(error)
											    });
		//console.log("pre_insert   :   :  :  : ",pre_insert && pre[pre_insert.function])
		if (pre_insert && pre[pre_insert.function] === -1) {
			res && res.status(200).json({pass: true})
			return
		}

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
							
		const pih = schemas[entity].postInsertHelpers &&  schemas[entity].postInsertHelpers.map(async PIH => {
			const PIHparameters = {}
			PIH.parameters.forEach(x => {
				PIHparameters[x] = params[x]
			})
			console.log("------",PIHparameters, PIH.parameters)
			return PIH && PIHparameters && await PIH.func(db,new_id,PIHparameters)
		})

		return new_id	

	} catch(err) {
		console.error("error in Insert:",err)
		if (!mute)res.status(406).json({error: 'insert : '+err})
		throw new Error("Insert fault :" + err.toString())
	}
}

/**
 * 
 * @param {Object} req 
 * @param {Object} res 
 * @param {Text} entity - the schema type
 */
const update = async (req, res, entity) => {
	let params = {}
	Object.keys(req.body).forEach(x=> params[x] = typeof req.body[x] === 'string' ?  req.body[x].replace(/'/g,"") : req.body[x]) //Protection againt sql injection
	const schema = schemas[entity].schema
	const isPublic = !!schema.public
	const tables= schema.tables
	const tableNames  = Object.keys(tables)
	let  fkSchema = {}
	const fkeysNames = Object.keys(schema.fkeys).filter(key => schema.fkeys[key].value in params || (schema.fkeys[key].value && (schema.fkeys[key].value)[0] in params))
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

		const ret = await Promise.all(tableNames.filter(tn => tables[tn].fields.some(field => allParams.hasOwnProperty(getField(field.field,params['flag']))))
				  .map(tn =>{
				  	const table = schema.tables[tn]
				  	const sets = table.fields.filter(field => {
							const fname = getField(field.field,params['flag'])

									return allParams.hasOwnProperty(fname) && (allParams[fname] !== undefined) // (allParams[fname] || allParams[fname] === false || allParams[fname] === 0)
										})
										.map(field => {
											const fname = getField(field.field,params['flag'])
											return {set : fname, to: allParams[fname] , conv: field.conv }
										})
				  	const wheres = table.fields.filter(field => params.hasOwnProperty(field.key))
				  							   .map(field => ({where : getField(field.field,params['flag']) > '' ? getField(field.field,params['flag']) : field.key , equals: params[field.key]}))
				  	const sqlSet = sets.reduce((old,set) => old + `"${set.set}" = ${set.to != null ? "'" : ""}${set.to}${set.to != null ? "'" : ""}${set.conv ? set.conv: ''},`,'').slice(0,-1)
				  	const sqlWhere = wheres.reduce((old,where) => old + `${where.where} = '${where.equals}' and `,'').slice(0,-5)
				  	const sql = `update ${!isPublic ? 'mymes.' : ''}${tn} set ${sqlSet} where ${sqlWhere} returning 1;`
				  	console.log("update sql:",sql)
				  	const ret  =  runQuery(sql)
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
		res.status(406).json({error: 'insert : '+err})
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
		res.status(406).json({error: 'function : '+err})		
	}

}

const runFunc = async (req, res, funcName) => {
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


/**
 * uses the batchIinsert_ function independently
 * @param {Object} req 
 * @param {Object} res 
 * @param {Text} entity 
 */
const batchInsert = async (req,res,entity) => {
	try {
		const ret = await Promise.all(await batchInsert_(req.body.data,entity))
		res.status(200).json({inserted:ret})
	}catch(err){
		console.error("Error in batchInsert",err)
		res.status(406).json({error: 'BatchInsert : '+err})		
	}	
}

/**
 * Insert more then one row to a schemas table
 * @param {*} data 
 * @param {*} entity 
 * @returns {Promise}
 */
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
			//return await InsertToTables(params,schema)
			return await insert({body : params},null,entity,true)
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



module.exports = {
  fetch, fetchRoutes, fetchResources, fetchTags, update, batchUpdate, batchInsert, batchInsert_,  insert, remove,
  runQuery ,runFunc, func, fetchNotifications, InsertToTables
}