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
exports.act_resources = {
		sql: {
			all: `select act_resources.id, act_resources.resource_id, r.name, t.description , act_resources.ord as ord , act_id
					from mymes.resources as r, mymes.resource_desc as t ,mymes.act_resources as act_resources
					where act_resources.resource_id = r.id
					and t.resource_id = r.id 
					and t.lang_id = $1
					and act_id = $3
					`,
			'final' : ' order by ord ',

			choosers :{	
				resources: `select name,description from mymes.resources, mymes.resource_desc where resource_id = id and lang_id= $1;`	
			}

		},

		schema: {
			pkey: 'id' ,

			fkeys: {
				resource_id: {
					query : `select id from mymes.resources where name = $1;`,
					 value : 'name'
					},
				act_id : {
					value : 'parent'
				},
				type : {
					value : 'type'
				},									
			},

			tables : {
				act_resources :{
					fields : [
						{
							field: 'resource_id',
							fkey : 'resource_id'
						},			
						{
							field: 'act_id',
							fkey : 'act_id'
						},	
						{
							field: 'type',
							fkey : 'type'
						},						
						{
							field: 'ord',
							variable : 'ord'
						},															
						{
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



