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
exports.malfunctions = {
		sql: {
			all: `select malfunctions.id, malfunctions.name , malfunctions.status, malfunctions_t.description, mt.name as type, 
			eq.name as equipment_name, malfunctions.status ,malfunctions.tags, malfunctions.open_date, malfunctions.close_date, malfunctions.dead 
				from mymes.malfunctions as malfunctions left join mymes.malfunctions_t as malfunctions_t on malfunctions.id = malfunctions_t.malfunction_id ,
				mymes.equipments as eq, mymes.malfunction_types as mt
				where malfunctions.equipment_id = eq.id
				and malfunctions.malfunction_type_id =  mt.id
				and malfunctions_t.lang_id = $1 `,

			choosers :{
				malfunction_types: `select name from mymes.malfunction_types;`,
				equipments: `select name from mymes.equipments;`,
			},

		},

		schema: {
			pkey: 'malfunction_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},
				malfunction_type_id: {
					query : `select id from mymes.malfunction_types where name = $1;`,
					 value : 'type'
				},
				equipment_id: {
					query : `select id from mymes.equipments where name = $1;`,
					 value : 'equipment_name'
				}					
			},

			tables : {
				malfunctions :{
					fields : [
						{
							field: 'equipment_id',
							fkey : 'equipment_id',
							table: 'eq',
							filterField : 'name',
							filterValue: 'equipment_name',								
						},
						{
							field: 'malfunction_type_id',
							fkey : 'malfunction_type_id',
							table: 'mt',
							filterField : 'name',
							filterValue: 'type',								
						},							
						{
							field: 'name',
							variable : 'name'
						},
						{
							field: 'status',
							variable : 'status'
						},
						{
							field: 'open_date',
							variable : 'open_date'
						},
						{
							field: 'close_date',
							variable : 'close_date'
						},
						{
							field: 'dead',
							variable : 'dead'
						},
						{
							"field": "tags",
							"variable" : "tags"
						},	
						{
							field: 'row_type',
							variable : 'row_type',
							value : 'malfunctions'
						},
						{
							key: 'id'
						}
				   ]
				},
				malfunctions_t :{
					fields : [
						{
							field: 'description',
							 variable: 'description'
							},
						{
							field: 'malfunction_id',
							 fkey :'malfunction_id',
							 key: 'id'},
						{
							field: 'lang_id',
							 fkey :'lang_id',
							  key: 'lang_id'
							},
					],
					fill: {
						field : 'lang_id',
						values : languagesArray
					}
				}
			}
		}	
	}



