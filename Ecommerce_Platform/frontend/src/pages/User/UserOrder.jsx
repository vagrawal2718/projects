import { useState } from "react";
import Message from "../../components/Message";
import Loader from "../../components/Loader";
import { Link } from "react-router-dom";
import { useSelector } from "react-redux";
import { useGetMyOrdersQuery } from "../../redux/api/orderApiSlice";

const UserOrder = () => {
  const { data: orders, isLoading, error } = useGetMyOrdersQuery();
  const { userInfo } = useSelector((state) => state.auth);
  const [activeTab, setActiveTab] = useState("pending");

  if (isLoading) return <Loader />;
  if (error) return <Message variant="danger">{error?.data?.error || error.error}</Message>;

  // 🔹 Categorizing Orders
  const pendingOrders = orders.filter((order) => !JSON.parse(localStorage.getItem(`order_status_${order._id}`))?.isDelivered);
  const boughtOrders = orders.filter((order) => JSON.parse(localStorage.getItem(`order_status_${order._id}`))?.isDelivered && order.buyer === userInfo._id);
  const soldOrders = orders.filter((order) => order.seller === userInfo._id);

  // 🔹 Rendering Orders
  const renderOrders = (orderList) => (
    <table className="w-full">
      <thead>
        <tr>
          <td className="py-2">IMAGE</td>
          <td className="py-2">ID</td>
          <td className="py-2">DATE</td>
          <td className="py-2">TOTAL</td>
          <td className="py-2">PAID</td>
          <td className="py-2">DELIVERED</td>
          <td className="py-2"></td>
        </tr>
      </thead>
      <tbody>
        {orderList.map((order) => (
          <tr key={order._id}>
            <td>
              <img
                src={order.orderItems[0]?.image || "/default-image.jpg"}
                alt="Product"
                className="w-[6rem] mb-5"
              />
            </td>
            <td className="py-2">{order._id}</td>
            <td className="py-2">{new Date(order.createdAt).toLocaleDateString()}</td>
            <td className="py-2">$ {order.totalPrice.toFixed(2)}</td>

            {/* ✅ Check payment status */}
            <td className="py-2">
              {JSON.parse(localStorage.getItem(`order_status_${order._id}`))?.isPaid ? (
                <p className="p-1 text-center bg-green-500 text-white w-[6rem] rounded-full">Completed</p>
              ) : (
                <p className="p-1 text-center bg-yellow-500 text-white w-[6rem] rounded-full">Pending</p>
              )}
            </td>

            {/* ✅ Check delivery status */}
            <td className="px-2 py-2">
              {JSON.parse(localStorage.getItem(`order_status_${order._id}`))?.isDelivered ? (
                <p className="p-1 text-center bg-green-500 text-white w-[6rem] rounded-full">Completed</p>
              ) : (
                <p className="p-1 text-center bg-yellow-500 text-white w-[6rem] rounded-full">Pending</p>
              )}
            </td>

            <td className="px-2 py-2">
              <Link to={`/order/${order._id}`}>
                <button className="bg-pink-400 text-white py-2 px-3 rounded">View Details</button>
              </Link>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );

  return (
    <div className="container mx-auto">
      <h2 className="text-2xl font-semibold mb-4">My Orders</h2>

      {/* Tabs for Order Categories */}
      <div className="flex gap-4 mb-4">
        <button className={`px-4 py-2 rounded ${activeTab === "pending" ? "bg-blue-500 text-white" : "bg-gray-300"}`} onClick={() => setActiveTab("pending")}>
          Pending Orders
        </button>
        <button className={`px-4 py-2 rounded ${activeTab === "bought" ? "bg-blue-500 text-white" : "bg-gray-300"}`} onClick={() => setActiveTab("bought")}>
          Bought Items
        </button>
        <button className={`px-4 py-2 rounded ${activeTab === "sold" ? "bg-blue-500 text-white" : "bg-gray-300"}`} onClick={() => setActiveTab("sold")}>
          Sold Items
        </button>
      </div>

      {/* Display Relevant Orders Based on Selected Tab */}
      {activeTab === "pending" && renderOrders(pendingOrders)}
      {activeTab === "bought" && renderOrders(boughtOrders)}
      {activeTab === "sold" && renderOrders(soldOrders)}
    </div>
  );
};

export default UserOrder;
