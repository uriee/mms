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
exports.repair_types = {
		sql: {
			all: `select repair_types.id, repair_types.name , repair_types_t.description  
				from mymes.repair_types as repair_types left join mymes.repair_types_t as repair_types_t on repair_types.id = repair_types_t.repair_type_id 
				where repair_types_t.lang_id = $1 `,

			choosers :{
			},

		},

		schema: {
			pkey: 'repair_type_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},
			},

			tables : {
				repair_types :{
					fields : [
			
						{
							field: 'name',
							variable : 'name'
						},
						{
							key: 'id'
						}
				   ]
				},
				repair_types_t :{
					fields : [
						{
							field: 'description',
							 variable: 'description'
							},
						{
							field: 'repair_type_id',
							 fkey :'repair_type_id',
							 key: 'id'},
						{
							field: 'lang_id',
							 fkey :'lang_id',
							  key: 'lang_id'
							},
					],
					fill: {
						field : 'lang_id',
						values : languagesArray
					}
				}
			}
		}	
	}



