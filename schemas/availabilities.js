const {languagesArray} = require('./schema_conf.js')
/*  sql : queries for fetching data
	sql.single : fetches single record
	sql.all : fetch few records
	schema: the insert/update schema for this entity
	schema.pkey : the pkey field name for this entity
	schema.fkeys : keys that need to be fetched from server in order to preform insert/update
	schema.tables : the tables that need to be updated 

*//*,json_agg(json_build_object('id', availability_profiles.id,'weekday', weekday, 'from', from_time, 'to', to_time)) as availabilities*/
exports.availabilities = {
		sql: {
			all: `select id,availability_profile_id, weekday, flag_o, from_time , to_time
			    from mymes.availabilities as availabilities
				where availabilities.availability_profile_id = $3 `,

			final: ' order by 3,4 ',				

			choosers :{
			},

		},

		schema: {
			pkey: 'availability_profile_id' ,

			fkeys: {
				availability_profile_id : {
					query : `select id from mymes.availability_profiles where id = $1;`,
					value : 'parent'
				},
				
			},

			tables : {
				availabilities :{
					fields : [
						{
							field: 'availability_profile_id',
							fkey: 'availability_profile_id'
						},
					
						{
							field: 'weekday',
							variable : 'weekday'
						},
						{
							field: 'flag_o',
							variable : 'flag_o'
						},						
						{
							field: 'from_time',
							variable : 'from_time',
							conv: '::time without time zone'
						},						
						{
							field: 'to_time',
							variable : 'to_time',
							conv : '::time'
						},
						{
							key: 'id'
						},						

				   ]
				},
			}
		}	
	}



