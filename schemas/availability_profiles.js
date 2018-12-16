const {languagesArray} = require('./schema_conf.js')
/*  sql : queries for fetching data
	sql.single : fetches single record
	sql.all : fetch few records
	schema: the insert/update schema for this entity
	schema.pkey : the pkey field name for this entity
	schema.fkeys : keys that need to be fetched from server in order to preform insert/update
	schema.tables : the tables that need to be updated 

*//*,json_agg(json_build_object('id', availability_profiles.id,'weekday', weekday, 'from', from_time, 'to', to_time)) as availabilities*/
exports.availability_profiles = {
		sql: {
			all: `select availability_profiles.id, availability_profiles.name, availability_profiles.active , availability_profiles.tags, availability_profiles_t.description
			    from mymes.availability_profiles as availability_profiles left join mymes.availability_profiles_t as availability_profiles_t on availability_profiles.id = availability_profiles_t.ap_id  
				where availability_profiles_t.lang_id = $1 `,

			final: '',				

			choosers :{
			},

		},
		
		post_insert: {
			function: 'set_availabilities',
			parameters: ['id']
		},

		schema: {
			pkey: 'ap_id' ,

			fkeys: {
		
			},

			tables : {
				availability_profiles :{
					fields : [
					
						{
							field: 'name',
							variable : 'name'
						},
						{
							field: 'active',
							variable : 'active'
						},
						{
							"field": "tags",
							"variable" : "tags"
						},						
						{
							field: 'row_type',
							variable : 'row_type',
							value : 'availability_profile'
						},
						{
							key: 'id'
						}
				   ]
				},
				availability_profiles_t :{
					fields : [
						{
							field: 'description',
							 variable: 'description'
							},
						{
							field: 'ap_id',
							 fkey :'ap_id',
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



