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
exports.serials = {
		sql: {
			all: `select serials.id, serials.name, serials.quant, serials.tags, serials_t.description, serials.active, serials.end_date, 
					concat(part.name,':',part.revision) as partname, process.name as procname, serial_statuses.name as status,
					serials.extserial ,parent.name as parent_serial_name
					from mymes.serials as serials left join mymes.serials_t as serials_t on serials.id = serials_t.serial_id 
					left join mymes.process as process on serials.process_id = process.id
					left join mymes.serials as parent on parent.id = serials.parent_serial,
					mymes.serial_statuses as serial_statuses, mymes.part as part 
					where part.id = serials.part_id
					and serial_statuses.id = serials.status
					and serials_t.lang_id = $1 `,	
			final : ' order by name desc ',										

			choosers :{	
				status: `select name from mymes.serial_statuses;`,
				part: `select concat(name,':',revision) as name from mymes.part where active=true order by name,revision;`,
				process: `select name from mymes.process;`,
				parent_serial: `select name from mymes.serials where active = True`
			}

		},

		post_insert: {
			function: 'cpy_acts_proc2ser',
			parameters: ['id','procname']
		},
		/*
		pre_delete: {
			tables: [{table :'kit',key : 'serial_id'}]
		},		
		*/




		schema: {
			pkey: 'serial_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},
				status: {
					query : `select id from mymes.serial_statuses where name = $1;`,
					 value : 'status'
				},
				part_id: {
					query : `select id from mymes.part where name = split_part($1,':',1) and revision = split_part($1,':',2);`,
					 value : 'partname'
				},
				process_id: {
					query : `select id from mymes.process where name = $1;`,
					 value : 'procname'
				},
				parent_serial: {
					query : `select id from mymes.serials where name = $1;`,
					 value : 'parent_serial_name'
				}				
			},

			tables : {
				serials :{
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
							field: 'quant',
							variable : 'quant'
						},						
						{
							field: 'part_id',
							fkey : 'part_id'
						},
						{
							field: 'process_id',
							fkey : 'process_id'
						},
																		{
							field: 'parent_serial',
							fkey : 'parent_serial'
						},
						{
							field: 'status',
							fkey : 'status',
							table: 'serial_statuses',
							filterField : 'name',
							filterValue: 'status',							
						},																
						{
							field: 'end_date',
							variable : 'end_date'
						},	
						{
							field: 'extserial',
							variable : 'extserial'
						},						
						{
							field: 'row_type',
							variable : 'row_type',
							value : 'serials'
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
				serials_t :{
					fields : [
						{
							field: 'description',
							variable: 'description'
						},
						{
							field: 'serial_id',
							 fkey :'serial_id',
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



