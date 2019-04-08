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
exports.sub_resources = {
		sql: {
			all: `select arc.id,son_id, son.name, t.description as desc , sord as ord , parent_id 
					from mymes.resources as son, mymes.resource_desc as t ,mymes.resource_arc as arc
					where arc.son_id = son.id
					and t.resource_id = son.id 
					and t.lang_id = $1
					and parent_id = $3 
					`,
			'final' : ' order by ord ',

			choosers :{	
				resources: `select name,description from mymes.resources, mymes.resource_desc where resource_id = id and lang_id= $1;`	
			}

		},

		schema: {
			pkey: 'id' ,

			fkeys: {	
			},

			tables : {
				resource_arc :{
					fields : [
						{
							field: 'son_id',
							variable : 'son_id'
						},			
						{
							field: 'parent_id',
							variable : 'parent_id'
						},	
						{
							field: 'sord',
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



