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
			all: `select availabilities.id,availabilities.availability_profile_id, availability_profiles.name , weekday , from_time , to_time
			    from mymes.availability_profiles as availability_profiles , mymes.availabilities as availabilities
				where availability_profile_id = availability_profiles.id `,

			final: ' order by 3,4 ',				

			choosers :{
			},

		},

		schema: {
			pkey: 'availability_profiles_id' ,

			fkeys: {
				availability_profiles_id : {
					value : 'availability_profiles_id'
				},
				
			},

			tables : {
				availabilities :{
					fields : [
						{
							field: 'availability_profiles_id',
							fkey: 'availability_profiles_id'
						},
					
						{
							field: 'weekday',
							variable : 'weekday'
						},
						{
							field: 'from_time',
							variable : 'from_time'
						},						
						{
							field: 'to_time',
							variable : 'to_time'
						},
						{
							key: 'id'
						},						

				   ]
				},
			}
		}	
	}



