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
exports.lot_swap = {
		sql: {
            all: `select lot_old, lot_new, updated_at , r.name as resourcename, s.name as serialname, a.name as actname , username 
                    from mymes.lot_swap , mymes.resources r, mymes.actions a, mymes.serials s, users u
                    where r.id = lot_swap.resource_id
                    and s.id = lot_swap.serial_id
                    and a.id = lot_swap.act_id
                    and u.id = lot_swap.user_id`	,		
			final: ` order by lot_swap.updated_at desc `,

			choosers :{
			
			},

		},

		schema: {
			pkey: '' ,

			fkeys: {
				resource_id: {
					query : `select id from mymes.resources where name = $1;`,
					 value : 'resourcename',
                },	
				serial_id: {
					query : `select id from mymes.serials where name = $1;`,
					 value : 'serialname',
                },
				sig_user: {
					query : `select id from users where username = $1;`,
					 value : 'sig_user',
                },
				act_id: {
					query : `select id from mymes.actions where name = $1;`,
					 value : 'actname',
                },                                                						
			},

			tables : {
				lot_swap :{
					fields : [	
						{
							field: 'lot_new',
							variable : 'lot_new'
						},
						{
							field: 'lot_old',
							variable : 'lot_old'
						},																													
						{
							field: 'resource_id',
							fkey : 'resource_id'
                        },	
						{
							field: 'serial_id',
							fkey : 'serial_id'
                        },	                        																	
						{
							field: 'act_id',
							fkey : 'act_id'
                        },	
						{
							field: 'user_id',
							fkey : 'sig_user'
						},	                                                
						{
							key: 'id'
						}
				   ]
				}
			}
		}	
	}



