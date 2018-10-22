//const {conf} = require('./Conf.js')
const languagesArray = [1,2,3]
/*---*/
/*  sql : queries for fetching data
	sql.single : fetches single record
	sql.all : fetch few records
	schema: the insert/update schema for this entity
	schema.pkey : the pkey field name for this entity
	schema.fkeys : keys that need to be fetched from server in order to preform insert/update
	schema.tables : the tables that need to be updated 
*/
exports.parts = {
		sql: {
			single: `select part.name, part_t.desc_t as desc ,part.type, 
				from mymes.part as part, mymes.part_t as part_t
				and part_t.part_id = part.id
				and part_t.lang_id = $2
				and part.name = $1;`	,

			all: `select part.name, part_t.desc_t as desc ,part.type, 
				from mymes.part as part, mymes.part_t as part_t
				and part_t.part_id = part.id
				and part_t.lang_id = $1
				order by part.name;`
		},

		schema: {
			pkey: 'part_id' ,


			fkeys: {
				lang_id : {value : 'part_id'},
			},

			tables : {
				part :{
					fields : [
						{field: 'name' , variable : 'part_name'},
						{field: 'status', variable: 'status'},
						{key: 'id'}
				   ]
				},
				part_t :{
					fields : [
						{field: 'desc_t', variable: 'desc'},
						{field: 'part_id', fkey :'part_id' ,key: 'id'},
						{field: 'lang_id', fkey :'lang_id', key: 'lang_id'},
					],
					fill: {field : 'lang_id' , values : languagesArray}
				}
			}
		}	
	}



