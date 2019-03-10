const {languagesArray} = require('./schema_conf.js')
/*  sql : queries for fetching data
	sql.single : fetches single record
	sql.all : fetch few records
	schema: the insert/update schema for this entity
	schema.pkey : the pkey field name for this entity
	schema.fkeys : keys that need to be fetched from server in order to preform insert/update
	schema.tables : the tables that need to be updated 
*/	
exports.mnt_plan_items = {
		sql: {
			all: `select mnt_plan_items.id, mnt_plans.name as name, resources.name as resource_name
			    from mymes.mnt_plan_items as mnt_plan_items, mymes.mnt_plans as mnt_plans, mymes.resources as resources 
				where mnt_plan_items.mnt_plan_id = mnt_plans.id 
				and mnt_plan_items.resource_id = resources.id and mnt_plans.id = $2 `,
			final: ' order by 2,3 ',				

			choosers :{
				resources: `select name from mymes.resources;`,
				mnt_plans: `select name from mymes.mnt_plans;`
			},

		},
		schema: {
			pkey: 'mnt_plan_id' ,

			fkeys: {
				resource_id: {
					query : `select id from mymes.resources where name = $1;`,
					 value : 'resource_name'
					},
				mnt_plan_id: {
					query : `select id from mymes.mnt_plans where name = $1;`,
					 value : 'parent'
					},				
			},

			tables : {
				mnt_plan_items :{
					fields : [
						{
							field: 'resource_id',
							fkey: 'resource_id',
							table: 'resources',
							filterField : 'name',
							filterValue: 'resource_name',								
						},
						{
							field: 'mnt_plan_id',
							fkey: 'mnt_plan_id'
						},						
						{
							key: 'id'
						},						

				   ]
				},
			}
		}	
	}



