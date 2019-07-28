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
exports.fault_type = {
		sql: {
			all: `select fault_type.id, fault_type.name, fault_type.tags, fault_type_t.description ,active , extname 
				  	from mymes.fault_type as fault_type left join mymes.fault_type_t as fault_type_t on fault_type.id = fault_type_t.fault_type_id
					where fault_type_t.lang_id = $1 `,					

			choosers :{	
	
			}

		},

		schema: {
			pkey: 'fault_type_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},				
			},

			tables : {
				fault_type :{
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
							value : 'fault_type'
						},						
						{
							field: 'active',
							variable : 'active'
						},
						{
							field: 'extname',
							variable : 'extname'
						},						
						{
							key: 'id'
						}
				   ]
				},
				fault_type_t :{
					fields : [
						{
							field: 'description',
							variable: 'description'
						},						
						{
							field: 'fault_type_id',
							 fkey :'fault_type_id',
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



