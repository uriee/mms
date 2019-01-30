const {languagesArray} = require('./schema_conf.js')
/*---*/
/*  sql : queries for fetching data
	sql.single : fetches single record
	sql.all : fetch few records
	schema: the insert/update schema for this entity
	schema.pkey : the pkey field name for this entity
	schema.fkeys : keys that need to be fetched from server in order to preform insert/update
	schema.tables : the tables that need to be updated 
*/
exports.iden = {
		sql: {
			all: `select iden.id, iden.name ,serial.name as serial_name, action.name as act_name , username as user_name, wr.sig_date
				from mymes.identifier iden, mymes.serials as serial, mymes.actions as action, mymes.work_report as wr , users
				where wr.serial_id = serial.id
				and wr.act_id =  action.id
				and wr.sig_user = users.id
				and iden.work_report_id = wr.id
				and ($3 = 0 or serial.id = $3) `,

			choosers :{
			
			},

		},

		schema: {
			pkey: '' ,

			fkeys: {
				sig_user_id: {
					query : `select id from users where name = $1;`,
					 value : 'user_name'
				},
				act_id: {
					query : `select id from mymes.actions where name = $1;`,
					 value : 'act_name'
				},
				serial_id: {
					query : `select id from mymes.serials where name = $1;`,
					 value : 'serial_name'
				},				
			},

			tables : {
				iden :{
					fields : [						
						{
							field: 'name',
							variable : 'name'
						},
						{
							field: 'serial_id',
							fkey : 'serial_id'
						},
						{
							field: 'act_id',
							fkey : 'act_id'
						},
						{
							field: 'sig_user',
							fkey : 'sig_user'
						},
						{
							"field": "sig_date",
							"variable" : "sig_date"
						},												
						{
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



