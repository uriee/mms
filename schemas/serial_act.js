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
exports.serial_act = {
		sql: {
			all: `select serial_act.id, serial.name, serial_act.pos, actions.name as act_name
					from mymes.serial_act as serial_act ,mymes.serials as serial, mymes.actions as actions
					where serial.id = serial_act.serial_id
					and actions.id = serial_act.act_id 
					and serial.name = $2 
					`,
			'final' : ' order by pos ',

			choosers :{	
				actions: `select name from mymes.actions;`,
				serial: `select name from mymes.serials;`,				
			}

		},

		schema: {
			pkey: 'serial_id' ,

			fkeys: {			
				act_id: {
					query : `select id from mymes.actions where name = $1;`,
					 value : 'act_name'
				},
				serial_id: {
					query : `select id from mymes.serials where name = $1;`,
					 value : 'name'
				}
			},

			tables : {
				serial_act :{
					fields : [
						{
							field: 'serial_id',
							fkey : 'serial_id'
						},					
						{
							field: 'pos',
							variable : 'pos'
						},					
						{
							field: 'act_id',
							fkey : 'act_id'
						},											
						{
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



