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
			all: `select locations.id, part.id as parent, locations.partname,  locations.quant, locations.location, actions.name as act_name,
					locations.x, locations.y, locations.z 
					from mymes.locations as locations left join mymes.actions as actions on locations.act_id = actions.id,
					mymes.part as part
					where part.id = locations.part_id
					and part.id = $3 
					`,					

			choosers :{	
				actions: `select name from mymes.actions;`,
			}

		},
		limit : 5000,
		schema: {
			pkey: 'part_id' ,

			fkeys: {			
				act_id: {
					query : `select id from mymes.actions where name = $1;`,
					value : 'act_name'
				},
				part_id: {
					value : 'parent'
				}
			},

			tables : {
				locations :{
					fields : [
						{
							field: 'part_id',
							fkey : 'part_id'
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
							fkey : 'act_id',
							table: 'actions',
							filterField : 'name',
							filterValue: 'act_name',							
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
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



