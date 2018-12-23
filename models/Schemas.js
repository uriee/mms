//db connection configuration
const {db} = require('../DBConfig.js')
const {flatten} = require('lodash')

const {employees} = require('../schemas/employees.js')
const {parts} = require('../schemas/parts.js')
const {departments} = require('../schemas/departments.js')
const {users} = require('../schemas/users.js')
const {profiles} = require('../schemas/profiles.js')
const {equipments} = require('../schemas/equipments.js')
const {resource_groups} = require('../schemas/resource_groups.js')
const {resources} = require('../schemas/resources.js')
const {availability_profiles} = require('../schemas/availability_profiles.js')
const {availabilities} = require('../schemas/availabilities.js') 
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
	malfunctions : malfunctions,
	malfunction_types : malfunction_types,
	repairs : repairs,
	repair_types : repair_types,
	mnt_plans : mnt_plans,
	mnt_plan_items : mnt_plan_items,
	}

const fillTemplate = function(templateString, templateVars){
	
    return new Function("return `"+templateString +"`;").call(templateVars);
}

//fetches Employee data from db 
const fetchByName = (request, response, entity) => {
	const param = request.body

  	return db.one(schemas[entity].sql.single
				, [param.name,param.lang]
				).then((emp) => response.status(201).json({ emp }))
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
		response.status(201).json({main:ret})
	console.log('xxxxxx',sql,request.query,ret)		
	}catch(e){
		console.log(e)
	}
}
/*
Populate the response data from DB with the requested data of a certain entity
*/
const fetch = async (request, response, entity) => {
	const {lang,pageSize,currentPage,zoom} = request.query
	console.log(schemas[entity],entity)
	const tables = schemas[entity].schema.tables	
	const filters = flatten(	
							Object.keys(tables)
							.map(table=> tables[table].fields
								.map(x => ({field : `${table}.${x.field || x.key}`,value : request.query[x.field || x.key]}))
								)
							).filter(field => field.value)
	
	try {
		const filterSql = filters.reduce((string, filter)=> string+` and ${filter.field} like '%${filter.value}%'`, '')
		const zoomSql = filters.reduce((string, filter)=> string+` and ${filter.field} = '${filter.value}'`, '')
		//const pageSql = pageSize ? ` offset ${(currentPage - 1) * pageSize} ` : ''
		const sql = schemas[entity].sql.all + (zoom === '1' ? zoomSql  : filterSql)  + (schemas[entity].sql.final || '') + ' limit 100;'
		console.log('ssssqqqqllll:',sql)		
		const main = await db.any(sql,[lang]).then(x=>x)
		const type = !main[0] ? 201 : 201
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
	
			const parameter = Array.isArray(params[query.value]) ? params[query.value].toString() :
								[params[query.value]]
			var res = query.hasOwnProperty('query') ?
						 await db.any(query.query, parameter)
					  	 .then(x => {console.log("----------------------",x,key,fkeys[key]);
					  	  return Array.isArray(x)? x.map(x=> x.id) : x.id}) :
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
	var params = req.body
	console.log('===========1:',params)	
	Object.keys(params).forEach(x => {
		params[x] = Array.isArray(params[x]) ? (params[x].length === 1 ? `{${params[x][0]}}` : `{${params[x]}}`) : params[x]
	})
	console.log('===========2:',params)
	const schema = schemas[entity].schema
	const isPublic = !!schemas[entity].public
	const post_insert = schemas[entity].post_insert
	const id  = schema.pkey
	var new_id = 0
	try{
		const keys = await getFkeys(schema.fkeys,params)

		const tables = Object.keys(schema.tables)
		const maintable = schema.tables[tables[0]]
		const insertFields = maintable.fields.filter(x => x.field && (x.value || keys[x.fkey]>'' ||params[x.variable]>''))
		let fields = insertFields.map(x => x.field)

		let values = insertFields
					.map(x => x.hasOwnProperty('value') ? 
						`'${x.value}'` :
						x.hasOwnProperty('fkey') ?
						(Array.isArray(keys[x.fkey]) && keys[x.fkey].length > 1 ? `'{${keys[x.fkey]}}'` : keys[x.fkey]) :
						`'${params[x.variable]}'`
					)
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
											 .map(x =>  x.field === field ? val :x.hasOwnProperty('fkey') ? keys[x.fkey] : `'${params[x.variable+(val === params['lang_id'] ? '_t' : '')]}'`)
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

		const post = post_insert && db.func(post_insert.function, new_id)
											    .then(data => {
											        console.log(`Return from function - ${post_insert.function} : ${data}`); 
											    })
											    .catch(error => {
											        console.log('ERROR:', error); 
											    });

		res.status(200).json(ret)
	} catch(err) {
		console.log(err)
		res.status(401)
	}
}

const update = async (req, res, entity) => {
	let params = req.body
	console.log("update ---", )
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
				  	console.log("---------",allParams)
				  	const sets = table.fields.filter(field => allParams.hasOwnProperty(field.field) && allParams[field.field])
				  							 .map(field => ({set : field.field, to: field.array ? allParams[field.field] : allParams[field.field]}))
					/*console.log('~~~********:',sets)*/
				  	const wheres = table.fields.filter(field => params.hasOwnProperty(field.key))
				  							   .map(field => ({where : field.field > '' ? field.field : field.key , equals: params[field.key]}))
				  	const sqlSet = sets.reduce((old,set) => old + `${set.set} = '${set.to}',`,'').slice(0,-1)
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

		res.status(200).json(ret)
		return
	} catch(err) {
		console.log(err)
		res.status(401).json({error:err})
	}
}


const remove = async (req, res, entity) => {
	let params = req.body
	const schema = schemas[entity].schema
	const isPublic = !!schemas[entity].public	
	console.log("remove ---",params)	
	const tables = Object.keys(schema.tables)
		.map(table => {
			const key = schema.tables[table].fields.reduce((o,x) => x.hasOwnProperty('key') && x.key === 'id' ? x.field || x.key : o , null)
			return {
				'table' : table,
				'key' : key
			}
		})
		.filter(x => x.key)
	const sqls = tables.map(table => `delete from ${!isPublic ? 'mymes.' : ''}${table.table} where ${table.key} = `)	
	const finalSqls	 = params.keys && sqls && params.keys.reduce((o,x) => {
															sqls.forEach(statement => o.push(statement + x + ' returning 1;'))
															return o
															}
														,[])
	console.log('final:',finalSqls) 

	try {
   	const ret  = await Promise.all(finalSqls.map(sql => runQuery(sql)))
	console.log('remove ret:',ret) 
		res.status(200).json(ret)
		return 
	} catch(err) {
		console.log(err)
		res.status(401).json({error:err})
	}
}

module.exports = {
  fetch,fetchTags,fetchByName, update, insert, remove
}