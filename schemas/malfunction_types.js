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
exports.malfunction_types = {
		sql: {
			all: `select malfunction_types.id, malfunction_types.name , malfunction_types_t.description  
				from mymes.malfunction_types as malfunction_types left join mymes.malfunction_types_t as malfunction_types_t on malfunction_types.id = malfunction_types_t.malfunction_type_id 
				where malfunction_types_t.lang_id = $1 `,

			choosers :{
			},

		},

		schema: {
			pkey: 'malfunction_type_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},
			},

			tables : {
				malfunction_types :{
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
				malfunction_types_t :{
					fields : [
						{
							field: 'description',
							 variable: 'description'
							},
						{
							field: 'malfunction_type_id',
							 fkey :'malfunction_type_id',
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



