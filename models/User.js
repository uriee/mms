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
    `insert into users(username, password_digest, token, created_at, "currentAuthority",profile_id) 
      select $1, $2, $3, $4, $5, id
      from profiles where name = $5 
       RETURNING  username, created_at, token,"currentAuthority"` ,
    [user.name, user.password_digest, user.token, new Date(), user.currentAuthority]
  )
}


const changeUserPassword = (userName, newPassword) => {
  return findUser({userName : userName})  
    .then(user=> hashPassword(newPassword)
      .then((hashedPassword) => {
        user.password_digest = hashedPassword
      })
      .then(() => createToken())
      .then(token => user.token = token)
      .then(() => updateUserPassword(user))
      .catch((err) => {
        response.status(401).json(user)
        console.error(err)
      })
    )
}

const updateUserPassword = (user) => {
  return db.one(
    `update users
    set password_digest = $1,
    token = $2
    where id = $3  RETURNING  id;` ,
    [user.password_digest, user.token, user.id]
  )
}

//Create a new random token 
const createToken = () => {
  return new Promise((resolve, reject) => {
    crypto.randomBytes(16, (err, data) => {
      err ? reject(err) : resolve(data.toString('hex'))
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


const findByToken =  async (token,user,auth) => {
  try { 
    return await db.one(`select * from users where token = $1 and username = $2 and "currentAuthority" = $3;`, [token,user,auth])
  }catch(err){
    return null;
  }
}

const getAuthority = () => {return {status: 'ok', type:'account'}}

const authenticate = async (req,res,next,status=408) => {
  const Utoken = (req.method == 'GET' ? req.query.token : req.body.token)
  const userName = (req.method == 'GET' ? req.query.user : req.body.user)
  let auth = (req.method == 'GET' ? req.query.auth : req.body.auth)
  auth = auth && auth.split('"')[1]  
  const isAuth = Utoken && userName && auth  && auth[0] && await findByToken(Utoken,userName,auth) ? true : false   
  if (!isAuth)  {
    res.status(status).json({err : 'Not Authorized'})
    return isAuth
  } else return next();  
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
    .catch((err) => {
      response.status(401).json(user)
      console.error(err)
    })
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
    .then(token => {
      user.token = token
      return updateUserToken(token, user)
    })
    .then(x => getAuthority(user.id))
    .then((auth) => {
      user = {...user, ...auth , name: user.username}
      delete user.password_digest
      response.status(200).json(user)
    })
    .catch((err) => {
      response.status(401).json(user)
      console.error(err)
    })
}

const logoff = (request, response) => {}

module.exports = {
  signup, signin, authenticate ,changeUserPassword
}