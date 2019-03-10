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
				dept.name as dept_name,ap.name as ap_name, usr.username as user_name, employees.tags,
				employees.id_n, employees.clock_n, employees.salary_n, employees.manager, employees.delivery_method ,employees.email, employees.phone
				from mymes.employees as employees left join mymes.employees_t as employees_t on employees.id = employees_t.emp_id 
				left join users as usr on usr.id = employees.user_id,
				mymes.availability_profiles as ap, mymes.departments as dept
				where employees.availability_profile_id = ap.id
				and employees.dept_id = dept.id
				and employees_t.lang_id = $1`,				

			choosers :{
				departments: `select name from mymes.departments;`,
				users: `select username as name from users where not exists(select 1 from mymes.employees where user_id = users.id);`,
				availability_profiles: `select name from mymes.availability_profiles;`,
			},

		},

		schema: {
			pkey: 'emp_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},
				dept_id: {
					query : `select id from mymes.departments where name = $1;`,
					 value : 'dept_name'
					},
				user_id: {
					query : `select id from users where username = $1;`,
					 value : 'user_name'
					},
				availability_profile_id: {
					query : `select id from mymes.availability_profiles where name = $1;`,
					 value : 'ap_name'
					}					
			},

			tables : {
				employees :{
					fields : [
						{
							field: 'dept_id',
							fkey : 'dept_id'
							},
						{
							field: 'user_id',
							fkey : 'user_id'
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
							value : 'employee'
						},
						{
							field: 'delivery_method',
							variable : 'delivery_method'						
						},
						{
							field: 'manager',
							variable : 'manager',							
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



