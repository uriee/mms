const express = require('express');
const User = require('./models/User')
const {
  fetch,
  update,
  insert,
  remove,
  fetchNotifications,
  fetchRoutes,
  fetchTags,
  fetchResources,
  batchUpdate,
  batchInsert,
  runQuery,
  func,
  runFunc,
  importSerial,
  exportWorkReport,
  approveWorkReports ,
  markNotificationAsRead,
  changeUserLang
} = require('./models/Schemas')
const {fetchDashData} = require('./models/Dash')
const { bugInsert } = require('./models/utils')
const app = express();
const bodyParser = require('body-parser')
app.use(bodyParser.json({limit: "50mb"})) 
app.use(bodyParser.urlencoded({limit: "50mb", extended: true, parameterLimit:50000}));
const cors = require('cors')

// Object for rendering Reports
const fs = require('fs')
const path = require('path')
const puppeteer = require('puppeteer')
const pug = require('pug')
const sass = require('node-sass')
const SassOprions = sass.Options

app.use(bodyParser.urlencoded({
    extended: true
}));

app.use(bodyParser.json());

const port = process.env.PORT || 4001;
const router = express.Router();

app.use(function(req, res, next) {
    res.header("Access-Control-Allow-Origin", "*");
    //res.header('Cache-Control', 'no-cache');
    res.header('Cache-Control', 'no-store, no-cache, must-revalidate, private') ;
    res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
    next();
});

const entityDict = {
  'user' : 'users',
  'profile': 'profiles',
  'emp': 'employees',
  'part': 'parts',
  'serial_statuses': 'serial_statuses',
  'dept': 'departments',
  'equipment': 'equipments',
  'resourceGroup': 'resource_groups',
  'resource': 'resources',
  'availabilityProfile': 'availability_profiles',
  'process_act_resources' : 'act_resources',
  'serial_act_resources' : 'act_resources',
}
const getEntity = (entity) => entityDict[entity] || entity

const createPDF = async (req, res, next)  => {
  const body = req.body
  const sass_file = {file :path.resolve(__dirname+'/templates','table.scss')}
  const pug_file = path.resolve(__dirname+'/templates','serials.pug')
  const browser = await puppeteer.launch({ headless: true })
  const page = await browser.newPage()  

  const compiledStyle = sass.renderSync({...sass_file});
  let  Template = {
      ...body,
      compiledStyle: compiledStyle.css,
  }
  let renderedTemplate = pug.renderFile(pug_file, Template) 
  //await page.goto(`data:text/html,${renderedTemplate}`,  {waitUntil: ['load', 'domcontentloaded', 'networkidle0']});
  await page.setContent(renderedTemplate)
  const buffer = await page.pdf({format: 'A4'});
  await browser.close()
  res.end(buffer)
}

app.post('/mymes/signin', User.signin)
//app.post('/mymes/signup', (req,res) => User.signup(req,res))
app.post('/mymes/remove', (req,res) => User.authenticate(req,res,() => remove(req,res,getEntity(req.body.entity))))
app.post('/mymes/update', (req,res) => User.authenticate(req,res,() => update(req,res,getEntity(req.body.entity))))
app.post('/mymes/insert', (req,res) => req.body.entity === 'user' ? User.signup(req,res) :  User.authenticate(req,res,() => insert(req,res,getEntity(req.body.entity))))
app.post('/mymes/func', (req,res) => User.authenticate(req,res,() => func(req,res,getEntity(req.body.entity))))

app.post('/mymes/updateroutes', async (req,res) => {
    try{
      await runQuery(`update routes set routes = '${req.body.routes}'`)
      res.status(201).json({main:2})
    } catch(err) {
      console.error(err)
      res.status(406).json({error:err})
    }
 })

app.post('/mymes/updateResources', (req,res) => {
    let {body} = req
    body.table = 'resource_groups'    
    batchUpdate(body,res)
 })


//app.post('/mymes/importdata', (req,res) => importData(req,res))
app.post('/mymes/importdata', (req,res) => batchInsert(req,res,getEntity(req.body.entity)))


router.get('/fetch', async (req,res) => await User.authenticate(req,res,() => fetch(req,res,getEntity(req.query.entity)))) 
router.get('/tags', async (req,res) => await User.authenticate(req,res,() => fetchTags(req, res, 'tags'))) 
router.get('/resources', async (req,res) => await User.authenticate(req,res,() => fetchResources(req, res))) 
//router.get('/notifications', (req,res) => fetchNotifications(req, res))
router.get('/notifications', (req,res) => User.authenticate(req,res,()=>fetchNotifications(req, res),status=208)) 
router.get('/routes', (req,res) => fetchRoutes(req, res))
router.get('/dash', (req,res) => User.authenticate(req,res,()=>fetchDashData(req, res)))
router.get('/exportWorkReport', (req,res) => exportWorkReport(req, res))

app.post('/mymes/bug', (req,res) => bugInsert(req,res))

app.post('/secure', async (request, response) => {
  const userReq = request.body
  const a = await User.authenticate(userReq)
  if (a === true)  response.status(201).json({ message: 'YOU ARE authenticated'})
  if (a === false) response.status(404).json({ message: 'YOU ARE not authenticated'})
});

app.post('/mymes/test', (req,res) => {
  createPDF(req,res)   
})


app.post('/mymes/importserial', (req,res) => importSerial(req,res))
app.post('/mymes/approveWorkReports', (req,res) => approveWorkReports(req,res))
app.post('/mymes/markNotificationAsRead', (req,res) => markNotificationAsRead(req,res))
app.post('/mymes/changeUserLang', (req,res) => changeUserLang(req,res))
app.use('/mymes', router);


app.listen(port);
console.log('Magic happens on port ' + port);
