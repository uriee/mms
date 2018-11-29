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
exports.machines = {
		sql: {
			all: `select machines.id, machines.name , machines.active as active, machines_t.description, dept.name as dept_name,ap.name as ap_name, machines.mac_address 
				from mymes.machines as machines left join mymes.machines_t as machines_t on machines.id = machines_t.machine_id ,
				mymes.availability_profiles as ap, mymes.departments as dept
				where machines.availability_profile_id = ap.id
				and machines.dept_id = dept.id
				and machines_t.lang_id = $1`,				

			choosers :{
				departments: `select name from mymes.departments;`,
				availability_profiles: `select name from mymes.availability_profiles;`,
			},

		},

		schema: {
			pkey: 'machine_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},
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
				machines :{
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
							field: 'mac_address',
							variable : 'mac_address'
						},
						{
							field: 'type',
							variable : 'type',
							value : 'machine'
						},						
						{
							key: 'id'
						}
				   ]
				},
				machines_t :{
					fields : [
						{
							field: 'description',
							 variable: 'description'
							},
						{
							field: 'machine_id',
							 fkey :'machine_id',
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



