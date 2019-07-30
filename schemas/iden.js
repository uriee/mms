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
exports.iden = {
		sql: {
			all: `select i.id,i.name, i.created_at, p.name as parent_name , part.name as part_name, pp.name as partname
				  from mymes.identifier i left join mymes.identifier p on p.id = i.parent_Identifier_id
				  left join mymes.part pp on pp.id = p.parent_id,
				  mymes.part as part
				  where part.id = i.parent_id  `	,		
			final: ` order by i.created_at desc `,

			choosers :{
			
			},

		},

		schema: {
			pkey: '' ,

			fkeys: {
				parent_identifier_id: {
					query : `select id from mymes.identifier where name = $1;`,
					 value : 'parent_name',
					 default : null
                },				
			},

			tables : {
				identifier :{
					fields : [						
						{
							field: 'parent_identifier_id',
							fkey : 'parent_identifier_id'
						},																		
						{
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



