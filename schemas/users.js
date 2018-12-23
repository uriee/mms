/*  sql : queries for fetching data
	sql.single : fetches single record
	sql.all : fetch few records
	schema: the insert/update schema for this entity
	schema.pkey : the pkey field name for this entity
	schema.fkeys : keys that need to be fetched from server in order to preform insert/update
	schema.tables : the tables that need to be updated 
*/
exports.users = {
		public: true,		

		sql: {
			all: `select  users.id as key, users.id, username as name, profile.name as "currentAuthority", users.email, users.title, users.created_at, users.tags
					from users as users left join profiles as profile on users.profile_id = profile.id
					where 1=1 `,				

			choosers :{
				profiles: `select name from profiles where active = true;`,
			},
		},

		schema: {

			pkey: 'user_id' ,

			fkeys: {

				profile_id: {
					query : `select id from profiles where name = $1;`,
					 value : 'currentAuthority'
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



