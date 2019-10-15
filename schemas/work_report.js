/*  sql : queries for fetching data
	sql.single : fetches single record
	sql.all : fetch few records
	sql.choosers : queries to fetch assential data for the input forms 
	sql cascaders : an array of the choosers that have more then one dimention
	schema: the insert/update schema for this entity
	schema.pkey : the pkey field name for this entity
	schema.fkeys : keys that need to be fetched from server in order to preform insert/update
	schema.tables : the tables that need to be updated 
*/

exports.work_report = {
		sql: {
			all: `select work_report.id, work_report.quant, users.username as username , work_report.sig_date, work_report.sig_user, sa.balance as maxq , sent ,approved ,
					serial.name as serialname, action.name as actname ,resources.name as resourcename, concat(serial.name,':',action.name,'-',work_report.quant) as name ,
					sa.batch_size 
					from mymes.work_report as work_report , mymes.resources as resources, mymes.serials as serial, mymes.actions as action, users, mymes.serial_act as sa
					where serial.id = work_report.serial_id 
					and resources.id = work_report.resource_id
					and users.id = work_report.sig_user
					and action.id = work_report.act_id 
					and sa.serial_id = work_report.serial_id 
					and sa.act_id = work_report.act_id
					and (resources.id = -1 or resources.id in (select resource from user_resources_by_parent($4)))
					and ($3 = 0 or serial.id = $3) 
					`,					
			final: 'order by work_report.sig_date desc ',
			choosers :{
				resseract : `select r.name as resourcename,serial.name as serialname,act.name as actname 
							from mymes.actions as act,
							mymes.serials as serial , mymes.serial_act as seract
							join mymes.act_resources as ar on (ar.act_id = seract.id and type = 3)
							join mymes.resources as r on r.id = ar.resource_id 
							where serial.id = seract.serial_id and act.id = seract.act_id 
							and serial.active=true and act.active=true
							and r.id in (select resource from user_parent_resources($2))
							and seract.balance > 0 
							order by serial.name,seract.pos;`	,
				serial: `select name from mymes.serials where active=true order by name;`,
				act: `select name from mymes.actions where active=true order by name;`,
			},

		},

		pre_insert: {
			function: 'check_identifier_exists',
			parameters: ['serialname','actname','entity','identifier']
		},
		
		post_insert: {
			function: 'update_serial_act_balance',
			parameters: ['serialname','actname','quant']
		},
		pre_delete: {
			function: 'update_serial_act_balance',
			parameters: ['keys']
		},		

		schema: {
			pkey: 'work_report_id' ,

			fkeys: {
				serial_id: {
					query : `select id from mymes.serials where name = $1;`,
					 value : 'serialname'
				},
				act_id: {
					query : `select id from mymes.actions where name = $1;`,
					 value : 'actname'
				},
				resource_id: {
					query : `select id from mymes.resources where name = $1;`,
					 value : 'resourcename'
				},				
				sig_user: {
					query : `select id from users where username = $1;`,
					 value : 'sig_user'
				},				
			},
			chain : ['identifier'],
			tables : {
				work_report :{
					fields : [
						{
							field: 'quant',
							variable : 'quant'
						},

						{
							field: 'act_id',
							fkey : 'act_id',
							table: 'action',
							filterField : 'name',
							filterValue: 'actname',								
						},
						{
							field: 'resource_id',
							fkey : 'resource_id',
							table: 'resources',
							filterField : 'name',
							filterValue: 'resourcename',								
						},						
						{
							field: 'serial_id',
							fkey : 'serial_id'
						},																					
						{
							field: 'sig_date',
							variable : 'sig_date'
						},	
						{
							field: 'sig_user',
							fkey : 'sig_user',
							table: 'users',
							filterField : 'username',
							filterValue: 'username',	

						},
						{
							field: 'row_type',
							variable : 'row_type',
							value : 'work_report'
						},																							
						{
							key: 'id'
						}
				   ]
				},
			}
		}	
	}



