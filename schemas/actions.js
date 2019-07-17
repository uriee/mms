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
exports.actions = {
		sql: {
			all: `select actions.id, actions.name, actions.tags, actions_t.description, actions.active, actions.erpact, actions.quantitative, actions.serialize 
					from mymes.actions as actions left join mymes.actions_t as actions_t on actions.id = actions_t.action_id 
					where actions_t.lang_id = $1 `,					

			choosers :{	

			}

		},

		schema: {
			pkey: 'action_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				}				
			},

			tables : {
				actions :{
					fields : [
						{
							field: 'name',
							variable : 'name'
						},
						{
							field: 'active',
							variable : 'active'
						},
						{
							field: 'erpact',
							variable : 'erpact'
						},
						{
							field: 'quantitative',
							variable : 'quantitative'
						},
						{
							field: 'serialize',
							variable : 'serialize'
						},																								
						{
							field: 'row_type',
							variable : 'row_type',
							value : 'action'
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
				actions_t :{
					fields : [
						{
							field: 'description',
							variable: 'description'
						},
						{
							field: 'action_id',
							 fkey :'action_id',
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
					name: 'Clone Actions',
					parameteres: ['id'],
					function : 'clone_actions'
				}
			]
		}	
	}



