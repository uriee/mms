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
exports.fault_type_actions = {
		sql: {
			all: `select fault_type_act.id, a.name, t.description 
					from mymes.actions as a, mymes.actions_t as t ,mymes.fault_type_act as fault_type_act
					where fault_type_act.action_id = a.id
					and t.action_id = a.id 
					and t.lang_id = $1
					and fault_type_act.fault_type_id = $3
					`,
			'final' : ' order by a.name ',

			choosers :{	
				actions: `select name,description from mymes.actions a, mymes.actions_t t where t.action_id = a.id and lang_id= $1;`	
			}

		},

		schema: {
			pkey: 'id' ,

			fkeys: {
				action_id: {
					query : `select id from mymes.actions where name = $1;`,
					 value : 'name'
					},
				fault_type_id : {
					value : 'parent'
				},								
			},

			tables : {
				fault_type_act :{
					fields : [
						{
							field: 'fault_type_id',
							fkey : 'fault_type_id'
						},			
						{
							field: 'action_id',
							fkey : 'action_id'
						},																
						{
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



