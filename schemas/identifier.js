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

exports.identifier = {
		sql: {
			all: `select identifier.id, identifier.name as identifier, identifier.id as name , il.serial_id, il.act_id 
			from mymes.identifier as identifier, mymes.identifier_links as il
			where identifier.id = il.identifier_id
			and il.parent_id = $3 and row_type = $6`,
					
			choosers :{}
		},
		
		postInsertHelpers : [{functionName:'updateParentIdentifiers',parameters : ['son_identifiers']}],

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
			parameters: ['parent','parent_schema','identifier']
		},				

		schema: {
			pkey: 'identifier_id' ,

			fkeys: {			

			},

			tables : {
				identifier :{
					fields : [				
						{
							field: 'name',
							variable : 'identifier'
						},
						{
							field: 'parent_id',
							variable : 'parent'
						},																	
						{
							key: 'id'
						}
				   ]
				},/*
				identifier_links :{
					fields : [
						{
							field: 'parent_id',
							variable : 'parent'
						},	
						{
							field: 'row_type',
							variable : 'parent_schema'
						},
						{
							field: 'serial_id',
							variable : 'serial_id'
						},	
						{
							field: 'act_id',
							variable : 'act_id'
						},																	
						{
							field: 'identifier_id',
							fkey :'identifier_id',
							key : 'id'
						},											
				   ]
				}
				*/				
			}
		}	
	}
