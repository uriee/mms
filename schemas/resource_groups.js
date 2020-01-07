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
exports.resource_groups = {
		sql: {
			all: `select resource_groups.id, resource_groups.name , resource_groups.active , resource_groups_t.description, resource_groups.active , resource_groups.tags, 
			    ap.name as ap_name, array_agg(resources.name) as resource_names,array_agg(resources.row_type) as resource_types , extname
				from mymes.resource_groups as resource_groups left join mymes.resource_groups_t as resource_groups_t on resource_groups.id = resource_groups_t.resource_group_id
				left join mymes.resources as resources on resources.id = any(resource_groups.resource_ids),
				mymes.availability_profiles as ap
				where resource_groups.availability_profile_id = ap.id
				and resource_groups_t.lang_id = $1 `,

			final: ' group by 1,2,3,4,5,6,7 ',				

			choosers :{
				availability_profiles: `select name from mymes.availability_profiles;`,
				resources: `select name,description from mymes.resources, mymes.resource_desc where resource_id = id and lang_id= $1;`
			},

		},

		schema: {
			pkey: 'resource_group_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},
				resource_ids: {

					query: `select id from mymes.resources where name::text = any(string_to_array(trim($1,'{}'),','));`,
					value: 'resource_names',
					array: true
				},
				availability_profile_id: {
					query : `select id from mymes.availability_profiles where name = $1;`,
					 value : 'ap_name'
					}					
			},

			tables : {
				resource_groups :{
					fields : [
						{
							field: 'availability_profile_id',
							fkey : 'availability_profile_id',
							table: 'ap',
							filterField : 'name',
							filterValue: 'ap_name',								
						},							
						{
							field: 'name',
							variable : 'name'
						},
						{
							field: 'active',
							variable : 'active'
						},
						{
							field: 'extname',
							variable : 'extname'
						},						
						{
							field: 'row_type',
							variable : 'row_type',
							value : 'resource_groups'
						},	
						{
							field: 'resource_ids',
							fkey : 'resource_ids',
						},
						{
							"field": "tags",
							"variable" : "tags"
						},	
						{
							key: 'id'
						}
				   ]
				},
				resource_groups_t :{
					fields : [
						{
							field: 'description',
							 variable: 'description'
							},
						{
							field: 'resource_group_id',
							 fkey :'resource_group_id',
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
			},
			functions : [
				{
					name: 'Clone Resource Group',
					parameteres: ['id'],
					function : 'clone_resource_groups'
				}
			]			
		}	
	}



