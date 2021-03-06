const {languagesArray} = require('./schema_conf.js')
/*  sql : queries for fetching data
	sql.single : fetches single record
	sql.all : fetch few records
	schema: the insert/update schema for this entity
	schema.pkey : the pkey field name for this entity
	schema.fkeys : keys that need to be fetched from server in order to preform insert/update
	schema.tables : the tables that need to be updated 

*//*,json_agg(json_build_object('id', resources.id,'flag_o', flag_o, 'from', from_date, 'to', to_date)) as resource_timeoff*/
const ts_range = (text) => text.replace('{','[').replace('}',')')

exports.employee_timeoff = {
		sql: {
			all: `select resource_timeoff.id,resource_id, flag_o , from_date , to_date, ts_range , approval, request, approved_by 
			    from mymes.resource_timeoff as resource_timeoff, users , mymes.employees as employees
				where resource_timeoff.resource_id = employees.id
				and users.id = employees.user_id
				and username = $4 `,

			final: ' order by 4 ',				

			choosers :{
			},

		},
	
		schema: {
			pkey: 'resource_id' ,

			fkeys: {
				resource_id : {
					query : `select emp.id from mymes.employees as emp ,users
							 where users.id = emp.user_id
							 and username = $1;`,
					value : 'sig_user'
				},
				
			},

			tables : {
				resource_timeoff :{
					fields : [
						{
							field: 'resource_id',
							fkey: 'resource_id'
						},
					
						{
							field: 'flag_o',
							variable : 'flag_o'
						},
						{
							field: 'from_date',
							variable : 'from_date',
							conv: '::timestamp'
						},						
						{
							field: 'to_date',
							variable : 'to_date',
							conv : '::timestamp without time zone'
						},
						{
							field: 'ts_range',
							variable : 'ts_range',
							conv : '::tsrange',
							func : ts_range
						},
						{
							field: 'approval',
							variable : 'approval',
							value : "Pending approval"
						},
						{
							field: 'request',
							variable : 'request'
						},
						{
							field: 'approved_by',
							variable : 'approved_by'
						},						
						{
							key: 'id'
						},						

				   ]
				},
			}
		}	
	}



