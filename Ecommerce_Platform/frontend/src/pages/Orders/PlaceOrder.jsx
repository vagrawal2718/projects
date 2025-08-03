import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import { toast } from "react-toastify";
import { useDispatch, useSelector } from "react-redux";
import Message from "../../components/Message";
import ProgressSteps from "../../components/ProgressSteps";
import Loader from "../../components/Loader";
import { useCreateOrderMutation } from "../../redux/api/orderApiSlice";
import { clearCartItems } from "../../redux/features/cart/cartSlice";

const PlaceOrder = () => {
  const navigate = useNavigate();
  const cart = useSelector((state) => state.cart);
  const dispatch = useDispatch();

  const [createOrder, { isLoading, error }] = useCreateOrderMutation();
  const [otp, setOtp] = useState(null); // ✅ Store OTP received from backend

  useEffect(() => {
    if (!cart.shippingAddress.address) {
      navigate("/shipping");
    }
  }, [cart.paymentMethod, cart.shippingAddress.address, navigate]);

  const placeOrderHandler = async () => {
    try {
      const res = await createOrder({
        orderItems: cart.cartItems,
        shippingAddress: cart.shippingAddress,
        paymentMethod: cart.paymentMethod,
        itemsPrice: cart.itemsPrice,
        shippingPrice: cart.shippingPrice,
        taxPrice: cart.taxPrice,
        totalPrice: cart.totalPrice,
      }).unwrap();

      console.log("✅ Order Created:", res);
      console.log("🔹 OTP from Backend:", res.otp);

      if (!res.orderId) {
        toast.error("❌ Error: Order ID is missing!");
      } else {
        // ✅ Store OTP in Local Storage
        localStorage.setItem(`order_otp_${res.orderId}`, res.otp);

        console.log("🔹 OTP Stored in Local Storage:", res.otp);

        // ✅ Update State so OTP is displayed immediately
        setOtp(res.otp);

        dispatch(clearCartItems());
        navigate(`/order/${res.orderId}`);
      }
    } catch (error) {
      console.error("❌ Error Creating Order:", error);
      toast.error(error.message || "Failed to place order.");
    }
  };

  return (
    <>
      <ProgressSteps step1 step2 step3 />

      <div className="container mx-auto mt-8">
        {cart.cartItems.length === 0 ? (
          <Message>Your cart is empty</Message>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full border-collapse">
              <thead>
                <tr>
                  <td className="px-1 py-2 text-left align-top">Image</td>
                  <td className="px-1 py-2 text-left">Product</td>
                  <td className="px-1 py-2 text-left">Quantity</td>
                  <td className="px-1 py-2 text-left">Price</td>
                  <td className="px-1 py-2 text-left">Total</td>
                </tr>
              </thead>

              <tbody>
                {cart.cartItems.map((item, index) => (
                  <tr key={index}>
                    <td className="p-2">
                      <img src={item.image} alt={item.name} className="w-16 h-16 object-cover" />
                    </td>
                    <td className="p-2">
                      <Link to={`/product/${item.product}`}>{item.name}</Link>
                    </td>
                    <td className="p-2">{item.qty}</td>
                    <td className="p-2">{item.price.toFixed(2)}</td>
                    <td className="p-2">$ {(item.qty * item.price).toFixed(2)}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}

        <div className="mt-8">
          <h2 className="text-2xl font-semibold mb-5">Order Summary</h2>
          <div className="flex justify-between flex-wrap p-8 bg-[#FFC0CB]">
            <ul className="text-lg">
              <li><span className="font-semibold mb-4">Items:</span> ${cart.itemsPrice}</li>
              <li><span className="font-semibold mb-4">Shipping:</span> ${cart.shippingPrice}</li>
              <li><span className="font-semibold mb-4">Tax:</span> ${cart.taxPrice}</li>
              <li><span className="font-semibold mb-4">Total:</span> ${cart.totalPrice}</li>
            </ul>

            {error && <Message variant="danger">{error.data.message}</Message>}

            <div>
              <h2 className="text-2xl font-semibold mb-4">Shipping</h2>
              <p><strong>Address:</strong> {cart.shippingAddress.address}, {cart.shippingAddress.city} {cart.shippingAddress.postalCode}, {cart.shippingAddress.country}</p>
            </div>

            <div>
              <h2 className="text-2xl font-semibold mb-4">Payment Method</h2>
              <strong>Method:</strong> {cart.paymentMethod}
            </div>
          </div>

          <button
            type="button"
            className="bg-pink-500 text-white py-2 px-4 rounded-full text-lg w-full mt-4"
            disabled={cart.cartItems === 0}
            onClick={placeOrderHandler}
          >
            Place Order
          </button>

          {isLoading && <Loader />}

          {/* ✅ Show OTP if available */}
          {otp && (
            <div className="otp-container text-center mt-4 p-4 bg-yellow-200 border border-yellow-500 rounded-lg">
              <h2 className="text-xl font-bold mb-2">Your OTP for Order Confirmation</h2>
              <p className="text-2xl font-bold text-blue-600">{otp}</p>
              <p className="text-sm text-gray-600">Please enter this OTP on the payment page to confirm your order.</p>
            </div>
          )}

        </div>
      </div>
    </>
  );
};

export default PlaceOrder;
