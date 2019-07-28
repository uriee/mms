const {db} = require('../DBConfig.js')

const fetchWorkPaths = async(request, response) =>{
	const {user} = request.query
	const sql = `select r.name as resourcename,serial.name as serialname,act.name as actname ,seract.balance , seract.quant , seract.quantitative ,
		seract.serialize and part.serialize as serialize 
		from mymes.actions as act, mymes.part as part, 
		mymes.serials as serial , mymes.serial_act as seract 
		join mymes.act_resources as ar on (ar.act_id = seract.id and type = 3)
		join mymes.resources as r on r.id = ar.resource_id 
		where serial.id = seract.serial_id and act.id = seract.act_id 
		and serial.active=true and act.active=true
		and part.id = serial.part_id
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
	const {serialname,actname,lang} = request.query
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
		and users.id = wr.sig_user
		and serials.name = '${serialname}'
		and actions.name = '${actname}'
		order by sig_date desc;`

	const locsql = `select loc.location
		from mymes.locations loc left join mymes.actions act on loc.act_id = act.id, mymes.serials ser
		where ser.name = '${serialname}'
		and (act.name  = '${actname}' or loc.act_id is null)
		and loc.part_id = ser.part_id;`

	const idensql = `select sp.name,array_agg(i.name) as identifiers
		from mymes.identifier i,
			mymes.part pp,
			mymes.part sp,
			mymes.locations l,
			mymes.bom b,
			mymes.serials s,
			mymes.actions a
		where i.parent_id = sp.id
			and l.part_id = pp.id
			and b.parent_id = pp.id
			and b.produce = true
			and i.parent_identifier_id is null 
			and l.part_id = b.parent_id
			and l.partname = b.partname
			and a.id = l.act_id
			and sp.name = b.partname	
			and a.name = '${actname}'
            and s.name = '${serialname}'
        group by sp.name;`

	const typesql = `select name,description from mymes.fault_type f ,mymes.fault_type_t t  where active = true and t.fault_type_id = f.id and t.lang_id = ${lang || 1};`

	try{
		const WR =  await db.any(WRsql).then(x=>x)	
		const loc = await db.any(locsql).then(x=>x)
        const type = await db.any(typesql).then(x=>x)
        const son_identifiers = await db.any(idensql).then(x=>x)      
		response.status(200).json({main:{WR,type,loc,son_identifiers}})
	}catch(e){
		console.error(e)
	}
}

module.exports = {
    fetchWR ,
    fetchWorkPaths,
  }