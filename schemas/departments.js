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
exports.departments = {
		sql: {
			all: `select departments.id,name,tags,description from mymes.departments as departments, mymes.departments_t as departments_t
					where departments_t.dept_id = departments.id
					and departments_t.lang_id = $1`,					
			choosers :{
				}

		},

		schema: {
			pkey: 'dept_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},
			},

			tables : {
				departments :{
					fields : [
						{
							field: 'name',
							variable : 'name'
						},
						{
							field: 'tags',
							variable : 'tags'
						},
						{
							field: 'row_type',
							variable : 'row_type',
							value : 'dept'
						},						
						{
							key: 'id'
						}
				   ]
				},
				departments_t :{
					fields : [
						{
							field: 'description',
							variable: 'description'
							},
						{
							field: 'dept_id',
							 fkey :'dept_id',
							 key: 'id'
						},
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



