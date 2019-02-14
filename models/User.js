const bcrypt  = require('bcrypt')  // bcrypt encrypt the signup password to be saved in db
const crypto  = require('crypto')  // crypto decrypt the login password to be chacked against the db

//db connection configuration
const {db} = require('../DBConfig.js')
// construct the hashed password from the users password
const hashPassword = (password) => {
  return new Promise((resolve, reject) =>
    bcrypt.hash(password, 10, (err, hash) => {
      err ? reject(err) : resolve(hash)
    })
  )
}

// Create new user in db
const createUser = (user) => {
  return db.one(
    'insert into users(username, password_digest, token, created_at, "currentAuthority") VALUES ($1, $2, $3, $4, $5) RETURNING  username, created_at, token,"currentAuthority"' ,
    [user.name, user.password_digest, user.token, new Date(), user.currentAuthority]
  )
}

//Create a new random token 
const createToken = () => {
  return new Promise((resolve, reject) => {
    crypto.randomBytes(16, (err, data) => {
      err ? reject(err) : resolve(data.toString('base64'))
    })
  }).then(x => x)
}

//fetches user's data from db 
const findUser = (userReq) => {
  return db.one('select * from users where username = $1', [userReq.userName])
}


//check if the users's input password match the user data password
const checkPassword = (reqPassword, foundUser) => {
  return new Promise((resolve, reject) =>
    bcrypt.compare(reqPassword, foundUser.password_digest, (err, response) => {
        if (err) {
          reject(err)
        }
        else if (response) {
          resolve(response)
        } else {
          reject(new Error('Passwords do not match.'))
        }
    })
  )
}

//update the users TOKEN field in db
const updateUserToken = (token, user) => {
  return db.one('update users set token = $1 where id = $2 returning id, username, token', [token, user.id])
}


const findByToken = (token) => {
  return db.one('select * from users where token = $1', [token])
}

const getAuthority = () => {return {status: 'ok', type:'account'}}

const authenticate = async (req,res,next) => {
  console.log('~~~~~~~~~~~~~',req.method,req.query)
  const Utoken = (req.method == 'GET' ? req.query.token : req.body.token)
  const userName = (req.method == 'GET' ? req.query.user : req.body.user)
    console.log('~~~~~~~~~~~~~',Utoken,userName)
  const auth = await findByToken(Utoken)
    .then((user) => {
      console.log("user",user,user.username == userName)
      return (user.username == userName) 
  }).catch((err) => false)
console.log("user auth:",auth)    
  if (auth) return next(req,res)
  else return auth;  
}

const authenticate_old = (userReq) => {
  console.logf('in Authenticate:',userReq)
  return findByToken(userReq.token)
    .then((user) => {
      console.log("user",user,user.USERNAME == userReq.userName)
      return (user.USERNAME == userReq.userName) 
  }).catch((err) => false)
}

const signup = (request, response, next) => {
   const user = request.body
   console.log("user:",user)
  hashPassword(user.password)
    .then((hashedPassword) => {
      delete user.password
      user.password_digest = hashedPassword
    })
    .then(() => createToken())
    .then(token => user.token = token)
    .then(() => createUser(user))
    .then(user => {
      delete user.PASSWORD_DIGEST
      response.status(201).json({ user })
    })
    .catch((err) => {
      response.status(401).json(user)
      console.error(err)
    })
}

const signin = (request, response) => {
  const userReq = request.body
  console.log('~~~~~~~~~',userReq)
  let user
  findUser(userReq)
    .then(foundUser => {
      user = foundUser
      return checkPassword(userReq.password, foundUser)
    })
    .then((res) => createToken())
    .then(token => updateUserToken(token, user))
    .then(x => getAuthority(user.id))
    .then((auth) => {
      user = {...user, ...auth , name: user.username}
      delete user.password_digest
      console.log(user)
      response.status(200).json(user)
    })
    .catch((err) => {
      response.status(401).json(user)
      console.error(err)
    })
}

const logoff = (request, response) => {}

module.exports = {
  signup, signin, authenticate
}