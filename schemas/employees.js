//const {conf} = require('./Conf.js')
const languagesArray = [1,2,3]
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
			single: `select emp.name, emp_t.fname, emp_t.sname, dept.name as dept_name, dept_t.name_t as dept_name_t, usr.usernameas,usr.last_login
				from mymes.employees as emp, mymes.users as usr , mymes.departments as dept, mymes.employees_t as emp_t, mymes.departments_t as dept_t
				where emp.user_id = usr.id
				and emp.dept_id = dept.id
				and dept_t.dept_id  = dept.id
				and emp_t.emp_id = emp.id
				and dept_t.lang_id = emp_t.lang_id
				and dept_t.lang_id = $2
				and emp.name = $1;`	,

			all: `select emp.id, emp.name, emp_t.fname, emp_t.sname, dept.name as dept_name, dept_t.name_t as dept_name_t, usr.username as user_name,usr.last_login,usr.username as key from mymes.employees as emp left join mymes.employees_t as emp_t on emp.id = emp_t.emp_id,
				mymes.users as usr ,
				mymes.departments as dept left join mymes.departments_t as dept_t on dept_t.dept_id = dept.id
				where emp.user_id = usr.id
				and emp.dept_id = dept.id
				and dept_t.lang_id = emp_t.lang_id
				and emp_t.lang_id = $1;`,

			choosers :{
				departments: `select name from mymes.departments;`,
				users: `select username as name from mymes.users;`,
			}

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
					query : `select id from mymes.users where username = $1;`,
					 value : 'user_name'
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
							field: 'name',
							variable : 'name'
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



