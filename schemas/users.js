/*  sql : queries for fetching data
	sql.single : fetches single record
	sql.all : fetch few records
	schema: the insert/update schema for this entity
	schema.pkey : the pkey field name for this entity
	schema.fkeys : keys that need to be fetched from server in order to preform insert/update
	schema.tables : the tables that need to be updated 
*/
exports.users = {
		sql: {
			all: `select  users.id as key, users.id, username as name, profile.name as "currentAuthority", users.email, users.title, users.created_at, ws.name as ws_name, users.tags
					from mymes.users as users left join mymes.profiles as profile on users.profile_id = profile.id
					left join mymes.work_spaces as ws on users.ws = ws.id where 1=1 `,				

			choosers :{
				profiles: `select name from mymes.profiles;`,
				ws: `select name from mymes.work_spaces;`,				
			},
		},

		schema: {
			pkey: 'user_id' ,

			fkeys: {

				profile_id: {
					query : `select id from mymes.profiles where name = $1;`,
					 value : 'currentAuthority'
					},
				ws_id: {
					query : `select id from mymes.profiles where name = $1;`,
					 value : 'ws_name'
					},					
			},

			tables : {
				users :{
					fields : [
						{
							field: 'profile_id',
							 fkey : 'profile_id'
							},
						{
							field: 'ws_id',
							 fkey : 'ws_id'
							},							
						{
							field: 'username',
							variable : 'name'
						},
						{
							field: 'title',
							variable : 'title'
						},
						{
							"field": "email",
							"variable" : "email"
						},
	
						{
							"field": "created_at",
							"variable" : "created_at"
						},
						{
							"field": "tags",
							"variable" : "tags"
						},						
						{
							"key": "id"
						}
				   ]
				},
			}
		}	
	}



