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
exports.proc_act = {
		sql: {
			all: `select proc_act.id, process.name, proc_act.pos, actions.name as act_name
					from mymes.proc_act as proc_act ,mymes.process as process, mymes.actions as actions
					where process.id = proc_act.process_id
					and actions.id = proc_act.act_id 
					and process.id = $3 
					`,
			'final' : ' order by pos ',

			choosers :{	
				actions: `select name from mymes.actions;`,
				process: `select name from mymes.process;`,				
			}

		},

		schema: {
			pkey: 'process_id' ,

			fkeys: {			
				act_id: {
					query : `select id from mymes.actions where name = $1;`,
					 value : 'act_name'
				},
				process_id: {
					value : 'parent'
				}
			},

			tables : {
				proc_act :{
					fields : [
						{
							field: 'process_id',
							fkey : 'process_id',
							table: 'actions',
							filterField : 'name',
							filterValue: 'act_name',								
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



