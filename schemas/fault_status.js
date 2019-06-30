const {languagesArray} = require('./schema_conf.js')
//import { languagesArray } from './schema_conf.js';
/*---*/
/*  sql : queries for fetching data
	sql.single : fetches single record
	sql.all : fetch few records
	schema: the insert/update schema for this entity
	schema.pkey : the pkey field name for this entity
	schema.fkeys : keys that need to be fetched from server in order to preform insert/update
	schema.tables : the tables that need to be updated 
*/
exports.fault_status = {
		sql: {
			all: `select fault_status.id, fault_status.name, fault_status.tags, fault_status_t.description , active
				  	from mymes.fault_status as fault_status left join mymes.fault_status_t as fault_status_t on fault_status.id = fault_status_t.fault_status_id
					where fault_status_t.lang_id = $1 `,					

			choosers :{	
	
			}

		},

		schema: {
			pkey: 'fault_status_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},				
			},

			tables : {
				fault_status :{
					fields : [
						{
							field: 'name',
							variable : 'name'
						},								
						{
							field: 'tags',
							variable : 'tags'
						},
						{
							field: 'row_type',
							variable : 'row_type',
							value : 'fault_status'
						},						
						{
							field: 'active',
							variable : 'active'
						},
						{
							key: 'id'
						}
				   ]
				},
				fault_status_t :{
					fields : [
						{
							field: 'description',
							variable: 'description'
						},						
						{
							field: 'fault_status_id',
							 fkey :'fault_status_id',
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



