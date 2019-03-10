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
			all: `select work_report.id, work_report.quant, users.username as username , work_report.sig_date, work_report.sig_user, sa.balance as maxq ,
					serial.name as serialname, action.name as actname ,concat(serial.name,':',action.name,'-',work_report.quant) as name
					from mymes.work_report as work_report , mymes.serials as serial, mymes.actions as action, users, mymes.serial_act as sa
					where serial.id = work_report.serial_id 
					and users.id = work_report.sig_user
					and action.id = work_report.act_id 
					and sa.serial_id = work_report.serial_id 
					and sa.act_id = work_report.act_id
					and ($3 = 0 or serial.id = $3) 
					`,					
			final: 'order by work_report.sig_date desc ',
			choosers :{
				seract : `select serial.name as serialname,act.name as actname
						  from mymes.serials as serial,mymes.actions as act, mymes.serial_act as sa 
						  where serial.id = sa.serial_id and act.id = sa.act_id 
						  and serial.active=true and act.active=true 
						  order by serial.name,sa.pos;`	,
				serial: `select name from mymes.serials where active=true order by name;`,
				act: `select name from mymes.actions where active=true order by name;`,
			},

		},

		pre_insert: {
			function: 'check_serial_act_balance',
			parameters: ['serialname','actname','quant']
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
			pkey: 'serial_id' ,

			fkeys: {
				serial_id: {
					query : `select id from mymes.serials where name = $1;`,
					 value : 'serialname'
				},
				act_id: {
					query : `select id from mymes.actions where name = $1;`,
					 value : 'actname'
				},
				sig_user: {
					query : `select id from users where username = $1;`,
					 value : 'sig_user'
				},				
			},

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
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



