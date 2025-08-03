import { useState } from "react";
import { useGetSellerOrdersQuery, useMarkOrderDeliveredMutation } from "../../redux/api/orderApiSlice";
import Message from "../../components/Message";
import Loader from "../../components/Loader";
import { toast } from "react-toastify";

const DeliverOrders = () => {
  const { data: orders, isLoading, error, refetch } = useGetSellerOrdersQuery();
  const [markOrderDelivered] = useMarkOrderDeliveredMutation();
  const [otpInput, setOtpInput] = useState("");

  const handleDeliver = async (orderId, storedOtp) => {
    if (otpInput !== storedOtp) {
      toast.error("Invalid OTP. Please try again.");
      return;
    }

    // ✅ Mark order as delivered in local storage
    localStorage.setItem(`order_status_${orderId}`, JSON.stringify({ isPaid: true, isDelivered: true }));

    toast.success("Order marked as delivered!");
    refetch(); // Refresh the list
  };

  if (isLoading) return <Loader />;
  if (error) return <Message variant="danger">{error?.data?.message || "Error loading orders"} </Message>;

  return (
    <div className="container mx-auto">
      <h2 className="text-2xl font-semibold mb-4">Orders to Deliver</h2>

      {orders.map((order) => (
        <div key={order._id} className="border p-4 mb-4">
          <p><strong>Order ID:</strong> {order._id}</p>
          <p><strong>Buyer:</strong> {order.buyer.username}</p>
          <p><strong>Item:</strong> {order.orderItems[0].name}</p>
          <p><strong>Price:</strong> ${order.totalPrice.toFixed(2)}</p>

          <input type="text" placeholder="Enter OTP" value={otpInput} onChange={(e) => setOtpInput(e.target.value)} className="border p-2" />
          <button className="bg-green-500 text-white px-4 py-2 rounded mt-2" onClick={() => handleDeliver(order._id, localStorage.getItem(`order_otp_${order._id}`))}>
            Mark as Delivered
          </button>
        </div>
      ))}
    </div>
  );
};

export default DeliverOrders;
 