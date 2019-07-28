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

module.exports = {
  bugInsert,
  changeUserLang,
  markNotificationAsRead  
}