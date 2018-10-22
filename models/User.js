const bcrypt  = require('bcrypt')  // bcrypt encrypt the signup password to be saved in db
const crypto  = require('crypto')  // crypto decrypt the login password to be chacked against the db

//db connection configuration
const {pgconfig} = require('../DBConfig.js')
const pgp = require('pg-promise')();
const db = pgp(pgconfig);

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
    'insert into mymes.users(username, password_digest, token, created_at, email, "currentAuthority") VALUES ($1, $2, $3, $4, $5, $6) RETURNING  username, created_at, token, email, "currentAuthority"' ,
    [user.userName, user.password_digest, user.token, new Date(), user.email, user.currentAuthority]
  )
}

//Create a new random token 
const createToken = () => {
  return new Promise((resolve, reject) => {
    crypto.randomBytes(16, (err, data) => {
      err ? reject(err) : resolve(data.toString('base64'))
    })
  })
}

//fetches user's data from db 
const findUser = (userReq) => {
  return db.one('select * from mymes.users where username = $1', [userReq.userName])
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
  return db.one('update mymes.users set token = $1 where id = $2 returning id, username, token', [token, user.id])
}


const findByToken = (token) => {
  return db.one('select * from mymes.users where token = $1', [token])
}

const getAuthority = () => {return {status: 'ok', type:'account'}}

const authenticate = (userReq) => {
  return findByToken(userReq.token)
    .then((user) => {
      console.log("user",user,user.USERNAME == userReq.userName)
      return (user.USERNAME == userReq.userName) 
  }).catch((err) => false)
}

const signup = (request, response, next) => {
   const user = request.body
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
    .catch((err) => console.error(err))
}

const signin = (request, response) => {
  const userReq = request.body
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