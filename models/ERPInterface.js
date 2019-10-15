const {db} = require('../DBConfig.js')
const {parts} = require('../schemas/parts.js')
const {
	batchInsert_,
	insert,
	InsertToTables
  } = require('./Schemas.js')

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
const exportWorkReport = async (req,res) => {
	const option = {year:'2-digit', month: '2-digit', day: "2-digit" }
	const date = new Date().toLocaleDateString("he",option).replace(/-/g,'/')
	let sql = `select w.id as id ,extserial as wo,erpact as act,w.quant
				from mymes.work_report as w,mymes.serials as s ,mymes.actions as a
				where a.id = w.act_id
				and s.id = w.serial_id
				and extserial is not null
				and erpact is not null
				and (sent is null or sent is false)
				order by w.id;`
	try{
		var lines = await db.any(sql)
		
		lines = await Promise.all(lines.map( async w => {
			const idsql = `select  i.id, i.name, i.secondary, i.mac_address, array_agg(s.name || '|' || sp.name) as sons
							from mymes.identifier i left join mymes.identifier s on s.parent_identifier_id = i.id
							left join mymes.part sp on sp.id = s.parent_id
							, mymes.identifier_links il
							where i.id = il.identifier_id
							and il.row_type = 'work_report'
							and il.parent_id = ${w.id}
							group by  i.id, i.name, i.secondary, i.mac_address;`	
									
			const iden = await db.any(idsql)
			console.log('___',w,idsql,iden)				
			const identifiers = iden.map( id => ({id: id.id, name: id.name,sons: id.sons,mac_address : id.mac_address, secondary : id.secondary }))
			return {...w, identifiers}
		}))

		const data = {
			date : date,
			data: lines
		}

		if (lines.length) {

			res.status(200).json(data)

			const ids = lines.map(x=>x.id).toString()

			sql = `update mymes.work_report
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

const exportFaults = async (req,res) => {

	const option = {year:'2-digit', month: '2-digit', day: "2-digit" }
	const date = new Date().toLocaleDateString("he",option).replace(/-/g,'/')

	let sql_fault =`select f.id as id ,extserial as serialname,rg.extname as locname,f.quant, loc.location, ft.name fault_type,
					fix.name as fix, 
						fs.sendable, 'fault' as row_type
					from mymes.fault  f left join mymes.locations loc on loc.id = f.location_id
						left join mymes.fix on fix.id = f.fix_id,
						mymes.serials  s, mymes.actions  a, mymes.fault_type ft, mymes.fault_status fs,
						mymes.resource_groups rg
					where a.id = f.act_id
						and rg.id = f.resource_id
						and s.id = f.serial_id
						and ft.id = f.fault_type_id
						and fs.id = f.fault_status_id				
						and extserial is not null
						and erpact is not null
						and fs.sendable = true
						and (sent is null or sent is false);`				
	try{
		var lines = await db.any(sql_fault)
		console.log("lines",lines)

		lines = await Promise.all(lines.map( async w => {
			const idsql = `select  il.parent_id as parent, i.id, i.name
							from mymes.identifier i, mymes.identifier_links il
							where i.id = il.identifier_id
							and row_type = 'fault'
							and il.parent_id = ${w.id};`				
			const iden = await db.any(idsql)
			const identifiers = iden.map( id => ({id: id.id, name: id.name}))
			return {...w, identifiers}
		}))

		console.log(lines)
		
		const data = {
			date : date,
			faults : lines,
		}

		if (lines.length) {

			res.status(200).json(data)
		
			var ids = lines.map(x=>x.id).toString()

			sql = `update mymes.fault
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

const aline = async (aline,serial_id) => {
	return aline && aline.map(async (al) => {
		console.log("in aline:",al,serial_id)
		let wr_id = 0;
		const wr_param = {
			serialname : al.SERIALNAME,
			actname : al.ACTNAME,
			quant : al.QUANT,
			row_type : 'work_report',
			sent : true,
			approved : true,
			sig_date: 0,
			sig_user : 'ERP',
			resourcename : 'ERP'
		}	

		try {

			console.log("INSERT WO _  ",wr_param)
			wr_id = await insert({body : wr_param},null,'work_report',true) //await InsertToTables(wr_param,wr_schema)
			console.log("INSERT WO _ 2",wr_id)
		}catch(e){
			throw new Error(`there was aproblem inseting a work report  ${al.SERIALNAME}:${al.ACTNAME} :: ${e}`)
		}
					

		if (al.IDENTIFIERS && al.IDENTIFIERS !== 'NONE' ) {
	
			const identifiers = al.IDENTIFIERS.map(idn =>({identifier : idn.SERNUM , parent : wr_id, parent_schema : 'work_report'})) 
			try{
				const ret = await batchInsert_(identifiers,'identifier')
			}catch(e){throw new Error(`Error in inserting work report identifiers: ${e}`)}
		}
		return wr_id

	})
}

const importSerial = (req,res) => {
	const part_schema = parts.schema
	//const serial_schema = serials
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
	    	console.warn('all ready exists',serial_id,part_id)
			serial.KIT = serial.KIT && serial.KIT.map(x => ({ lang_id: 1,lot: x.LOT, partname: x.PARTNAME, quant: x.QUANT,  parent : serial_id}))
			//const kit = serial.KIT && serial.KIT.length ? await Promise.all( await batchInsert_(serial.KIT,'kit')) : []	
			const aline1 = await aline(serial.ALINE,serial.SERIAL.SERIALNAME)

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
				const aline1 = await aline(serial.ALINE,serial_id)
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
	exportFaults,
    approveWorkReports
  }