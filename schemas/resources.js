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
exports.resources = {
		sql: {
			all: `select resources.id, resources.name , resources.active as active, resources.row_type as type,  ap.name as ap_name , dragable 
				from mymes.resources as resources , mymes.availability_profiles as ap
				where resources.availability_profile_id = ap.id` ,

			choosers :{
				availability_profiles: `select name from mymes.availability_profiles;`,
			},

		},

		schema: {
			pkey: 'resource_id' ,

			fkeys: {

				availability_profile_id: {
					query : `select id from mymes.availability_profiles where name = $1;`,
					 value : 'ap_name'
					}					
			},

			tables : {
				resources :{
					fields : [
						{
							field: 'availability_profile_id',
							fkey : 'availability_profile_id',
							table: 'ap',
							filterField : 'name',
							filterValue: 'ap_name',								
						},							
						{
							field: 'name',
							variable : 'name'
						},
						{
							field: 'active',
							variable : 'active'
						},
						{
							field: 'row_type',
							variable : 'type',
						},
						{
							field: 'dragable',
							variable : 'dragable',
						},
						{
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



