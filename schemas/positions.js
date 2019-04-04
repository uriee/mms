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
exports.positions = {
		sql: {
			all: `select positions.id, positions.name, positions.tags, positions_t.description, positions.hr, positions.qa, positions.manager
					from mymes.positions as positions left join mymes.positions_t as positions_t on positions.id = positions_t.position_id 
					where positions_t.lang_id = $1 `,					

			choosers :{	

			}

		},

		schema: {
			pkey: 'position_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				}				
			},

			tables : {
				positions :{
					fields : [
						{
							field: 'name',
							variable : 'name'
						},
						{
							field: 'hr',
							variable : 'hr'
						},
						{
							field: 'qa',
							variable : 'qa'
						},	
						{
							field: 'manager',
							variable : 'manager'
						},											
						{
							field: 'row_type',
							variable : 'row_type',
							value : 'position'
						},						
						{
							field: 'tags',
							variable : 'tags'
						},											
						{
							key: 'id'
						}
				   ]
				},
				positions_t :{
					fields : [
						{
							field: 'description',
							variable: 'description'
						},
						{
							field: 'position_id',
							 fkey :'position_id',
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



