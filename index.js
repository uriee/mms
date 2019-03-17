const express = require('express');
const User = require('./models/User')
const {fetch, fetchTags, update, insert, remove, fetchNotifications, fetchRoutes, runQuery, func} = require('./models/Schemas')
const {fetchDashData} = require('./models/Dash')
const { bugInsert } = require('./models/utils')
const app = express();
const bodyParser = require('body-parser');
const cors = require('cors');

app.use(bodyParser.urlencoded({
    extended: true
}));

app.use(bodyParser.json());

const port = process.env.PORT || 4001;
const router = express.Router();

app.use(function(req, res, next) {
    res.header("Access-Control-Allow-Origin", "*");
    res.header('Cache-Control', 'no-cache');
    res.header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
    next();
});

const entityDict = {
  'user' : 'users',
  'profile': 'profiles',
  'emp': 'employees',
  'part': 'parts',
  'serials': 'serials',
  'serial_statuses': 'serial_statuses',
  'actions' : 'actions',
  'dept': 'departments',
  'equipment': 'equipments',
  'resourceGroup': 'resource_groups',
  'resource': 'resources',
  'availabilityProfile': 'availability_profiles',
  'locations' : 'locations',
  'kit' : 'kit',
  'process' : 'process',
  'proc_act' : 'proc_act',
  'serial_act' : 'serial_act',
  'work_report' : 'work_report', 
  'identifier ' : 'identifier',
  'preferences' : 'preferences'  
}
const getEntity = (entity) => entityDict[entity] || entity



app.post('/mymes/signin', User.signin)
app.post('/mymes/signup', (req,res) => User.signup(req,res))
app.post('/mymes/remove', (req,res) => remove(req,res,getEntity(req.body.entity)))
app.post('/mymes/update', (req,res) => update(req,res,getEntity(req.body.entity)))
app.post('/mymes/insert', (req,res) => req.body.entity === 'user' ? User.signup(req,res) :  insert(req,res,getEntity(req.body.entity)))
app.post('/mymes/func', (req,res) => func(req,res,getEntity(req.body.entity)))

app.post('/mymes/updateroutes', (req,res) => {
     res.status(201).json({main:2})
   runQuery(`update routes set routes = '${req.body.routes}'`)
 })


router.get('/fetch', async (req,res) => {
      const x= await User.authenticate(req,res) 
      console.log(':1234567890:',x)
    if (x) {
      fetch(req,res,getEntity(req.query.entity))
    } else {
      res.status(403)
    }
  }) 

router.get('/notifications', (req,res) => fetchNotifications(req, res))
router.get('/tags', (req,res) => fetchTags(req, res, 'tags'))
router.get('/routes', (req,res) => fetchRoutes(req, res))
router.get('/dash', (req,res) => fetchDashData(req, res))

app.post('/mymes/bug', (req,res) => bugInsert(req,res))

app.post('/secure', async (request, response) => {
  const userReq = request.body
  const a = await User.authenticate(userReq)
  if (a === true)  response.status(201).json({ message: 'YOU ARE authenticated'})
  if (a === false) response.status(404).json({ message: 'YOU ARE not authenticated'})
});

router.get('/test', function(req, res) {
 User.test()
});

app.use('/mymes', router);
app.listen(port);
console.log('Magic happens on port ' + port);
