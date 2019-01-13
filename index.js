const express = require('express');
const User = require('./models/User')
const {fetch, fetchTags, update, insert, remove, fetchByName, fetchRoutes, runQuery} = require('./models/Schemas')
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
  'proc_act' : 'proc_act'
}
const getEntity = (entity) => entityDict[entity] || entity

app.post('/mymes/signin', User.signin)
app.post('/mymes/remove', (req,res) => remove(req,res,getEntity(req.body.entity)))
app.post('/mymes/update', (req,res) => update(req,res,getEntity(req.body.entity)))
app.post('/mymes/insert', (req,res) => insert(req,res,getEntity(req.body.entity)))
app.post('/mymes/updateroutes', (req,res) => {
     res.status(201).json({main:2})
   runQuery(`update routes set routes = '${req.body.routes}'`)
 })
router.get('/t', function(req, res) {
    res.json({
        message: 'hooray! welcome to our api!'
    });
});

router.get('/user', (req,res) => fetch(req, res, 'users'))
router.get('/profile', (req,res) => fetch(req, res, 'profiles'))
router.get('/emp', (req,res) => fetch(req, res, 'employees'))
router.get('/part', (req,res) => fetch(req, res, 'parts'))
router.get('/dept', (req,res) => fetch(req, res, 'departments'))
router.get('/equipment', (req,res) => fetch(req, res, 'equipments'))
router.get('/resourceGroup', (req,res) => fetch(req, res, 'resource_groups'))
router.get('/resource', (req,res) => fetch(req, res, 'resources'))
router.get('/availabilityProfile', (req,res) => fetch(req, res, 'availability_profiles'))
router.get('/availabilities', (req,res) => fetch(req, res, 'availabilities'))
router.get('/malfunctions', (req,res) => fetch(req, res, 'malfunctions'))
router.get('/malfunction_types', (req,res) => fetch(req, res, 'malfunction_types'))
router.get('/repairs', (req,res) => fetch(req, res, 'repairs'))
router.get('/repair_types', (req,res) => fetch(req, res, 'repair_types'))
router.get('/mnt_plans', (req,res) => fetch(req, res, 'mnt_plans'))
router.get('/mnt_plan_items', (req,res) => fetch(req, res, 'mnt_plan_items'))
router.get('/serials', (req,res) => fetch(req, res, 'serials'))
router.get('/serial_statuses', (req,res) => fetch(req, res, 'serial_statuses'))
router.get('/actions', (req,res) => fetch(req, res, 'actions'))
router.get('/locations', (req,res) => fetch(req, res, 'locations'))
router.get('/kit', (req,res) => fetch(req, res, 'kit'))
router.get('/process', (req,res) => fetch(req, res, 'process'))
router.get('/proc_act', (req,res) => fetch(req, res, 'proc_act'))
router.get('/tags', (req,res) => fetchTags(req, res, 'tags'))
router.get('/routes', (req,res) => fetchRoutes(req, res))

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
