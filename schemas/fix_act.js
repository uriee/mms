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
exports.fix_actions = {
		sql: {
			all: `select fix_act.id, a.name, t.description 
					from mymes.actions as a, mymes.actions_t as t ,mymes.fix_act as fix_act
					where fix_act.action_id = a.id
					and t.action_id = a.id 
					and t.lang_id = $1
					and fix_act.fix_id = $3
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
				fix_id : {
					value : 'parent'
				},								
			},

			tables : {
				fix_act :{
					fields : [
						{
							field: 'fix_id',
							fkey : 'fix_id'
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



