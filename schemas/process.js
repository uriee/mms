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
exports.process = {
		sql: {
			all: `select process.id, process.name, process.tags, process_t.description, process.active, process.erpproc
					from mymes.process as process left join mymes.process_t as process_t on process.id = process_t.process_id 
					where process_t.lang_id = $1 `,					

			choosers :{	
			}

		},

		schema: {
			pkey: 'process_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				}				
			},

			tables : {
				process :{
					fields : [
						{
							field: 'name',
							variable : 'name'
						},
						{
							field: 'active',
							variable : 'active'
						},
						{
							field: 'erpproc',
							variable : 'erpproc'
						},						
						{
							field: 'row_type',
							variable : 'row_type',
							value : 'process'
						},						
						{
							field: 'tags',
							variable : 'tags'
						},											
						{
							key: 'id'
						}
				   ]
				},
				process_t :{
					fields : [
						{
							field: 'description',
							variable: 'description'
						},
						{
							field: 'process_id',
							 fkey :'process_id',
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



