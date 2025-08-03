import express from "express";
const router = express.Router();

import {
  createOrder,
  verifyOrderOtp, // 🔹 Added OTP verification route
  getAllOrders,
  getUserOrders,
  countTotalOrders,
  calculateTotalSales,
  calcualteTotalSalesByDate,
  findOrderById,
  markOrderAsPaid,
  markOrderAsDelivered,
} from "../controllers/orderController.js";

import { authenticate, authorizeAdmin } from "../middlewares/authMiddleware.js";

router
  .route("/")
  .post(authenticate, createOrder)
  .get(authenticate, authorizeAdmin, getAllOrders);

router.route("/mine").get(authenticate, getUserOrders);
router.route("/total-orders").get(countTotalOrders);
router.route("/total-sales").get(calculateTotalSales);
router.route("/total-sales-by-date").get(calcualteTotalSalesByDate);
router.route("/:id").get(authenticate, findOrderById);

// 🔹 New route for OTP verification before marking order as paid
router.route("/:id/verify-otp").post(authenticate, verifyOrderOtp);

router.route("/:id/pay").put(authenticate, markOrderAsPaid);
router.route("/:id/deliver").put(authenticate, authorizeAdmin, markOrderAsDelivered);

export default router;
