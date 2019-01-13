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
exports.locations = {
		sql: {
			all: `select locations.id, serials.name, locations.partname,  locations.quant, locations.location, actions.name as act_name
					from mymes.locations as locations ,mymes.serials as serials, mymes.actions as actions
					where serials.id = locations.serial_id
					and actions.id = locations.act_id 
					`,					

			choosers :{	
				actions: `select name from mymes.actions;`,
			}

		},

		schema: {
			pkey: 'serial_id' ,

			fkeys: {			
				act_id: {
					query : `select id from mymes.actions where name = $1;`,
					 value : 'act_name'
				},
				serial_id: {
					query : `select id from mymes.serials where name = $1;`,
					 value : 'name'
				}
			},

			tables : {
				locations :{
					fields : [
						{
							field: 'serial_id',
							fkey : 'serial_id'
						},					
						{
							field: 'partname',
							variable : 'partname'
						},
						{
							field: 'quant',
							variable : 'quant'
						},						
						{
							field: 'act_id',
							fkey : 'act_id'
						},						
															
						{
							field: 'location',
							variable : 'location'
						},											
						{
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



