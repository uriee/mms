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
exports.part_status = {
		sql: {
			all: `select part_status.id, part_status.name, part_status.active, part_status.tags, part_status_t.description 
				  	from mymes.part_status as part_status left join mymes.part_status_t as part_status_t on part_status.id = part_status_t.part_status_id
					where part_status_t.lang_id = $1 `,					

			choosers :{	
	
			}

		},

		schema: {
			pkey: 'part_status_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},				
			},

			tables : {
				part_status :{
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
							value : 'part_status'
						},						
						{
							field: 'active',
							variable : 'active'
						},
						{
							key: 'id'
						}
				   ]
				},
				part_status_t :{
					fields : [
						{
							field: 'description',
							variable: 'description'
						},						
						{
							field: 'part_status_id',
							 fkey :'part_status_id',
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



