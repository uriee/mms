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

const updateParentIdentifiers = async (db,id,params) => {
	var iid = id

	sids = Array.isArray(params.son_identifiers) ? params.son_identifiers : [params.son_identifiers]

	if (!id) {
		const do_exist = `select i.id from mymes.identifier i ,mymes.serials s
						where s.name = '${params.serialname}'
						and i.parent_id = s.part_id
						and i.name = '${params.identifier}';`
		iid =  await db.one(do_exist).then(x => x.id)
		console.log(do_exist,iid,id)
	}

	return  await sids.map(async (obj) => 
		Promise.all(Object.keys(obj).map( async parent => {

			return await obj[parent].map(async identifier => {
				const sql = `update mymes.identifier
							set parent_identifier_id = ${iid}
							where name = '${identifier}'
							and parent_id = (select id from mymes.part where name = '${parent}') returning 1;`
								 
				return await db.one(sql)
			})
		})
	))
}

exports.identifier = {
		sql: {
			all: `select identifier.id, identifier.name as identifier, identifier.mac_address, identifier.secondary,
			 identifier.id as name , il.serial_id, il.act_id  , p.name as parent_identifier
			from mymes.identifier as identifier left join mymes.identifier p on p.id = identifier.parent_identifier_id
			,mymes.identifier_links as il
			where identifier.id = il.identifier_id
			and il.parent_id = $3 and row_type = $6`,
					
			choosers :{}
		},
		
		postInsertHelpers : [{func : updateParentIdentifiers ,parameters : ['son_identifiers','serialname','identifier']}],

		pre_delete: {
			function: 'delete_identifier_link',
			parameters: ['id','parent','row_type']
		},	
		pre_insert: {
			function: 'insert_identifier_link_pre',
			parameters: ['parent','parent_schema','identifier']
		},	
		post_insert: {
			function: 'insert_identifier_link_post',
			parameters: ['parent','parent_schema','identifier','batch_array']
		},				

		schema: {
			pkey: 'identifier_id' ,

			fkeys: {
				parent_identifier_id : {
					query : `select id from mymes.identifier where name = $1;`,
					 value : 'parent_identifier'
                },							

			},

			tables : {
				identifier :{
					fields : [				
						{
							field: 'name',
							variable : 'identifier'
						},
						{
							field: 'mac_address',
							variable : 'mac_address'
						},
						{
							field: 'secondary',
							variable : 'secondary'
						},												
						{
							field: 'parent_id',
							variable : 'parent'
						},	
						{
							field: 'parent_identifier_id',
							variable : 'parent_identifier_id'
						},																													
						{
							key: 'id'
						}
				   ]
				},				
			}
		}	
	}
