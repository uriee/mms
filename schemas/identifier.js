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
exports.identifier = {
		sql: {
			all: `select identifier.id, identifier.name as identifier, wr.id as name
					from mymes.identifier as identifier ,mymes.work_report as wr
					where wr.id = identifier.work_report_id
					and wr.id = $3 
					`,					

			choosers :{	
				
			}

		},

		schema: {
			pkey: 'parent' ,

			fkeys: {			

			},

			tables : {
				identifier :{
					fields : [
						{
							field: 'work_report_id',
							variable : 'parent'
						},					
						{
							field: 'name',
							variable : 'identifier'
						},											
						{
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



