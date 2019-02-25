const {languagesArray} = require('./schema_conf.js')
/*  sql : queries for fetching data
	sql.single : fetches single record
	sql.all : fetch few records
	schema: the insert/update schema for this entity
	schema.pkey : the pkey field name for this entity
	schema.fkeys : keys that need to be fetched from server in order to preform insert/update
	schema.tables : the tables that need to be updated 

*//*,json_agg(json_build_object('id', resources.id,'flag_o', flag_o, 'from', from_date, 'to', to_date)) as resource_timeoff*/
exports.resource_timeoff = {
		sql: {
			all: `select id,resource_id, flag_o , from_date , to_date
			    from mymes.resource_timeoff as resource_timeoff
				where resource_timeoff.resource_id = $3 `,

			final: ' order by 3,4 ',				

			choosers :{
			},

		},

		post_insert: {
			function: 'cpy_resource_timeoffs',
			parameters: ['id']
		},	
		pre_delete: {
			function: 'delete_resource_timeoffs',
			parameters: ['keys']
		},			

		schema: {
			pkey: 'resource_id' ,

			fkeys: {
				resource_id : {
					query : `select id from mymes.resources where id = $1;`,
					value : 'parent'
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
							key: 'id'
						},						

				   ]
				},
			}
		}	
	}



