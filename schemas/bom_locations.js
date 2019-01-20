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
exports.bom_locations = {
		sql: {
			all: `select locations.id, part.name, locations.partname,  locations.quant, locations.location, actions.name as act_name,
					locations.x, locations.y, locations.z ,locations.is_serial 
					from mymes.locations as locations ,mymes.part as part, mymes.actions as actions
					where part.id = locations.serial_id
					and actions.id = locations.act_id 
					and is_serial is null
					and part.name = $2 
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
					query : `select id from mymes.part where name = $1;`,
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
							field: 'x',
							variable : 'x'
						},
						{																							
							field: 'y',
							variable : 'y'
						},
						{				
							field: 'z',
							variable : 'z'
						},
						{
							field: 'is_serial',
							variable: 'is_serial',
							value: false
						},						
						{
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



