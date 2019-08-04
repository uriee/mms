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
exports.fix = {
		sql: {
			all: `select fix.id, fix.name, fix.tags, fix_t.description ,active , extname 
				  	from mymes.fix as fix left join mymes.fix_t as fix_t on fix.id = fix_t.fix_id
					where fix_t.lang_id = $1 `,					

			choosers :{	
	
			}

		},

		schema: {
			pkey: 'fix_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},				
			},

			tables : {
				fix :{
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
							value : 'fix'
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
				fix_t :{
					fields : [
						{
							field: 'description',
							variable: 'description'
						},						
						{
							field: 'fix_id',
							 fkey :'fix_id',
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



