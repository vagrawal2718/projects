import mongoose from "mongoose";

const orderSchema = mongoose.Schema(
  {
    buyer: { 
      type: mongoose.Schema.Types.ObjectId, 
      required: true, 
      ref: "User"  // Buyer is the user placing the order
    },

    seller: { 
      type: mongoose.Schema.Types.ObjectId, 
      required: true, 
      ref: "User"  // Seller is extracted from the product details
    },

    orderItems: [
      {
        name: { type: String, required: true },
        qty: { type: Number, required: true },
        image: { type: String, required: true },
        price: { type: Number, required: true },
        product: {
          type: mongoose.Schema.Types.ObjectId,
          required: true,
          ref: "Product",
        },
      },
    ],

    shippingAddress: {
      address: { type: String, required: true },
      city: { type: String, required: true },
      postalCode: { type: String, required: true },
      country: { type: String, required: true },
    },

    transactionId: {
      type: String,
      required: true,
      unique: true,
    },

    itemsPrice: {
      type: Number,
      required: true,
      default: 0.0,
    },

    taxPrice: {
      type: Number,
      required: true,
      default: 0.0,
    },

    shippingPrice: {
      type: Number,
      required: true,
      default: 0.0,
    },

    totalPrice: {
      type: Number,
      required: true,
      default: 0.0,
    },

    isPaid: {
      type: Boolean,
      required: true,
      default: false,
    },

    paidAt: {
      type: Date,
    },

    isDelivered: {
      type: Boolean,
      required: true,
      default: false,
    },

    deliveredAt: {
      type: Date,
    },

    // OTP fields (Will be hashed in `orderController.js`)
    otp: { type: String, required: false }, 
    otpVerified: { type: Boolean, default: false },
  },
  {
    timestamps: true,
  }
);

const Order = mongoose.model("Order", orderSchema);
export default Order;
