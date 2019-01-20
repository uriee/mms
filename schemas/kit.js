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
			all: `select kit.id, serials.name, kit.partname,  kit.quant, kit.balance, kit.lot 
					from mymes.kit as kit ,mymes.serials as serials 
					where serials.id = kit.serial_id
					and serials.name = $2 
					`,					

			choosers :{	
				
			}

		},

		schema: {
			pkey: 'serial_id' ,

			fkeys: {			

				serial_id: {
					query : `select id from mymes.serials where name = $1;`,
					 value : 'name'
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
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



