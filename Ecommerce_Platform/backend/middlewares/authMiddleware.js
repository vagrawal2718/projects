import jwt from 'jsonwebtoken';
import User from '../models/userModel.js';
import asyncHandler from './asyncHandler.js';

const authenticate = asyncHandler(async (req, res, next) => {
  let token;
  
  token = req.cookies.token;
  console.log('Token from cookie:', token); 
  if (token) {
    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      console.log('Decoded Token:', decoded); // Debug log

      req.user = await User.findById(decoded.userId).select('-password');
      console.log('Authenticated User:', req.user); // Debug log

      next();
    } catch {
      console.error('Token verification failed:', error);
      res.status(401);
      throw new Error('Not authorized, token failed');
    }
  }
  else {
    console.error('No token provided');
    res.status(401);
    throw new Error('Not authorized, no token');
  }
});

//Is the user an admin
const authorizeAdmin = (req, res, next) => {
  //console.log('User in authorizeAdmin:', req.user); // Debug log

  if(req.user && req.user.isAdmin){
    next();
  }else{
    res.status(401);
    throw new Error('Not authorized as an admin');
  } 
}

export {authenticate, authorizeAdmin};