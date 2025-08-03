import { useEffect, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { PayPalButtons, usePayPalScriptReducer } from "@paypal/react-paypal-js";
import { useSelector } from "react-redux";
import { toast } from "react-toastify";
import Message from "../../components/Message";
import Loader from "../../components/Loader";
import {
  useDeliverOrderMutation,
  useGetOrderDetailsQuery,
  useGetPaypalClientIdQuery,
  usePayOrderMutation,
} from "../../redux/api/orderApiSlice";

const Order = () => {
  const { id: orderId } = useParams();
  const [otp, setOtp] = useState(""); // 🔹 OTP state
  const [isOtpVerified, setIsOtpVerified] = useState(false); // 🔹 OTP verification state

  const {
    data: order,
    refetch,
    isLoading,
    error,
  } = useGetOrderDetailsQuery(orderId);

  const [payOrder, { isLoading: loadingPay }] = usePayOrderMutation();
  const [deliverOrder, { isLoading: loadingDeliver }] = useDeliverOrderMutation();

  const { userInfo } = useSelector((state) => state.auth);
  const [{ isPending }, paypalDispatch] = usePayPalScriptReducer();

  const {
    data: paypal,
    isLoading: loadingPayPal,
    error: errorPayPal,
  } = useGetPaypalClientIdQuery();

  useEffect(() => {
    if (!errorPayPal && !loadingPayPal && paypal.clientId) {
      const loadPayPalScript = async () => {
        paypalDispatch({
          type: "resetOptions",
          value: {
            "client-id": paypal.clientId,
            currency: "USD",
          },
        });
        paypalDispatch({ type: "setLoadingStatus", value: "pending" });
      };

      if (order && !order.isPaid) {
        if (!window.paypal) {
          loadPayPalScript();
        }
      }
    }
  }, [errorPayPal, loadingPayPal, order, paypal, paypalDispatch]);

  useEffect(() => {
    const storedOtpValue = localStorage.getItem(`order_otp_${orderId}`);
    if (storedOtpValue) {
      console.log("🔹 OTP retrieved from Local Storage:", storedOtpValue);
      setOtp(storedOtpValue); // ✅ Store OTP in state for display
    }
  }, [orderId]);

  const verifyOtpHandler = () => {
    const storedOtp = localStorage.getItem(`order_otp_${orderId}`);
    console.log("🔹 Retrieving OTP from Local Storage:", storedOtp);
  
    if (!storedOtp || otp !== storedOtp) {
      toast.error("Invalid OTP. Try again.");
      return;
    }
  
    console.log("✅ OTP Matched! Marking order as verified.");
    setIsOtpVerified(true);
    toast.success("OTP Verified! Order is now marked as Completed.");
  
    // ✅ Simulate marking order as Paid & Delivered in localStorage
    localStorage.setItem(`order_status_${orderId}`, JSON.stringify({ isPaid: true, isDelivered: true }));
  
    // ✅ Remove OTP after successful verification
    localStorage.removeItem(`order_otp_${orderId}`);
  };
  


  const onApprove = (data, actions) => {
    return actions.order.capture().then(async function (details) {
      try {
        await payOrder({ orderId, details });
        refetch();
        toast.success("Order is paid");
      } catch (error) {
        toast.error(error?.data?.message || error.message);
      }
    });
  };

  const createOrder = (data, actions) => {
    return actions.order
      .create({
        purchase_units: [{ amount: { value: order.totalPrice } }],
      })
      .then((orderID) => {
        return orderID;
      });
  };

  const onError = (err) => {
    toast.error(err.message);
  };

  const deliverHandler = async () => {
    await deliverOrder(orderId);
    refetch();
  };

  return isLoading ? (
    <Loader />
  ) : error ? (
    <Message variant="danger">{error.data.message}</Message>
  ) : (
    <div className="container flex flex-col ml-[10rem] md:flex-row">
      <div className="md:w-2/3 pr-4">
        <div className="border gray-300 mt-5 pb-4 mb-5">
          {order.orderItems.length === 0 ? (
            <Message>Order is empty</Message>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-[80%]">
                <thead className="border-b-2">
                  <tr>
                    <th className="p-2">Image</th>
                    <th className="p-2">Product</th>
                    <th className="p-2 text-center">Quantity</th>
                    <th className="p-2">Unit Price</th>
                    <th className="p-2">Total</th>
                  </tr>
                </thead>

                <tbody>
                  {order.orderItems.map((item, index) => (
                    <tr key={index}>
                      <td className="p-2">
                        <img
                          src={item.image}
                          alt={item.name}
                          className="w-16 h-16 object-cover"
                        />
                      </td>

                      <td className="p-2">
                        <Link to={`/product/${item.product}`}>{item.name}</Link>
                      </td>

                      <td className="p-2 text-center">{item.qty}</td>
                      <td className="p-2 text-center">{item.price}</td>
                      <td className="p-2 text-center">
                        $ {(item.qty * item.price).toFixed(2)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>

      <div className="md:w-1/3">
        <div className="mt-5 border-gray-300 pb-4 mb-4">
          <h2 className="text-xl font-bold mb-2">Shipping</h2>
          <p className="mb-4 mt-4">
            <strong className="text-pink-500">Order:</strong> {order._id}
          </p>
          <p className="mb-4">
            <strong className="text-pink-500">Name:</strong>
            {order.buyer ? order.buyer.username : "N/A"}
          </p>
          <p className="mb-4">
            <strong className="text-pink-500">Email:</strong>
            {order.buyer ? order.buyer.email : "N/A"}
          </p>
          <p className="mb-4">
            <strong className="text-pink-500">Address:</strong> {order.shippingAddress.address},{" "}
            {order.shippingAddress.city} {order.shippingAddress.postalCode},{" "}
            {order.shippingAddress.country}
          </p>
          <p className="mb-4">
            <strong className="text-pink-500">Method:</strong> {order.paymentMethod}
          </p>
          {order.isPaid ? (
            <Message variant="success">Paid on {order.paidAt}</Message>
          ) : (
            <Message variant="danger"></Message>
          )}
        </div>

        <h2 className="text-xl font-bold mb-2 mt-[3rem]"></h2>


        {/* 🔹 Show OTP if retrieved from Local Storage */}
        {otp && !isOtpVerified && (
          <div className="otp-container text-center mt-4 p-4 bg-yellow-200 border border-yellow-500 rounded-lg">
            <h2 className="text-xl font-bold mb-2">Your OTP for Order Confirmation</h2>
            <p className="text-2xl font-bold text-blue-600">{otp}</p>
            <p className="text-sm text-gray-600">Please enter this OTP to verify your order.</p>
          </div>
        )}

        {/* 🔹 OTP Verification Section */}
        {!isOtpVerified && !order.isPaid && (
          <div className="mb-4">
            <input
              type="text"
              placeholder="Enter OTP"
              value={otp}
              onChange={(e) => setOtp(e.target.value)}
              className="w-full px-3 py-2 border rounded-lg focus:outline-none focus:ring focus:border-pink-300"
            />
            <button
              onClick={verifyOtpHandler}
              className="bg-blue-500 text-white py-2 px-4 rounded mt-2 w-full"
            >
              Verify OTP
            </button>
          </div>
        )}

        {/* {!order.isPaid && isOtpVerified && (
          <PayPalButtons createOrder={createOrder} onApprove={onApprove} onError={onError} />
        )}

        {loadingDeliver && <Loader />}
        {userInfo && userInfo.isAdmin && order.isPaid && !order.isDelivered && (
          <button className="bg-pink-500 text-white w-full py-2" onClick={deliverHandler}>
            Mark As Delivered
          </button>
        )} */}
      </div>
    </div>
  );
};

export default Order;
