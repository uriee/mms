//db connection configuration
const {pgconfig} = require('../DBConfig.js')
const pgp = require('pg-promise')();
const db = pgp(pgconfig);
const {flatten} = require('lodash')

const {employees} = require('../schemas/employees.js')
const {parts} = require('../schemas/parts.js')
const {departments} = require('../schemas/departments.js')
const {users} = require('../schemas/users.js')
const {machines} = require('../schemas/machines.js')
const {resource_groups} = require('../schemas/resource_groups.js')
const {resources} = require('../schemas/resources.js')
const {availability_profiles} = require('../schemas/availability_profiles.js')
const {availabilities} = require('../schemas/availabilities.js') 

const schemas = {
	employees : employees,
	parts : parts,
	departments : departments,
	users : users,
	machines: machines,
	resource_groups : resource_groups,
	resources : resources,	
	availability_profiles : availability_profiles,
	availabilities : availabilities
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

/*
Populate the response data from DB with the requested data of a certain entity
*/
const fetch = async (request, response, entity) => {
	const {lang,pageSize,currentPage,zoom} = request.query
	/*console.log(schemas[entity],entity)*/
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
			response.status(403)
			console.log(err)
		}
}

const runQuery = async (query) => {
	try{
		return await db.one(query).then(x => x)
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
	const params = req.body
	const schema = schemas[entity].schema
	const post_insert = schemas[entity].post_insert
	const id  = schema.pkey
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
		let sql = `insert into mymes.${tables[0]}(${fields}) values(${values}) returning id;`
		console.log("insert query maintable",sql)
		keys[id] = await db.one(sql).then(x => x.id)
		tables.shift()
		const ret  = await Promise.all(tables.map(async (tablename)=>{
			const table = schema.tables[tablename]
			const fields = table.fields.filter(x => x.field).map(x => x.field)
			if (table.hasOwnProperty('fill')) {
				let field = table.fill.field
				return await Promise.all(table.fill.values.map(val => {
					let values = table.fields.filter(x => x.field )
											 .map(x =>  x.field === field ? val :x.hasOwnProperty('fkey') ? keys[x.fkey] : `'${params[x.variable+(val === params['lang_id'] ? '_t' : '')]}'`)
					let sql = `insert into mymes.${tablename}(${fields}) values(${values}) returning *;`
					return db.one(sql).then(x => x)
				}))

			}
			else {
				let values = table.fields.filter(x => x.field).map(x =>  x.hasOwnProperty('fkey') ? keys[x.fkey] : `'${params[x.variable]}'`)
				let sql = `insert into mymes.${tablename}(${fields}) values(${values}) returning *;`
				let ret =  await db.one(sql).then(x => x)
				return ret
			}
		}))
		console.log(ret[0])
		const new_id = ret[0] && Array.isArray(ret[0]) ? ret[0][0][id] : ret[0]['id']
		const post = post_insert && db.func(post_insert.function, new_id)
											    .then(data => {
											        console.log('DATA:', data); 
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
	console.log("update ---", params)
	const schema = schemas[entity].schema
	const tables= schema.tables
	const tableNames  = Object.keys(tables)
	let  fkSchema = {}
	const fkeysNames = Object.keys(schema.fkeys).filter(key => schema.fkeys[key].value in params)
	fkeysNames.map((key) => {
			fkSchema[key] = schema.fkeys[key]
		})
	try {
		const fkeys = await getFkeys(fkSchema, params)
		allParams = Object.assign({},params,fkeys)
		Object.keys(allParams).forEach(key => {
			value = allParams[key]
			allParams[key] = Array.isArray(value) && value.length > 1 ? `{${value}}` : value})
		const ret = Promise.all(tableNames.filter(tn => tables[tn].fields.some(field => allParams.hasOwnProperty(field.field)))
				  .map(tn =>{
				  	const table = schema.tables[tn]
				  	const sets = table.fields.filter(field => allParams.hasOwnProperty(field.field))
				  							 .map(field => ({set : field.field, to: field.array ? allParams[field.field] : allParams[field.field]}))
					/*console.log('~~~********:',sets)*/
				  	const wheres = table.fields.filter(field => params.hasOwnProperty(field.key))
				  							   .map(field => ({where : field.field > '' ? field.field : field.key , equals: params[field.key]}))
				  	const sqlSet = sets.reduce((old,set) => old + `${set.set} = '${set.to}',`,'').slice(0,-1)
				  	const sqlWhere = wheres.reduce((old,where) => old + `${where.where} = '${where.equals}' and `,'').slice(0,-5)
				  	const sql = `update mymes.${tn} set ${sqlSet} where ${sqlWhere} returning 1;`
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


module.exports = {
  fetch,fetchByName, update, insert
}