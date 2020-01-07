const {db} = require('../DBConfig.js')

const integerOperators = [
    {
      name: "=",
      caption: "Equals"
    },
    {
      name: "<>",
      caption: "Not equal"
    },
    {
      name: "<",
      caption: "Is Less Than"
    } ,
    {
      name: ">",
      caption: "Is Greater Than"
    } ,    
    {
      name: ">>",
      caption: "Got Bigger",
      noValue : true      
    } ,
    {
      name: "<<",
      caption: "Got Smaller",
      noValue : true
    },      
    {
      name: "><",
      caption: "Changed",
      noValue : true      
    },                
  ]

const booleanOperators =[
    {
        name : 'true',
        caption : 'Is True',
        noValue : true           
    },
    {
        name : 'false',
        caption : 'Is false',
        noValue : true           
    },
    {
        name: "><",
        caption: "Changed",
        noValue : true        
    },    
]
const textOperators = [
    {
        name: "=",
        caption: "Equals"
      },
      {
        name: "<>",
        caption: "Not equal"
      },
      {
        name: 'like',
        caption : 'Contains'
      },
      {
        name: 'nlike',
        caption : 'Not Contains'
      },      
      {
        name: "><",
        caption: "Changed",
        noValue : true        
      },      
]

const arrayOperators = [
    {
      name: 'contain',
      caption : 'Contains'
    },
    {
      name: 'ncontain',
      caption : 'Not Contains'
    },
    {
      name: "><",
      caption: "Changed",
      noValue : true      
    },      
]
const exportSchemas = async(req, res) =>{
	const {user} = req.query
	const sql = `select distinct table_name from information_schema.tables,information_schema.triggers 
    where table_schema = 'mymes'
    and event_object_table = table_name
    and trigger_name like 'events_trigger%';
 `
	try{
		const ret =  await db.any(sql).then(x=>x)	
        res.status(200).json({main : { schemas: ret,
                                    integerOperators,
                                    booleanOperators,
                                    textOperators ,
                                    arrayOperators                                   
                                }})
	}catch(e){
		console.error(e)
	}
}


const exportFields = async(req, res) =>{
	const {user,schema} = req.query
    const sql = `
    select table_name,column_name,data_type
    from information_schema.columns
    where (table_name = '${schema}'
    or table_name in (
    SELECT
        ccu.table_name 
        FROM 
        information_schema.table_constraints AS tc 
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        JOIN information_schema.constraint_column_usage AS ccu
          ON ccu.constraint_name = tc.constraint_name
          AND ccu.table_schema = tc.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name='${schema}')
     
    or table_name in (
    SELECT
        ccu.table_name 
        FROM 
        information_schema.table_constraints AS tc 
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        JOIN information_schema.constraint_column_usage AS ccu
          ON ccu.constraint_name = tc.constraint_name
          AND ccu.table_schema = tc.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name in (
    SELECT
        ccu.table_name 
        FROM 
        information_schema.table_constraints AS tc 
        JOIN information_schema.key_column_usage AS kcu
          ON tc.constraint_name = kcu.constraint_name
          AND tc.table_schema = kcu.table_schema
        JOIN information_schema.constraint_column_usage AS ccu
          ON ccu.constraint_name = tc.constraint_name
          AND ccu.table_schema = tc.table_schema
    WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name='${schema}')
    ))
    and data_type <> 'USER-DEFINED'
    and column_name not like '%id'
    order by 1;`        

  const fetchTriggersSQL = `select * from mymes.event_triggers where table_id = '${schema}';`
	try{
    const fields =  await db.any(sql).then(x=>x)
    const triggers = await db.any(fetchTriggersSQL).then(x=>x)	
    const ret = {triggers,fields}
		res.status(200).json({main:ret})
	}catch(e){
		console.error(e)
	}
}

