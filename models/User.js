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
    'INSERT INTO "MyMES"."USERS"("USERNAME", "PASSWORD_DIGEST", "TOKEN", "CREATED_AT") VALUES ($1, $2, $3, $4) RETURNING "USERID", "USERNAME", "CREATED_AT", "TOKEN"',
    [user.username, user.password_digest, user.token, new Date()]
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
  console.log('finduser:',userReq)
  return db.one('SELECT * FROM "MyMES"."USERS" WHERE "USERNAME" = $1', [userReq.username])
}

//check if the users's input password match the user data password
const checkPassword = (reqPassword, foundUser) => {
  return new Promise((resolve, reject) =>
    bcrypt.compare(reqPassword, foundUser.PASSWORD_DIGEST, (err, response) => {
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
  return db.one('UPDATE "MyMES"."USERS" SET "TOKEN" = $1 WHERE "USERID" = $2 RETURNING "USERID", "USERNAME", "TOKEN"', [token, user.USERID])
}


const findByToken = (token) => {
  return db.one('SELECT * FROM "MyMES"."USERS" WHERE "TOKEN" = $1', [token])
}

const authenticate = (userReq) => {
  return findByToken(userReq.token)
    .then((user) => {
      console.log("user",user,user.USERNAME == userReq.username)
      return (user.USERNAME == userReq.username) 
  }).catch((err) => false)
}

const signup = (request, response) => {
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
    .then(() => {
      delete user.PASSWORD_DIGEST
      console.log(user)
      response.status(200).json(user)
    })
    .catch((err) => console.error(err))
}

const logoff = (request, response) => {}

module.exports = {
  signup, signin, authenticate
}