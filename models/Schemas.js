//db connection configuration
const {pgconfig} = require('../DBConfig.js')
const pgp = require('pg-promise')();
const db = pgp(pgconfig);
const {employees} = require('../schemas/employees.js')
const schemas = {employees : employees};

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
	console.log("in fetchEmp",entity,schemas)
	return db.any(schemas[entity].sql.all
				, [request.query.lang]
				).then((emp) => response.status(201).json(emp))
 				 .catch((err) => {
      				response.status(401)
      				console.error(err)
    			})  
}


const insert = async (req, res, entity) => {
	const params = req.body
	const schema = schemas[entity].schema
	const id  = schema.pkey
	try{
		const fkeysnames = Object.keys(schema.fkeys)
		const keyvalues = await Promise.all(fkeysnames.map(async (key) => {
			const query = schema.fkeys[key]
			return query.hasOwnProperty('query') ? db.one(query.query, [params[query.value]]).then(x => x.id) : params[query.value]
		})).then(x => {console.log('keys in inset query:',x); return x})
		const keys = {}
		fkeysnames.map((name,i) => {
			keys[name] = keyvalues[i]
		})
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
					let values = table.fields.filter(x => x.field > '').map(x =>  x.field === field ? val :x.hasOwnProperty('fkey') ? keys[x.fkey] : `'${params[x.variable+(val === params['lang_id'] ? '_t' : '')]}'`)
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
const update = () => {
	const params = req.body
	const schema = schemas[entity].schema
}


module.exports = {
  fetch, fetchByName, update, insert
}