const getConditionsSQL = async (trigger,table_id) => {
  const tableArr = (json) => json.map(cond => cond.hasOwnProperty('groupName') ? tableArr(cond.items) : cond.field).flat().map(x => x.split('.')[0])
  const tables = Array.from(new Set(tableArr([trigger])))

  const start_with = `select 1 from ${tables.reduce((z,x) => `${z},mymes.${x}` ,'').substr(1)} where 1=1 `
  const whereLinksArr = await Promise.all(tables.map( async table => {
    const sql = `SELECT
            tc.table_schema, 
            tc.constraint_name, 
            tc.table_name, 
            kcu.column_name, 
            ccu.table_schema AS foreign_table_schema,
            ccu.table_name AS foreign_table_name,
            ccu.column_name AS foreign_column_name 
        FROM 
            information_schema.table_constraints AS tc 
            JOIN information_schema.key_column_usage AS kcu
              ON tc.constraint_name = kcu.constraint_name
              AND tc.table_schema = kcu.table_schema
            JOIN information_schema.constraint_column_usage AS ccu
              ON ccu.constraint_name = tc.constraint_name
              AND ccu.table_schema = tc.table_schema 
        WHERE tc.constraint_type = 'FOREIGN KEY' AND tc.table_name='${table}'
        AND tc.table_name <> ccu.table_name;`
    const allFKeys =  await db.any(sql).then(x=>x)
    const fkeys = allFKeys.filter(x=> tables.includes(x.foreign_table_name))
   
    return fkeys.map(x => {
      x.table_schema = x.table_name === table_id ? '' : x.table_schema+'.'      
      x.table_name = x.table_name === table_id ? '$1' : x.table_name
      x.foreign_table_schema = x.table_name === table_id ? '' : x.foreign_table_schema+'.'
      x.foreign_table_name = x.table_name === table_id ? '$1' : x.foreign_table_name
      return `and ${x.table_schema}${x.table_name}.${x.column_name} = ${x.foreign_table_schema}${x.foreign_table_name}.${x.foreign_column_name}`
    }) 
  }))
  const whereLinks = whereLinksArr.flat().reduce((z,x) => `${z} ${x || ''}` ,'')
  
  const getOV = (operator,value,tableField) => {
    let ret
    const field = tableField.split('.')[1]
    const fieldName = table_id === tableField.split('.')[0] ? `$1.${field}` : tableField
    switch(operator) {
      case 'true' : ret = `${fieldName} is true` 
      break;
      case 'false' : ret = `${fieldName} is false`
       break;
      case 'like' : ret = `${fieldName} like ''%${value}%''`
       break;
      case 'nlike' : ret = `${fieldName} not like ''%${value}%''`
       break;
      case '<<' : ret = `${fieldName} < $2.${field}`
       break;
      case '>>' : ret = `${fieldName} > $2.${field}`
       break;
      case '><' : ret = `${fieldName} <> $2.${field}`
       break;
      case 'contain' : ret = `${fieldName} @> array[''${value}'']`
       break;
      case 'ncontain' : ret = `not ${fieldName} @> array[''${value}'']`
       break;      
      default: ret = `${fieldName} ${operator} ''${value}''`
    }

    return ret
  }

  getWhereConditions = (json,pg,insert) => { 
    const logicGate = json.groupName 
    const logicCondition = ( logicGate) === 'and' ? '1=1' : '1=2'
    const ret = [`${pg || logicGate} ( ${logicCondition} ` , json.items.map(x=> (x.hasOwnProperty('groupName') ?  getWhereConditions(x,logicGate,insert) : (insert && ['<<','>>','><'].includes(x.operator) ? '' :  `${logicGate}  ${getOV(x.operator,x.value,x.field)}`))).flat(),")"].flat()
    return ret.flat().reduce((o,x) => `${o} ${x}`,'' )
  }
  const whereConditionsInsert = getWhereConditions(trigger,null,true)
  const whereConditionsUpdate = getWhereConditions(trigger,null,false)

  const coditionsSqlInsert = whereConditionsInsert > '' ? `${start_with} ${whereLinks} ${whereConditionsInsert}; ` : ''
  const coditionsSqlUpdate =  `${start_with} ${whereLinks} ${whereConditionsUpdate}; `

  return {
    updateSQL: coditionsSqlUpdate,
    insertSQL: coditionsSqlInsert
  }
}


const insertTrigger = async(req, res) =>{
  const data = req.body

  const {insertSQL, updateSQL} = await getConditionsSQL(data.conditions,data.table_id)


  const sql = `insert into mymes.event_triggers (name,active,message_text,queues,error,del,table_id,conditions,user_name,update_sql,insert_sql)
               values('${data.name}',${data.active},'${data.message_text.replace(new RegExp("'", 'g'), "''")}','{${data.queues}}',${data.error},${data.del},'${data.table_id}','${JSON.stringify(data.conditions)}','${data.user}','${updateSQL}','${insertSQL}') returning id;  `
               
	try{
    if(data.id > 0)  await db.one(`delete from mymes.event_triggers where id = ${data.id}`).then(x=>x)
		const ret =  await db.one(sql).then(x=>x)	
        res.status(201).json({ret})
      } catch(err) {
        console.error("error in InsertTrigger:",err,sql)
        res.status(406).json({error: 'insertTrigger : '+err})
        throw new Error("Insert Trigger fault :" + err.toString())
      }        
}

const deleteTrigger = async(req, res) =>{
  const data = req.body

  const sql = `delete from mymes.event_triggers where id = ${data.id} returning id; `
	try{
		const ret =  await db.one(sql).then(x=>x)	
        res.status(205).json({ret})
      } catch(err) {
        console.error("error in DeleteTrigger:",err,sql)
        res.status(406).json({error: 'DeleteTrigger : '+err})
        throw new Error("Delete Trigger fault :" + err.toString())
      }        
}

module.exports = {
    exportFields,
    exportSchemas,
    insertTrigger,
    deleteTrigger
  }

