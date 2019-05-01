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
exports.serial_statuses = {
		sql: {
			all: `select serial_statuses.id, serial_statuses.name, serial_statuses.active, serial_statuses.closed, serial_statuses.tags, serial_statuses_t.description 
				  	from mymes.serial_statuses as serial_statuses left join mymes.serial_statuses_t as serial_statuses_t on serial_statuses.id = serial_statuses_t.serial_status_id
					where serial_statuses_t.lang_id = $1 `,					

			choosers :{	
	
			}

		},

		schema: {
			pkey: 'serial_status_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},				
			},

			tables : {
				serial_statuses :{
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
							value : 'serial_status'
						},						
						{
							field: 'active',
							variable : 'active'
						},
						{
							field: 'closed',
							variable : 'closed'
						},						
						{
							key: 'id'
						}
				   ]
				},
				serial_statuses_t :{
					fields : [
						{
							field: 'description',
							variable: 'description'
						},						
						{
							field: 'serial_status_id',
							 fkey :'serial_status_id',
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



