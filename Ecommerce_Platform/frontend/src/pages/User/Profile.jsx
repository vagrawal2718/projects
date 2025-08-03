import { useEffect, useState } from "react";
import { useDispatch, useSelector } from "react-redux";
import { toast } from "react-toastify";
import Loader from "../../components/Loader";
import { setCredentials } from "../../redux/features/auth/authSlice";
import { Link } from "react-router-dom";
import { useProfileMutation } from "../../redux/api/usersApiSlice";

const Profile = () => {
  const [firstName, setFirstName] = useState('');
  const [lastName, setLastName] = useState('');
  const [username, setUserName] = useState('');
  const [email, setEmail] = useState('');
  const [age, setAge] = useState('');
  const [contactNumber, setContactNumber] = useState('');
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');

  const { userInfo } = useSelector((state) => state.auth);
  const [updateProfile, { isLoading: loadingUpdateProfile }] = useProfileMutation();
  const dispatch = useDispatch();

  //  Set user details from Redux state
  useEffect(() => {
    if (userInfo) {
      setFirstName(userInfo.firstName || '');
      setLastName(userInfo.lastName || '');
      setUserName(userInfo.username || '');
      setEmail(userInfo.email || '');
      setAge(userInfo.age || '');
      setContactNumber(userInfo.contactNumber || '');
    }
  }, [userInfo]);

  const submitHandler = async (e) => {
    e.preventDefault();

    if (password !== confirmPassword) {
      toast.error("Passwords do not match");
    } else {
      try {
        const res = await updateProfile({
          _id: userInfo._id,
          firstName,
          lastName,
          username,
          email,
          age,
          contactNumber,
          password
        }).unwrap();

        dispatch(setCredentials({ ...res }));
        toast.success("Profile successfully updated");

      } catch (err) {
        toast.error(err?.data?.message || err.message);
      }
    }
  };

  return (
    <div className="container mx-auto p-4 mt-[10rem]">
      <div className="flex justify-center align-center md:flex md:space-x-4">
        <div className="md:w-1/3">
          <h2 className="text-2xl font-semibold mb-4">Update Profile</h2>

          <form onSubmit={submitHandler}>
            {/* First Name */}
            <div className="mb-4">
              <label className="block text-black mb-2">First Name</label>
              <input
                type="text"
                placeholder="Enter First Name"
                className="form-input p-4 rounded-sm w-full"
                value={firstName}
                onChange={(e) => setFirstName(e.target.value)}
              />
            </div>

            {/* Last Name */}
            <div className="mb-4">
              <label className="block text-black mb-2">Last Name</label>
              <input
                type="text"
                placeholder="Enter Last Name"
                className="form-input p-4 rounded-sm w-full"
                value={lastName}
                onChange={(e) => setLastName(e.target.value)}
              />
            </div>

            {/* Username */}
            <div className="mb-4">
              <label className="block text-black mb-2">Username</label>
              <input
                type="text"
                placeholder="Enter Username"
                className="form-input p-4 rounded-sm w-full"
                value={username}
                onChange={(e) => setUserName(e.target.value)}
              />
            </div>

            {/* Email */}
            <div className="mb-4">
              <label className="block text-black mb-2">Email</label>
              <input
                type="email"
                placeholder="Enter Email"
                className="form-input p-4 rounded-sm w-full"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
              />
            </div>

            {/* Age */}
            <div className="mb-4">
              <label className="block text-black mb-2">Age</label>
              <input
                type="number"
                placeholder="Enter Age"
                className="form-input p-4 rounded-sm w-full"
                value={age}
                onChange={(e) => setAge(e.target.value)}
              />
            </div>

            {/* Contact Number */}
            <div className="mb-4">
              <label className="block text-black mb-2">Contact Number</label>
              <input
                type="text"
                placeholder="Enter Contact Number"
                className="form-input p-4 rounded-sm w-full"
                value={contactNumber}
                onChange={(e) => setContactNumber(e.target.value)}
              />
            </div>

            {/* Password */}
            <div className="mb-4">
              <label className="block text-black mb-2">New Password</label>
              <input
                type="password"
                placeholder="Enter New Password"
                className="form-input p-4 rounded-sm w-full"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
              />
            </div>

            {/* Confirm Password */}
            <div className="mb-4">
              <label className="block text-black mb-2">Confirm Password</label>
              <input
                type="password"
                placeholder="Confirm Password"
                className="form-input p-4 rounded-sm w-full"
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
              />
            </div>

            {/* Update Button */}
            <div className="flex justify-between">
              <button
                type="submit"
                className="bg-pink-500 text-black py-2 px-4 rounded hover:bg-pink-600"
              >
                Update
              </button>

              <Link
                to="/user-orders"
                className="bg-pink-600 text-black py-2 px-4 rounded hover:bg-pink-700"
              >
                My Orders
              </Link>

              <Link
                to="/admin/deliver-orders"
                className="bg-green-600 text-black py-2 px-4 rounded hover:bg-green-700 text-center"
              >
                Manage Deliveries
              </Link>
            </div>


            {loadingUpdateProfile && <Loader />}
          </form>

          {/* Seller Ratings Display */}
          {userInfo.sellerReviews?.length > 0 && (
            <div className="mt-6">
              <h2 className="text-xl font-semibold mb-4">Seller Rating</h2>
              <p className="text-lg font-medium">⭐ {userInfo.sellerReviews.reduce((sum, review) => sum + review.rating, 0) / userInfo.sellerReviews.length} / 5</p>
              <ul className="mt-2">
                {userInfo.sellerReviews.map((review, index) => (
                  <li key={index} className="border-b py-2">
                    <p><strong>Rating:</strong> ⭐ {review.rating}</p>
                    <p><strong>Comment:</strong> {review.comment}</p>
                  </li>
                ))}
              </ul>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default Profile;
