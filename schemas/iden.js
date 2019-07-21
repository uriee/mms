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
			all: `select id,name, created_at from mymes.identifier as iden where 1=1  `	,		
			final: ` order by created_at desc `,

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
							fkey : 'act_id',
							table: 'action',
							filterField : 'name',
							filterValue: 'act_name',							
						},
						{
							field: 'sig_user',
							fkey : 'sig_user'
						},
						{
							"field": "sig_date",
							"variable" : "sig_date",
							table: 'users',
							filterField : 'username',
							filterValue: 'user_name',							
						},												
						{
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



