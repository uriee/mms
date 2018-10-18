const express = require('express');
const User = require('./models/User')
const Employee = require('./models/Employee')
const {fetch, update, insert, fetchByName} = require('./models/Schemas')
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
app.post('/mymes/update', Employee.upd)
app.post('/mymes/insert/emp', (req,res) => insert(req,res,'employees'))

router.get('/t', function(req, res) {
    res.json({
        message: 'hooray! welcome to our api!'
    });
});

router.get('/employees', (req,res) => fetch(req, res, 'employees'))



app.post('/secure', async (request, response) => {
  const userReq = request.body
  const a = await User.authenticate(userReq)
  console.log("1:",userReq,a)
  if (a === true)  response.status(201).json({ message: 'YOU ARE authenticated'})
  if (a === false) response.status(404).json({ message: 'YOU ARE not authenticated'})
});

router.get('/test', function(req, res) {
 User.test()
});

app.use('/mymes', router);
app.listen(port);
console.log('Magic happens on port ' + port);
