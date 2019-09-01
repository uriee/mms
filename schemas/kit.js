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
exports.kit = {
		sql: {
			all: `select kit.id, kit.partname, kit.quant, kit.balance, kit.lot , kit.in_use
					from mymes.kit as kit ,mymes.serials as serials 
					where serials.id = kit.serial_id
					and serials.id = $3 
					`,					

			choosers :{	
				
			}

		},
		limit : 5000,		

		schema: {
			pkey: 'serial_id' ,

			fkeys: {			

				serial_id: {
					value : 'parent'
				}
			},

			tables : {
				kit :{
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
							field: 'balance',
							variable : 'balance'
						},	
						{
							field: 'lot',
							variable : 'lot'
						},											
						{
							field: 'in_use',
							variable : 'in_use'
						},						
						{
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



