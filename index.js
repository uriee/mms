const express = require('express');
const User = require('./models/User')
const {fetch,fetch2, update, insert, fetchByName} = require('./models/Schemas')
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

app.post('/mymes/signup', User.signup)
app.post('/signin', User.signin)
app.post('/mymes/signin', User.signin)
app.post('/mymes/insert/emp', (req,res) => insert(req,res,'employees'))
app.post('/mymes/update/emp', (req,res) => update(req,res,'employees'))
app.post('/mymes/insert/part', (req,res) => insert(req,res,'parts'))
app.post('/mymes/update/part', (req,res) => update(req,res,'parts'))
app.post('/mymes/insert/dept', (req,res) => insert(req,res,'departments'))
app.post('/mymes/update/dept', (req,res) => update(req,res,'departments'))
app.post('/mymes/update/user', (req,res) => update(req,res,'users'))
app.post('/mymes/update/machine', (req,res) => update(req,res,'machines'))
app.post('/mymes/insert/machine', (req,res) => insert(req,res,'machines'))
app.post('/mymes/update/resourceGroup', (req,res) => update(req,res,'resource_groups'))
app.post('/mymes/insert/resourceGroup', (req,res) => insert(req,res,'resource_groups'))
app.post('/mymes/update/resource', (req,res) => update(req,res,'resources'))
app.post('/mymes/insert/resource', (req,res) => insert(req,res,'resources'))
app.post('/mymes/update/availabilityProfile', (req,res) => update(req,res,'availability_profiles'))
app.post('/mymes/insert/availabilityProfile', (req,res) => insert(req,res,'availability_profiles'))
app.post('/mymes/update/availabilities', (req,res) => update(req,res,'availabilities'))
app.post('/mymes/insert/availabilities', (req,res) => insert(req,res,'availabilities'))

router.get('/t', function(req, res) {
    res.json({
        message: 'hooray! welcome to our api!'
    });
});

router.get('/user', (req,res) => fetch(req, res, 'users'))
router.get('/emp', (req,res) => fetch(req, res, 'employees'))
router.get('/part', (req,res) => fetch(req, res, 'parts'))
router.get('/dept', (req,res) => fetch(req, res, 'departments'))
router.get('/machine', (req,res) => fetch(req, res, 'machines'))
router.get('/resourceGroup', (req,res) => fetch(req, res, 'resource_groups'))
router.get('/resource', (req,res) => fetch(req, res, 'resources'))
router.get('/availabilityProfile', (req,res) => fetch(req, res, 'availability_profiles'))
router.get('/availabilities', (req,res) => fetch(req, res, 'availabilities'))

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
