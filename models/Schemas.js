//db connection configuration
const {pgconfig} = require('../DBConfig.js')
const pgp = require('pg-promise')();
const db = pgp(pgconfig);
const {employees} = require('../schemas/employees.js')
const {parts} = require('../schemas/parts.js')
const schemas = {employees : employees, parts : parts};

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

//fetches Employee's data from db
const fetch = (request, response, entity) => {
	return db.any(schemas[entity].sql.all
				, [request.query.lang]
				).then((emp) => response.status(201).json(emp))
 				 .catch((err) => {
      				response.status(401)
      				console.error(err)
    			})  
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
			return query.hasOwnProperty('query') ? db.one(query.query, [params[query.value]]).then(x => x.id) : params[query.value]
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
	const id  = schema.pkey
	try{
		const keys = await getFkeys(schema.fkeys,params)
		const tables = Object.keys(schema.tables)
		const maintable = schema.tables[tables[0]]
		let fields = maintable.fields.filter(x => x.field > '').map(x => x.field)
		let values = maintable.fields.filter(x => x.field > '').map(x =>  x.hasOwnProperty('fkey') ? keys[x.fkey] : `'${params[x.variable]}'`)
		let sql = `insert into mymes.${tables[0]}(${fields}) values(${values}) returning id;`
		console.log("insert query maintable",sql)
		keys[id] = await db.one(sql).then(x => x.id)
		tables.shift()
		const ret  = tables.map(async (tablename)=>{
			const table = schema.tables[tablename]
			const fields = table.fields.filter(x => x.field > '').map(x => x.field)
			if (table.hasOwnProperty('fill')) {
				let field = table.fill.field
				return await Promise.all(table.fill.values.map(val => {
					let values = table.fields.filter(x => x.field > '')
											 .map(x =>  x.field === field ? val :x.hasOwnProperty('fkey') ? keys[x.fkey] : `'${params[x.variable+(val === params['lang_id'] ? '_t' : '')]}'`)
					let sql = `insert into mymes.${tablename}(${fields}) values(${values}) returning *;`
					console.log('insert query in fill',sql)
					return db.one(sql).then(x => x)
				}))

			}
			else {
				let values = table.fields.filter(x => x.field > '').map(x =>  x.hasOwnProperty('fkey') ? keys[x.fkey] : `'${params[x.variable]}'`)
				let sql = `insert into mymes.${tablename}(${fields}) values(${values}) returning *;`
				console.log('insert query no fill:',sql)
				let ret =  await db.one(sql).then(x => x)
				return ret
			}
		})
		res.status(200).json({})
	} catch(err) {
		console.log(err)
		res.status(401)
	}
}


const update = async (req, res, entity) => {
	let params = req.body
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
		const ret =  Promise.all(tableNames.filter(tn => tables[tn].fields.some(field => allParams.hasOwnProperty(field.field)))
				  .map(tn =>{
				  	const table = schema.tables[tn]
				  	const sets = table.fields.filter(field => allParams.hasOwnProperty(field.field))
				  							 .map(field => ({set : field.field, to: allParams[field.field]}))
				  	const wheres = table.fields.filter(field => params.hasOwnProperty(field.key))
				  							   .map(field => ({where : field.field > '' ? field.field : field.key , equals: params[field.key]}))
				  	const sqlSet = sets.reduce((old,set) => old + `${set.set} = '${set.to}',`,'').slice(0,-1)
				  	const sqlWhere = wheres.reduce((old,where) => old + `${where.where} = '${where.equals}' and `,'').slice(0,-5)
				  	const sql = `update mymes.${tn} set ${sqlSet} where ${sqlWhere} returning 1;`
				  	console.log("sql:",sql)
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
  fetch, fetchByName, update, insert
}