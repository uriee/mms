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
exports.preferences = {
		sql: {
			all: `select preferences.id, preferences.name , preferences.description,preferences.value
					from mymes.preferences 
					`,					

			choosers :{	
				
			}

		},

		schema: {

			fkeys: {			

			},

			tables : {
				preferences :{
					fields : [
						{
							field: 'name',
							variable : 'name'
						},					
						{
							field: 'description',
							variable : 'description'
						},	
						{
						    field: 'value',
							variable : 'value'
						},
						{
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



