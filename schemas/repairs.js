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
exports.repairs = {
		sql: {
			all: `select repairs.id, repairs.name ,repairs.details, rt.name as type, 
			mf.name as malfunction_name, emp.name as employee_name ,repairs.tags, repairs.start_date, repairs.end_date
				from mymes.repairs as repairs, mymes.malfunctions as mf, mymes.repair_types as rt, mymes.employees as emp 
				where repairs.employee_id = emp.id
				and repairs.repair_type_id =  rt.id
				and repairs.malfunction_id = mf.id `,

			choosers :{
				repair_types: `select name from mymes.repair_types;`,
				malfunctions: `select name from mymes.malfunctions;`,
				employees: `select name from mymes.employees;`,				
			},

		},

		schema: {
			pkey: 'repair_id' ,

			fkeys: {
				repair_type_id: {
					query : `select id from mymes.repair_types where name = $1;`,
					 value : 'type'
				},
				malfunction_id: {
					query : `select id from mymes.malfunctions where name = $1;`,
					 value : 'malfunction_name'
				},
				employee_id: {
					query : `select id from mymes.employees where name = $1;`,
					 value : 'employee_name'
				}
			},

			tables : {
				repairs :{
					fields : [
						{
							field: 'malfunction_id',
							fkey : 'malfunction_id',
							table: 'mf',
							filterField : 'name',
							filterValue: 'malfunction_name',								
						},
						{
							field: 'employee_id',
							fkey : 'employee_id',
							table: 'emp',
							filterField : 'name',
							filterValue: 'employee_name',								
						},						
						{
							field: 'repair_type_id',
							fkey : 'repair_type_id',
							table: 'rt',
							filterField : 'name',
							filterValue: 'type',								
						},							
						{
							field: 'name',
							variable : 'name'
						},
						{
							field: 'details',
							variable : 'details'
						},
						{
							field: 'start_date',
							variable : 'start_date'
						},
						{
							field: 'end_date',
							variable : 'end_date'
						},
						{
							"field": "tags",
							"variable" : "tags"
						},	
						{
							field: 'row_type',
							variable : 'row_type',
							value : 'repair'
						},											
						{
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



