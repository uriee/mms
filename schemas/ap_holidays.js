const {languagesArray} = require('./schema_conf.js')
/*  sql : queries for fetching data
	sql.single : fetches single record
	sql.all : fetch few records
	schema: the insert/update schema for this entity
	schema.pkey : the pkey field name for this entity
	schema.fkeys : keys that need to be fetched from server in order to preform insert/update
	schema.tables : the tables that need to be updated 

*//*,json_agg(json_build_object('id', availability_profiles.id,'flag_o', flag_o, 'from', from_date, 'to', to_date)) as ap_holidays*/
exports.ap_holidays = {
		sql: {
			all: `select id,availability_profile_id, flag_o , from_date , to_date
			    from mymes.ap_holidays as ap_holidays
				where ap_holidays.availability_profile_id = $3 `,

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
				ap_holidays :{
					fields : [
						{
							field: 'availability_profile_id',
							fkey: 'availability_profile_id'
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



