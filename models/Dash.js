//db connection configuration
const {db} = require('../DBConfig.js')

const ws = 'mymes';


const wo_percent_total = () => {
  return db.one(`select avg(1-sa.balance::real/sa.quant::real)
                 from ${ws}.serial_act as sa,${ws}.serials as s
                 where s.id = sa.serial_id
                 and s.active = true;`)
}

const serial_total = () => {
  return db.one(`select count(*)
                 from ${ws}.serials
                 where active = true;`)
}


const serial_stats = () => {
  return db.any(`select se.name, avg(1- sa.balance::real/sa.quant::real),min(1- sa.balance::real/sa.quant::real)
                  from mymes.serials se,mymes.serial_act sa 
                  where se.id = sa.serial_id
                  and se.active = true 
                  group by 1;`)
}

const work_report_placements2 = (param) => {
  const {fromdate,todate,interval} = param
  return db.any(
    `select date_trunc($3, wr.sig_date),sum(wr.quant)
    from ${ws}.work_report as wr ,${ws}.serials as wo ,${ws}.locations as l 
    where wo.id = wr.serial_id
    and l.part_id = wo.part_id
    and l.act_id = wr.act_id
    and wr.sig_date between $1 and date $2 + interval '1 day' 
    group by 1;`
    ,[fromdate,todate,interval || 'day'])
}

const work_report_placements = (param) => {
  const {fromdate,todate,interval} = param
  const inter = `1 ${interval}`
  return db.any(
    `select d as x, sum(wr.quant) as y
      from generate_series( $1, date $2 + interval '1 day - 1 minute', interval $4) as d
      left join mymes.work_report wr on date_trunc($3, wr.sig_date) = d
      left join mymes.serials wo on wo.id = wr.serial_id
      left join mymes.locations l  on l.part_id = wo.part_id and l.act_id = wr.act_id
      group by d
      order by d`
    ,[fromdate,todate,interval || 'day',(interval ? inter : '1 day')])
}

const work_report_products = (param) => {
  const {fromdate,todate,interval} = param
  const inter = `1 ${interval}`
  return db.any(
    `select d as x, sum(wr.quant) as y
      from generate_series( $1, date $2 + interval '1 day - 1 minute', interval $4) as d
      left join mymes.work_report wr on date_trunc($3, wr.sig_date) = d
      group by d
      order by d`
    ,[fromdate,todate,interval || 'day',(interval ? inter : '1 day')])
}

const work_report_placements_by_parent_resource = (param) => {
  const {fromdate,todate,interval,user} = param
  const inter = `1 ${interval}`
  return db.any(
    `select res.name,d as x, sum(wr.quant) as y ,min(rh.depth) as depth
      from generate_series( $1, date $2 + interval '1 day - 1 minute', interval $4) as d
      left join mymes.work_report wr on date_trunc($3, wr.sig_date) = d
      left join mymes.serials wo on wo.id = wr.serial_id
      left join mymes.resources_hierarchy rh on rh.son = wr.resource_id   
      left join user_resources_by_parent($5) r on r.resource = rh.parent                        
      left join mymes.resources res on res.id = r.resource
      left join mymes.locations l  on l.part_id = wo.part_id and l.act_id = wr.act_id
      group by res.name,d 
      order by d, depth desc,  res.name`
    ,[fromdate,todate,interval || 'day',(interval ? inter : '1 day'),user])
}


const prod_funcs = [
  {name:  'wo_percent_total' , func: wo_percent_total},
  {name:'serial_total' ,func: serial_total},
  {name : 'work_report_placements', func :  work_report_placements},
  {name : 'work_report_placements_by_parent_resource', func :  work_report_placements_by_parent_resource, multi : 'resource'}, 
  {name : 'work_report_products' ,func : work_report_products},
  {name : 'serial_stats' ,func : serial_stats}  
]

const fetchDashData = async (req,res) => {
  const param = req.query || req.body
  console.log('----------------',param)
  let ret = {funcs : prod_funcs.map(x => x.name)}
  try {
        const data = await Promise.all(prod_funcs.map(async (f) => await f.func(param)))
        prod_funcs.forEach((x,i)=> ret[x.name] = data[i])
        console.log(data,ret)        
        res.status(200).json({data :ret})
      }catch(err){
              res.status(401).json()
              console.error(err)
      }
}



module.exports = {
  fetchDashData
}