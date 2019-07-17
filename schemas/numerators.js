const {languagesArray} = require('./schema_conf.js')
/*---*/
/*  sql : queries for fetching data
	sql.single : fetches single record
	sql.all : fetch few records
	schema: the insert/update schema for this entity
	schema.pkey : the pkey field row_type for this entity
	schema.fkeys : keys that need to be fetched from server in order to preform insert/update
	schema.tables : the tables that need to be updated 
*/
exports.numerators = {
		sql: {
			all: `select row_type , prefix, numerator, description,id
					from mymes.numerators 
					`,					

			choosers :{}
		},

		schema: {

			fkeys: {},

			tables : {
				numerators :{
					fields : [
						{
							field: 'row_type',
							variable : 'row_type'
						},					
						{
							field: 'prefix',
							variable : 'prefix'
						},	
						{
						    field: 'numerator',
							variable : 'numerator'
                        },
						{
						    field: 'description',
							variable : 'description'
                        },    
                        {
						    key: 'id'
						},                     
				   ]
				}
			}
		}	
	}



