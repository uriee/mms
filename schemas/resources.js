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
			all: `select resources.id, resources.name , resources.active as active, resources.type as type, dept.name as dept_name, ap.name as ap_name
				from mymes.resources as resources , mymes.availability_profiles as ap, mymes.departments as dept
				where resources.availability_profile_id = ap.id
				and resources.dept_id = dept.id` ,

			choosers :{
				departments: `select name from mymes.departments;`,
				availability_profiles: `select name from mymes.availability_profiles;`,
			},

		},

		schema: {
			pkey: 'resource_id' ,

			fkeys: {

				dept_id: {
					query : `select id from mymes.departments where name = $1;`,
					 value : 'dept_name'
					},
				availability_profile_id: {
					query : `select id from mymes.availability_profiles where name = $1;`,
					 value : 'ap_name'
					}					
			},

			tables : {
				resources :{
					fields : [
						{
							field: 'dept_id',
							fkey : 'dept_id'
							},
						{
							field: 'availability_profile_id',
							fkey : 'availability_profile_id'
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
							field: 'type',
							variable : 'type',
						},						
						{
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



