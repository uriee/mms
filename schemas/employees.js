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
exports.employees = {
		sql: {
			all: `select employees.id, employees.name , employees.active as active, employees_t.fname, employees_t.sname, 
				ap.name as ap_name, usr.username as user_name, employees.tags, 
				employees.id_n, employees.clock_n, employees.salary_n, pos.name as position_name, employees.delivery_method ,employees.email, employees.phone
				from mymes.employees as employees
				 left join mymes.employees_t as employees_t on employees.id = employees_t.emp_id 
				 left join mymes.positions as pos on employees.position_id = pos.id 
				 left join users as usr on usr.id = employees.user_id,
				mymes.availability_profiles as ap 
				where employees.availability_profile_id = ap.id
				and employees_t.lang_id = $1`,				

			choosers :{
				users: `select username as name from users where not exists(select 1 from mymes.employees where user_id = users.id);`,
				availability_profiles: `select name from mymes.availability_profiles;`,
				positions: `select name from mymes.positions;`,				
			},

		},

		schema: {
			pkey: 'emp_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},
				user_id: {
					query : `select id from users where username = $1;`,
					 value : 'user_name'
					},
				availability_profile_id: {
					query : `select id from mymes.availability_profiles where name = $1;`,
					 value : 'ap_name'
					},
				position_id: {
					query : `select id from mymes.positions where name = $1;`,
					 value : 'position_name'
					}										
			},

			tables : {
				employees :{
					fields : [
						{
							field: 'user_id',
							fkey : 'user_id'
						},
						{
							field: 'position_id',
							fkey : 'position_id'
						},						
						{
							field: 'availability_profile_id',
							table: 'ap',
							filterField : 'name',
							filterValue: 'ap_name',
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
							field: 'id_n',
							variable : 'id_n'
						},
						{
							field: 'clock_n',
							variable : 'clock_n'
						},
						{
							field: 'salary_n',
							variable : 'salary_n'
						},
						{
							"field": "tags",
							"variable" : "tags"
						},						
						{
							field: 'row_type',
							variable : 'row_type',
							value : 'employees'
						},
						{
							field: 'delivery_method',
							variable : 'delivery_method'						
						},
						{
							field: 'email',
							variable : 'email'						
						},
						{
							field: 'phone',
							variable : 'phone',							
						},
						{
							key: 'id'
						}
				   ]
				},
				employees_t :{
					fields : [
						{
							field: 'fname',
							 variable: 'fname'
							},
						{
							field: 'sname',
							 variable: 'sname'
							},
						{
							field: 'emp_id',
							 fkey :'emp_id',
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



