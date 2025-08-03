import User from '../models/userModel.js';
import asyncHandler from '../middlewares/asyncHandler.js';
import bcrypt from 'bcryptjs';
import createToken from '../utils/createToken.js';

const createUser = asyncHandler(async (req, res) => {
  const { firstName, lastName, username, email, password, age, contactNumber } = req.body;

  if (!firstName || !lastName || !username || !email || !password || !age || !contactNumber) {
    res.status(400);
    throw new Error("Please fill all fields");
  }

  // Check if email or username is already taken
  const emailExists = await User.findOne({ email });
  const usernameExists = await User.findOne({ username });

  if (emailExists) {
    res.status(400);
    throw new Error("Email already in use");
  }

  if (usernameExists) {
    res.status(400);
    throw new Error("Username already taken");
  }

  // Hash password before storing
  const salt = await bcrypt.genSalt(10);
  const hashedPassword = await bcrypt.hash(password, salt);

  // Create new user with updated fields
  const newUser = new User({
    firstName,
    lastName,
    username,
    email,
    password: hashedPassword,
    age,
    contactNumber,
  });

  try {
    await newUser.save();
    createToken(res, newUser._id);

    res.status(201).json({
      _id: newUser._id,
      firstName: newUser.firstName,
      lastName: newUser.lastName,
      username: newUser.username,
      email: newUser.email,
      age: newUser.age,
      contactNumber: newUser.contactNumber,
    });
  } catch (error) {
    res.status(400);
    throw new Error("Invalid user data");
  }
});

const loginUser = asyncHandler(async (req, res) => {
  const { email, password } = req.body;

  const existingUser = await User.findOne({ email });

  if (existingUser) {
    const isPasswordCorrect = await bcrypt.compare(password, existingUser.password);
    if (isPasswordCorrect) {
      createToken(res, existingUser._id);
      res.status(200).json({
        _id: existingUser._id,
        firstName: existingUser.firstName,
        lastName: existingUser.lastName,
        username: existingUser.username,
        email: existingUser.email,
        age: existingUser.age,
        contactNumber: existingUser.contactNumber,
        isAdmin: existingUser.isAdmin
      });
      return;
    }
  }

  console.log("Login Response:", userResponse);
  res.status(401);
  if (!/^[a-zA-Z0-9._%+-]+@iiit.ac.in$/.test(email)) {
    res.status(400);
    throw new Error("Only IIIT emails are allowed!");
  }
});


const logoutCurrentUser = asyncHandler(async (req, res) => {
 res.cookie('token', null, {
   httpOnly: true,
   expires: new Date(0)
 });
 res.status(200).json({message: 'Logged out successfully'});
});

const getAllUsers = asyncHandler(async (req, res) => {
  const users = await User.find({});
  res.status(200).json(users);
});

const getCurrentUserProfile = asyncHandler(async (req, res) => {
  const user = await User.findById(req.user._id);

  if (user) {
    res.json({
      _id: user._id,
      firstName: user.firstName,
      lastName: user.lastName,
      username: user.username,
      email: user.email,
      age: user.age,
      contactNumber: user.contactNumber,
      sellerReviews: user.sellerReviews,
    });
  } else {
    res.status(404);
    throw new Error("User not found");
  }
});

const updateCurrentUserProfile = asyncHandler(async (req, res) => {
  const user = await User.findById(req.user._id);

  if (user) {
    user.firstName = req.body.firstName || user.firstName;
    user.lastName = req.body.lastName || user.lastName;
    user.username = req.body.username || user.username;
    user.email = req.body.email || user.email;
    user.age = req.body.age || user.age;
    user.contactNumber = req.body.contactNumber || user.contactNumber;

    if (req.body.password) {
      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(req.body.password, salt);
      user.password = hashedPassword;
    }

    const updatedUser = await user.save();
    res.json({
      _id: updatedUser._id,
      firstName: updatedUser.firstName,
      lastName: updatedUser.lastName,
      username: updatedUser.username,
      email: updatedUser.email,
      age: updatedUser.age,
      contactNumber: updatedUser.contactNumber,
    });
  } else {
    res.status(404);
    throw new Error("User not found");
  }
});


const deleteUserById= asyncHandler(async (req, res) => {
  const user = await User.findById(req.params.id);
  if(user){
    if(user.isAdmin){
      res.status(400);
      throw new Error('Admin user cannot be deleted');
    }
    await user.deleteOne({_id:user._id});
    res.json({message: 'User removed'});
  }
  else{
    res.status(404);
    throw new Error('User not found');
  }
});

const getUserById = asyncHandler(async (req, res) => { 
  const user = await User.findById(req.params.id).select('-password');

  if (user) {
    // Compute seller rating
    const totalRating = user.sellerReviews.reduce((acc, review) => acc + review.rating, 0);
    const numReviews = user.sellerReviews.length;
    const sellerRating = numReviews > 0 ? (totalRating / numReviews).toFixed(1) : "No ratings yet";

    res.json({
      _id: user._id,
      firstName: user.firstName,
      lastName: user.lastName,
      username: user.username,
      email: user.email,
      age: user.age,
      contactNumber: user.contactNumber,
      sellerReviews: user.sellerReviews,
      sellerRating,
    });
  } else {
    res.status(404);
    throw new Error("User not found");
  }
});



const updateUserById = asyncHandler(async (req, res) => {  
  const user = await User.findById(req.params.id);

  if (user) {
    user.firstName = req.body.firstName || user.firstName;
    user.lastName = req.body.lastName || user.lastName;
    user.username = req.body.username || user.username;
    user.email = req.body.email || user.email;
    user.age = req.body.age || user.age;
    user.contactNumber = req.body.contactNumber || user.contactNumber;
    user.isAdmin = req.body.isAdmin !== undefined ? req.body.isAdmin : user.isAdmin;

    if (req.body.password) {
      const salt = await bcrypt.genSalt(10);
      const hashedPassword = await bcrypt.hash(req.body.password, salt);
      user.password = hashedPassword;
    }

    const updatedUser = await user.save();
    res.json({
      _id: updatedUser._id,
      firstName: updatedUser.firstName,
      lastName: updatedUser.lastName,
      username: updatedUser.username,
      email: updatedUser.email,
      age: updatedUser.age,
      contactNumber: updatedUser.contactNumber,
      isAdmin: updatedUser.isAdmin
    });
  } else {
    res.status(404);
    throw new Error("User not found");
  }
});

export {createUser, loginUser, logoutCurrentUser, getAllUsers, getCurrentUserProfile,updateCurrentUserProfile, deleteUserById, getUserById,updateUserById};