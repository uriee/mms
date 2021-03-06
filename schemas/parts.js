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
exports.parts = {
		sql: {
			all: `select part.id, part.name, part.revision, part.doc_revision, part.active, part_t.description , part_status.name as part_status, part.tags, part.serialize ,part.batch_size
					from mymes.part as part left join mymes.part_t as part_t on part.id = part_t.part_id, 
					mymes.part_status 
					where part_status.id = part.part_status_id 
					and part_t.lang_id = $1 `,
			final : ' order by name desc ',										

			choosers :{
				part_status: `select name from mymes.part_status;`
			}

		},


		schema: {
			pkey: 'part_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},
				part_status_id: {
					query : `select id from mymes.part_status where name = $1 ; `,
					 value : 'part_status'
					}
			},

			tables : {
				part :{
					fields : [
						{
							field: 'part_status_id',
							fkey : 'part_status_id',
							table: 'part_status',
							filterField : 'name',
							filterValue: 'part_status',								 
						},
						{
							field: 'active',
							variable : 'active'
						},						
						{
							field: 'name',
							variable : 'name',
							required : true

						},
						{
							field: 'revision',
							variable : 'revision'
						},	
						{
							field: 'doc_revision',
							variable : 'doc_revision'
						},
						{
							field: 'serialize',
							variable : 'serialize'
						},		
						{
							field: 'batch_size',
							variable : 'batch_size'
						},										
						{
							field: 'row_type',
							variable : 'row_type',
							value : 'part'
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
				part_t :{
					fields : [
						{
							field: 'description',
							variable: 'description'
							},
						{
							field: 'part_id',
							 fkey :'part_id',
							 key: 'id'},
						{
							field: 'lang_id',
							 fkey :'lang_id',
							  key: 'lang_id'
						}

					],
					fill: {
						field : 'lang_id',
						values : languagesArray
					}
				}
			},

			functions : [
				{
					name: 'Clone Part',
					parameteres: ['id'],
					function : 'clone_part'
				}
			]
		}	
	}



