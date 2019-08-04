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
            serial.name as serialname, status.name as status_name, type.name as type_name ,fix.name as fix_name, 
            resource.name as resourcename , act.name as actname , sig_date, l.location as location, 
            fault.tags, fault.close_date, fault.quant , users.username as username
			from mymes.fault as fault left join mymes.fault_t as fault_t on fault.id = fault_t.fault_id
			left join mymes.fault_type as type on fault_type_id = type.id 
			left join mymes.fix as fix on fix_id = fix.id 			
			left join mymes.fault_status as status on fault_status_id = status.id
			left join mymes.actions as act on act_id = act.id
			left join mymes.locations as l on location_id = l.id,
            mymes.serials as serial, mymes.resources as resource, users 
            where fault.serial_id = serial.id
            and fault.resource_id = resource.id
            and fault.sig_user = users.id 
			and fault_t.lang_id = $1 `,
			
			final : ' order by name desc ',	
				

			choosers :{
				fault_type: `select name,description from mymes.fault_type f,mymes.fault_type_t t where active = true and f.id = t.fault_type_id and t.lang_id = $1;`,
				fix: `select name,description from mymes.fix f,mymes.fix_t t where active = true and f.id = t.fix_id and t.lang_id = $1;`,				
                fault_status: `select name from mymes.fault_status where active = true;`,
                resource: `select name from mymes.resource_groups where active = true;`,
				serial: `select name from mymes.serials where active = true;`,
			},

		},
		pre_insert: {
			function: 'check_identifier_exists',
			parameters: ['serialname','actname','entity','identifier']
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
				fix_id: {
					query : `select id from mymes.fix where name = $1;`,
					 value : 'fix_name'
                },				
				fault_status_id: {
					query : `select id from mymes.fault_status where name = $1 and active = true;`,
					 value : 'status_name'
				},                
				serial_id: {
					query : `select id from mymes.serials where name = $1 and active = true;`,
					 value : 'serialname'
				},
				act_id: {
					query : `select id from mymes.actions where name = $1;`,
					 value : 'actname'
				},				
				resource_id: {
					query : `select id from mymes.resources where name = $1;`,
					 value : 'resourcename'
				},
				location_id: {
					query : `select l.id from mymes.locations l, mymes.serials s where l.location = $1 and s.part_id = l.part_id and s.name = $2;`,
					 value : ['location','serialname']
				},				
				sig_user: {
					query : `select id from users where username = $1;`,
					 value : 'user'
				}                                 					
			},
			chain : ['identifier'],
			tables : {
				fault :{
					fields : [
						{
							field: 'serial_id',
							fkey : 'serial_id',
							table: 'serial',
							filterField : 'name',
							filterValue: 'serialname',								
						},
						{
							field: 'fault_type_id',
							fkey : 'fault_type_id',
							table: 'type',
							filterField : 'name',
							filterValue: 'type',								
						},	
						{
							field: 'fix_id',
							fkey : 'fix_id',
							table: 'fix',
							filterField : 'name',
							filterValue: 'fix',								
                        },						
						{
							field: 'fault_status_id',
							fkey : 'fault_status_id',
							table: 'status',
							filterField : 'name',
							filterValue: 'status',								
                        },   
						{
							field: 'sig_user',
							fkey : 'sig_user',
							table: 'users',
							filterField : 'username',
							filterValue: 'username',								
                        },    
						{
							field: 'resource_id',
							fkey : 'resource_id',
							table: 'resource',
							filterField : 'resourcename',
							filterValue: 'resourcename',								
						},  
						{
							field: 'act_id',
							fkey : 'act_id',
							table: 'action',
							filterField : 'name',
							filterValue: 'actname',								
						},
						{
							field: 'location_id',
							fkey : 'location_id',
							table: 'locations',
							filterField : 'location',
							filterValue: 'location',								
						},												                                                                    						
						{
							field: 'name',
							variable : 'name'
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
							field: 'sig_date',
							variable : 'sig_date'
						},						
						{
							field: "tags",
							variable : "tags"
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



