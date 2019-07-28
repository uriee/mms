const {db} = require('../DBConfig.js')

/***
* Get the approval of the erp acceptance of the work reports
* And set approve propety of the reports to true
****/
const approveWorkReports = async (req,res,entity) => {
	var data = {}
	const table = entity || 'work_report'
	try {
		data = JSON.parse(req.body.data)
	}catch(e){
		res.status(406).json({})
	}
	const ids = data[0].REPORTS.map(x => x.MESID);
	let sql = `update mymes.${table}
				set approved = true
				where id = any (ARRAY[${ids}]) returning 1`
	try{
		lines = await db.any(sql)
		res.status(200).json(lines)
	}catch(e){
		console.error("error in approveWorkReport : ",table,e)
		res.status(406).json({error: `approveWorkReports : ${table}-${e}`})		
	}
}

/***
* Exports the Work Reports that are not yet Sent to the Erp server
* And set Sent propety of the reports to true
****/
const exportWorkReport = async (req,res,entity) => {
	const row_type = entity || 'work_report'	
	const option = {year:'2-digit', month: '2-digit', day: "2-digit" }
	const date = new Date().toLocaleDateString("he",option).replace(/-/g,'/')
	let sql = `select w.id as id ,extserial as wo,erpact as act,w.quant
				from mymes.work_report as w,mymes.serials as s ,mymes.actions as a
				where a.id = w.act_id
				and s.id = w.serial_id
				and extserial is not null
				and erpact is not null
				and (sent is null or sent is false);`
	let sql_fault = `select w.id as id ,extserial as wo,erpact as act,w.quant
				from mymes.work_report as w,mymes.serials as s ,mymes.actions as a
				where a.id = w.act_id
				and s.id = w.serial_id
				and extserial is not null
				and erpact is not null
				and (sent is null or sent is false);`				
	try{
		var lines = await db.any(sql)

		lines = await Promise.all(lines.map( async w => {
			const idsql = `select i.id,i.name from mymes.identifier i, mymes.identifier_links il
						   where i.id = il.identifier_id
						   and row_type = '${row_type}'
						   and il.parent_id = ${w.id};`			
			const iden = await db.any(idsql)
			const identifiers = iden.map( id => ({id: id.id, name: id.name}))
			return {...w, identifiers}
		}))
		
		const data = {
			date : date,
			data: lines
		}

		if (lines.length) {

			res.status(200).json(data)
		
			const ids = lines.map(x=>x.id).toString()

			sql = `update mymes.${row_type}
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
						const sql = `select id,name,serialize,quantitative from mymes.actions where erpact = '${x.ACTNAME}';`
						const act = await db.one(sql)
						return {act_name: act.name, pos : x.POS, serialize : act.serialize, quantitative : act.quantitative}
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
					serial.BOM = serial.BOM && serial.BOM.map(x => ({ lang_id: 1, partname : x.PARTNAME, coef : x.COEF, produce: x.TYPE==='P' , parent : part_id}))
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
    importSerial,
    exportWorkReport,
    approveWorkReports
  }