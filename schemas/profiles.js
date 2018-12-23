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
exports.profiles = {
		public: true,
		
		sql: {
			all: `select profiles.id, profiles.name, profiles.active, profiles_t.description 
					from profiles as profiles left join profiles_t as profiles_t on profiles.id = profiles_t.profile_id 
					where profiles_t.lang_id = $1 `,					

			choosers :{
				
			}

		},

		schema: {
			pkey: 'profile_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},
			},

			tables : {
				profiles :{
					fields : [
						{
							field: 'active',
							variable : 'active'
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
				profiles_t :{
					fields : [
						{
							field: 'description',
							variable: 'description'
							},
						{
							field: 'profile_id',
							 fkey :'profile_id',
							 key: 'id'},
						{
							field: 'lang_id',
							 fkey :'lang_id',
							  key: 'lang_id'
						}

					],
					fill: {
						field : 'lang_id',
						values : languagesArray
					}
				}
			}
		}	
	}



