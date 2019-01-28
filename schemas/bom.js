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
exports.bom = {
		sql: {
			all: `select bom.id, part.name, bom.partname, bom.coef 
					from mymes.bom as bom ,mymes.part as part 
					where part.id = bom.parent_id
					and part.id = $3 
					`,					

			choosers :{	
				
			}

		},

		schema: {
			pkey: 'parent_id' ,

			fkeys: {			

				parent_id: {
					//query : `select id from mymes.part where name = $1;`,
					 value : 'parent'
				}
			},

			tables : {
				bom :{
					fields : [
						{
							field: 'parent_id',
							fkey : 'parent_id'
						},					
						{
							field: 'partname',
							variable : 'partname'
						},
						{
							field: 'coef',
							variable : 'coef'
						},											
						{
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



