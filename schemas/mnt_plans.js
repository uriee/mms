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
exports.mnt_plans = {
		sql: {
			all: `select mnt_plans.id, mnt_plans.name, tags, mnt_plan_t.description ,  mnt_plans.reschedule, mnt_plans.repeat ,mnt_plans.start_date, mnt_plans.end_date
					from mymes.mnt_plans as mnt_plans left join mymes.mnt_plans_t as mnt_plan_t on mnt_plans.id = mnt_plan_t.mnt_plan_id where mnt_plan_t.lang_id = $1 `,					

			choosers :{			
			}

		},

		schema: {
			pkey: 'mnt_plan_id' ,

			fkeys: {
				lang_id : {
					value : 'lang_id'
				},
			},

			tables : {
				mnt_plans :{
					fields : [
						{
							field: 'name',
							variable : 'name'
						},
						{
							field: 'repeat',
							variable : 'repeat'
						},
						{
							field: 'reschedule',
							variable : 'reschedule'
						},	
						{
							field: 'start_date',
							variable : 'start_date'
						},																	
						{
							field: 'end_date',
							variable : 'end_date'
						},	
						{
							field: 'row_type',
							variable : 'row_type',
							value : 'mnt_plans'
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
				mnt_plans_t :{
					fields : [
						{
							field: 'description',
							variable: 'description'
						},
						{
							field: 'mnt_plan_id',
							 fkey :'mnt_plan_id',
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



