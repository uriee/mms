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
exports.fault = {
		sql: {
			all: `select fault.id, fault.name , fault_t.description,  
            serial.name as serial_name, status.name as status_name, type.name as type_name ,
            resource.name as resource_name , 
            fault.tags, fault.open_date, fault.close_date, fault.quant , users.username as user_name
            from mymes.fault as fault left join mymes.fault_t as fault_t on fault.id = fault_t.fault_id ,
            mymes.serials as serial, mymes.resources as resource, mymes.fault_type as type , mymes.fault_status as status , users 
            where fault.serial_id = serial.id
            and fault.resource_id = resource.id
            and fault.user_id = users.id
            and fault_status_id = status.id              
            and fault_type_id = type.id  
            and fault_t.lang_id = $1 `,

			choosers :{
                fault_type: `select name from mymes.fault_type where active = true;`,
                fault_status: `select name from mymes.fault_status where active = true;`,
                resource: `select name from mymes.resource_groups where active = true;`,
				serial: `select name from mymes.serials where active = true;`,
			},

		},

		schema: {
			pkey: 'fault_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},
				fault_type_id: {
					query : `select id from mymes.fault_type where name = $1;`,
					 value : 'type_name'
                },
				fault_status_id: {
					query : `select id from mymes.fault_status where name = $1;`,
					 value : 'status_name'
				},                
				serial_id: {
					query : `select id from mymes.serials where name = $1 and active = true;`,
					 value : 'serial_name'
                },
				resource_id: {
					query : `select id from mymes.resource_groups where name = $1;`,
					 value : 'resource_name'
                },
				user_id: {
					query : `select id from users where username = $1;`,
					 value : 'user'
				}                                 					
			},

			tables : {
				fault :{
					fields : [
						{
							field: 'serial_id',
							fkey : 'serial_id',
							table: 'serial',
							filterField : 'name',
							filterValue: 'serial_name',								
						},
						{
							field: 'fault_type_id',
							fkey : 'fault_type_id',
							table: 'type',
							filterField : 'name',
							filterValue: 'type',								
                        },	
						{
							field: 'fault_status_id',
							fkey : 'fault_status_id',
							table: 'status',
							filterField : 'name',
							filterValue: 'status',								
                        },   
						{
							field: 'user_id',
							fkey : 'user_id',
							table: 'users',
							filterField : 'username',
							filterValue: 'user_name',								
                        },    
						{
							field: 'resource_id',
							fkey : 'resource_id',
							table: 'resource',
							filterField : 'resource_name',
							filterValue: 'resource_name',								
						},                                                                      						
						{
							field: 'name',
							variable : 'name'
						},                      
						{
							field: 'open_date',
							variable : 'open_date'
						},
						{
							field: 'close_date',
							variable : 'close_date'
						},
						{
							field: 'quant',
							variable : 'quant'
						},
						{
							"field": "tags",
							"variable" : "tags"
						},	
						{
							field: 'row_type',
							variable : 'row_type',
							value : 'fault'
						},
						{
							key: 'id'
						}
				   ]
				},
				fault_t :{
					fields : [
						{
							field: 'description',
							 variable: 'description'
							},
						{
							field: 'fault_id',
							 fkey :'fault_id',
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



