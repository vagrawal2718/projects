import mongoose from "mongoose";

// Schema for individual seller reviews
const sellerReviewSchema = new mongoose.Schema(
  {
    reviewer: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true }, // Buyer who leaves review
    rating: { type: Number, min: 1, max: 5, required: true }, // 1-5 Star Rating
    comment: { type: String, required: true }, // Optional comment
  },
  { timestamps: true }
);

const userSchema = new mongoose.Schema(
  {
    firstName: { type: String, required: true },
    lastName: { type: String, required: true },
    username: { type: String, required: true, unique: true }, // ✅ Username added back
    email: { 
      type: String, 
      required: true, 
      unique: true,
      match: [/^[a-zA-Z0-9._%+-]+@iiit.ac.in$/, "Only IIIT emails are allowed!"]
    },
    age: { type: Number, required: true },
    contactNumber: { type: String, required: true },
    password: { type: String, required: true },
    isAdmin: { type: Boolean, default: true },
    sellerReviews: [sellerReviewSchema], 
  },
  { timestamps: true }
);

const User = mongoose.model("User", userSchema);
export default User;
