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

exports.identifier_links = {
		sql: {
			all: `select a.name as act_name ,r.name as resource_name ,s.name as serial_name, l.created_at::timestamp as created_at ,l.row_type, f.name as fault_name
			from mymes.identifier_links l left join mymes.fault f on f.id = l.parent_id and l.row_type = 'fault',
			mymes.serials s, mymes.actions a, mymes.resources r, mymes.identifiable i 
            where i.id = l.parent_id
            and s.id = l.serial_id
            and a.id = l.act_id
            and r.id = i.resource_id
            and identifier_id = $3`,

            final : ' order by created_at desc '    ,
                        
            choosers :{}
		},		

		schema: {
			pkey: 'identifier_id' ,

			fkeys: {			

			},

			tables : {
				identifier_links :{
					fields : [
						{
							field: 'parent_id',
							variable : 'parent'
						},	
						{
							field: 'row_type',
							variable : 'parent_schema'
						},
						{
							field: 'serial_id',
							variable : 'serial_id'
						},	
						{
							field: 'act_id',
							variable : 'act_id'
						},																	
						{
							field: 'identifier_id',
							fkey :'identifier_id',
							key : 'id'
						},											
				   ]
				}			
			}
		}	
	}
