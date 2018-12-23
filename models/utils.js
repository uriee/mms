//db connection configuration
const {db} = require('../DBConfig.js')

const bugInsert = async (req, res) => {
		let sql = `insert into bugs(message,state,status) values('${req.body.message}','${req.body.clientName}',1) returning id;`
		try{
			const ret  = await db.one(sql).then(x => x)
			return res.sendStatus(201)
		} catch(err) {
			console.log(err)
			res.sendStatus(401)
		}
		return 0
}

module.exports = {
  bugInsert
}