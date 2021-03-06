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
exports.equipments = {
		sql: {
			all: `select equipments.id, equipments.name , equipments.active as active, equipments_t.description,  
			ap.name as ap_name, equipments.mac_address ,equipments.tags, equipments.serial, equipments.equipment_type ,equipments.calibrated ,equipments.last_calibration 
				from mymes.equipments as equipments left join mymes.equipments_t as equipments_t on equipments.id = equipments_t.equipment_id ,
				mymes.availability_profiles as ap
				where equipments.availability_profile_id = ap.id
				and equipments_t.lang_id = $1`,				

			choosers :{
				availability_profiles: `select name from mymes.availability_profiles;`,
			},

		},

		schema: {
			pkey: 'equipment_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},
				availability_profile_id: {
					query : `select id from mymes.availability_profiles where name = $1;`,
					 value : 'ap_name'
				}					
			},

			tables : {
				equipments :{
					fields : [
						{
							field: 'availability_profile_id',
							fkey : 'availability_profile_id',
							table: 'ap',
							filterField : 'name',
							filterValue: 'ap_name',								
						},							
						{
							field: 'name',
							variable : 'name'
						},
						{
							field: 'active',
							variable : 'active'
						},
						{
							field: 'serial',
							variable : 'serial'
						},
						{
							field: 'equipment_type',
							variable : 'equipment_type'
						},
						{
							field: 'mac_address',
							variable : 'mac_address'
						},
						{
							field: 'row_type',
							variable : 'row_type',
							value : 'equipments'
						},						
						{
							"field": "tags",
							"variable" : "tags"
						},
						{
							field: 'calibrated',
							variable : 'calibrated'
						},
						{
							field: 'last_calibration',
							variable : 'last_calibration'
						},												
						{
							key: 'id'
						}
				   ]
				},
				equipments_t :{
					fields : [
						{
							field: 'description',
							 variable: 'description'
							},
						{
							field: 'equipment_id',
							 fkey :'equipment_id',
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
			},

			functions : [
				{
					name: 'Clone Equipments',
					parameteres: ['id'],
					function : 'clone_equipments'
				}
			]

		}	
	}



