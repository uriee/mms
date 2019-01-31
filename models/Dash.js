//db connection configuration
const {db} = require('../DBConfig.js')

const ws = 'mymes';


const wo_percent_total = () => {
  return db.one(`select avg(sa.balance::real/sa.quant::real)
                 from ${ws}.serial_act as sa,${ws}.serials as s
                 where s.id = sa.serial_id
                 and s.active = true;`)
}

const serial_total = () => {
  return db.one(`select count(*)
                 from ${ws}.serials
                 where active = true;`)
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
    `select d as date_column, sum(wr.quant) 
      from generate_series( $1, $2, interval $4) as d
      left join mymes.work_report wr on date_trunc($3, wr.sig_date) = d
      left join mymes.serials wo on wo.id = wr.serial_id
      left join mymes.locations l  on l.part_id = wo.part_id and l.act_id = wr.act_id
      group by d
      order by d`
    ,[fromdate,todate,interval || 'day',inter || '1 day'])
}


const funcs = {
  wo_percent_total : wo_percent_total,
  serial_total : serial_total,
   work_report_placements :  work_report_placements
}

const fetchDashData = async (req,res) => {
  const param = req.query || req.body
  const func = funcs[param.func] 
  console.log('~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~',param)
  try {
        data = await func(param)
        res.status(201).json(data)
      }catch(err){
              res.status(401).json()
              console.error(err)
      }
}




module.exports = {
  fetchDashData
}