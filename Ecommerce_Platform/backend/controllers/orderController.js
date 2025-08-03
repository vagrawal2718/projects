import Order from "../models/orderModel.js";
import Product from "../models/productModel.js";
import crypto from "crypto"; // To generate transactionId
import bcrypt from "bcryptjs"; // For hashing OTP
import { v4 as uuidv4 } from "uuid"; // For generating transaction IDs

// Utility Function
function calcPrices(orderItems) {
  const itemsPrice = orderItems.reduce(
    (acc, item) => acc + item.price * item.qty,
    0
  );

  const shippingPrice = itemsPrice > 100 ? 0 : 10;
  const taxRate = 0.15;
  const taxPrice = (itemsPrice * taxRate).toFixed(2);

  const totalPrice = (
    itemsPrice +
    shippingPrice +
    parseFloat(taxPrice)
  ).toFixed(2);

  return {
    itemsPrice: itemsPrice.toFixed(2),
    shippingPrice: shippingPrice.toFixed(2),
    taxPrice,
    totalPrice,
  };
}

// Utility Function for OTP
const generateOTP = () => Math.floor(100000 + Math.random() * 900000).toString(); // 6-digit OTP

const createOrder = async (req, res) => {
  try {
    console.log("Incoming Order Request:", req.body);

    const { orderItems, shippingAddress, paymentMethod } = req.body;

    if (!orderItems || orderItems.length === 0) {
      return res.status(400).json({ error: "No order items" });
    }

    console.log("Order Items Received:", orderItems);

    const itemsFromDB = await Product.find({
      _id: { $in: orderItems.map((x) => x._id) },
    }).populate("seller", "_id name email");

    console.log("Items Fetched From DB:", itemsFromDB);

    if (!itemsFromDB.length) {
      return res.status(400).json({ error: "Products not found" });
    }

    const dbOrderItems = orderItems.map((itemFromClient) => {
      const matchingItemFromDB = itemsFromDB.find(
        (itemFromDB) => itemFromDB._id.toString() === itemFromClient._id
      );

      if (!matchingItemFromDB) {
        throw new Error(`❌ Product not found: ${itemFromClient._id}`);
      }

      if (!matchingItemFromDB.seller || !matchingItemFromDB.seller._id) {
        throw new Error(`❌ Seller not found for product: ${itemFromClient._id}`);
      }

      if (matchingItemFromDB.seller._id.toString() === req.user._id.toString()) {
        throw new Error("⚠️ You cannot buy from yourself.");
      }

      return {
        name: matchingItemFromDB.name,
        qty: itemFromClient.qty,
        image: matchingItemFromDB.image,
        price: matchingItemFromDB.price,
        product: matchingItemFromDB._id,
        seller: matchingItemFromDB.seller._id,
      };
    });

    console.log("Formatted Order Items:", dbOrderItems);

    const { itemsPrice, taxPrice, shippingPrice, totalPrice } = calcPrices(dbOrderItems);

    // ✅ Generate OTP but DO NOT store in the database
    const plainOtp = generateOTP();
    console.log("Generated OTP:", plainOtp);

    // ✅ Generate a unique Transaction ID
    const transactionId = crypto.randomBytes(16).toString("hex");

    // ✅ Create order without storing OTP
    const order = new Order({
      buyer: req.user._id,
      seller: dbOrderItems[0].seller,
      orderItems: dbOrderItems,
      shippingAddress,
      paymentMethod,
      itemsPrice,
      taxPrice,
      shippingPrice,
      totalPrice,
      transactionId,
      otpVerified: false,
      isPaid: false,
      isDelivered: false,
    });

    console.log("Order Before Saving:", order);

    const createdOrder = await order.save();
    console.log("✅ Order Created Successfully:", createdOrder);

    // ✅ Send OTP in response but NOT store it in DB
    res.status(201).json({
      message: "Order Created. Enter OTP to confirm payment.",
      orderId: createdOrder._id,
      transactionId: createdOrder.transactionId,
      otp: plainOtp, // ⚠️ Only sent to frontend (DO NOT store in DB)
    });
  } catch (error) {
    console.error("❌ Error Creating Order:", error.message);
    res.status(500).json({ error: error.message });
  }
};


// 🔹 Function to verify OTP and mark order as paid
const verifyOrderOtp = async (req, res) => {
  try {
    console.log("🔹 Incoming OTP Verification Request:", req.body);
    
    const { enteredOtp } = req.body; // ✅ Extract only `enteredOtp` from the body
    const orderId = req.params.id;

    console.log(`🔹 Looking for Order: ${orderId}`);
    const order = await Order.findById(orderId);

    if (!order) {
      return res.status(404).json({ error: "Order not found" });
    }

    console.log("✅ Found Order:", order._id);
    console.log("🔹 Stored Hashed OTP:", order.otp);
    // 🔹 Compare entered OTP with stored hashed OTP
    const isMatch = await bcrypt.compare(enteredOtp, order.otp);

    if (!isMatch) {
      return res.status(400).json({ error: "Invalid OTP" });
    }

    // 🔹 Mark order as paid
    order.isPaid = true;
    order.paidAt = Date.now();
    order.otpVerified = true;

    await order.save();
    console.log("✅ OTP Verified & Order Paid:", order._id);

    res.json({ message: "Order verified successfully and marked as paid" });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const getAllOrders = async (req, res) => {
  try {
    const orders = await Order.find({}).populate("buyer", "id username");
    res.json(orders);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const getUserOrders = async (req, res) => {
  try {
    const orders = await Order.find({ buyer: req.user._id });
    res.json(orders);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const countTotalOrders = async (req, res) => {
  try {
    const totalOrders = await Order.countDocuments();
    res.json({ totalOrders });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const calculateTotalSales = async (req, res) => {
  try {
    const orders = await Order.find();
    const totalSales = orders.reduce((sum, order) => sum + order.totalPrice, 0);
    res.json({ totalSales });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const calcualteTotalSalesByDate = async (req, res) => {
  try {
    const salesByDate = await Order.aggregate([
      {
        $match: {
          isPaid: true,
        },
      },
      {
        $group: {
          _id: {
            $dateToString: { format: "%Y-%m-%d", date: "$paidAt" },
          },
          totalSales: { $sum: "$totalPrice" },
        },
      },
    ]);

    res.json(salesByDate);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const findOrderById = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id)
      .populate("buyer", "username email") // ✅ Correct field name
      .populate("seller", "username email"); // ✅ Fetch seller info

    if (!order) {
      return res.status(404).json({ message: "Order not found" });
    }

    res.json(order); // ✅ Ensure response contains `buyer`
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
};


const markOrderAsPaid = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id);

    if (order) {
      order.isPaid = true;
      order.paidAt = Date.now();
      order.paymentResult = {
        id: req.body.id,
        status: req.body.status,
        update_time: req.body.update_time,
        email_address: req.body.payer.email_address,
      };

      const updateOrder = await order.save();
      res.status(200).json(updateOrder);
    } else {
      res.status(404);
      throw new Error("Order not found");
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

const markOrderAsDelivered = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id);

    if (order) {
      order.isDelivered = true;
      order.deliveredAt = Date.now();

      const updatedOrder = await order.save();
      res.json(updatedOrder);
    } else {
      res.status(404);
      throw new Error("Order not found");
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

export {
  createOrder,
  verifyOrderOtp, // 🔹 Added OTP verification
  getAllOrders,
  getUserOrders,
  countTotalOrders,
  calculateTotalSales,
  calcualteTotalSalesByDate,
  findOrderById,
  markOrderAsPaid,
  markOrderAsDelivered,
};
