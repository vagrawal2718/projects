import { useState, useEffect } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { useDispatch, useSelector } from "react-redux";
import Loader from "../../components/Loader";
import { setCredentials } from "../../redux/features/auth/authSlice";
import { toast } from "react-toastify";
import { useRegisterMutation } from "../../redux/api/usersApiSlice";

const Register = () => {
  const [firstName, setFirstName] = useState("");
  const [lastName, setLastName] = useState("");
  const [username, setUserName] = useState("");
  const [email, setEmail] = useState("");
  const [age, setAge] = useState("");
  const [contactNumber, setContactNumber] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");

  const dispatch = useDispatch();
  const navigate = useNavigate();

  const [register, { isLoading }] = useRegisterMutation();
  const { userInfo } = useSelector((state) => state.auth);

  const { search } = useLocation();
  const sp = new URLSearchParams(search);
  const redirect = sp.get("redirect") || "/";

  useEffect(() => {
    if (userInfo) {
      navigate(redirect);
    }
  }, [navigate, redirect, userInfo]);

  const submitHandler = async (e) => {
    e.preventDefault();
  
    const iiitEmailRegex = /^[a-zA-Z0-9._%+-]+@iiit.ac.in$/;
    if (!iiitEmailRegex.test(email)) {
      toast.error("Only IIIT emails are allowed!"); // ✅ Show error before sending request
      return; // Stop the form from submitting
    }
  
    if (password !== confirmPassword) {
      toast.error("Passwords do not match");
      return;
    }
  
    try {
      const res = await register({
        firstName,
        lastName,
        username,
        email,
        password,
        age,
        contactNumber,
      }).unwrap();
  
      dispatch(setCredentials({ ...res }));
      navigate(redirect);
      toast.success("User successfully registered");
  
    } catch (err) {
      toast.error(err?.data?.message || err.message);
    }
  };
  

  return (
    <section className="pl-[10rem] flex flex-wrap">
      <div className="mr-[4rem] mt-[5rem]">
        <h1 className="text-2xl font-semibold mb-4">Register</h1>

        <form onSubmit={submitHandler} className="container w-[40rem]">
          {/* First Name */}
          <div className="my-[2rem]">
            <label htmlFor="firstName" className="block text-sm font-medium text-black">
              First Name
            </label>
            <input
              type="text"
              id="firstName"
              className="mt-1 p-2 border rounded w-full"
              placeholder="Enter First Name"
              value={firstName}
              onChange={(e) => setFirstName(e.target.value)}
            />
          </div>

          {/* Last Name */}
          <div className="my-[2rem]">
            <label htmlFor="lastName" className="block text-sm font-medium text-black">
              Last Name
            </label>
            <input
              type="text"
              id="lastName"
              className="mt-1 p-2 border rounded w-full"
              placeholder="Enter Last Name"
              value={lastName}
              onChange={(e) => setLastName(e.target.value)}
            />
          </div>

          {/* Username */}
          <div className="my-[2rem]">
            <label htmlFor="username" className="block text-sm font-medium text-black">
              Username
            </label>
            <input
              type="text"
              id="username"
              className="mt-1 p-2 border rounded w-full"
              placeholder="Enter Username"
              value={username}
              onChange={(e) => setUserName(e.target.value)}
            />
          </div>

          {/* Email */}
          <div className="my-[2rem]">
            <label htmlFor="email" className="block text-sm font-medium text-black">
              Email Address
            </label>
            <input
              type="email"
              id="email"
              className="mt-1 p-2 border rounded w-full"
              placeholder="Enter Email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </div>

          {/* Age */}
          <div className="my-[2rem]">
            <label htmlFor="age" className="block text-sm font-medium text-black">
              Age
            </label>
            <input
              type="number"
              id="age"
              className="mt-1 p-2 border rounded w-full"
              placeholder="Enter Age"
              value={age}
              onChange={(e) => setAge(e.target.value)}
            />
          </div>

          {/* Contact Number */}
          <div className="my-[2rem]">
            <label htmlFor="contactNumber" className="block text-sm font-medium text-black">
              Contact Number
            </label>
            <input
              type="text"
              id="contactNumber"
              className="mt-1 p-2 border rounded w-full"
              placeholder="Enter Contact Number"
              value={contactNumber}
              onChange={(e) => setContactNumber(e.target.value)}
            />
          </div>

          {/* Password */}
          <div className="my-[2rem]">
            <label htmlFor="password" className="block text-sm font-medium text-black">
              Password
            </label>
            <input
              type="password"
              id="password"
              className="mt-1 p-2 border rounded w-full"
              placeholder="Enter Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </div>

          {/* Confirm Password */}
          <div className="my-[2rem]">
            <label htmlFor="confirmPassword" className="block text-sm font-medium text-black">
              Confirm Password
            </label>
            <input
              type="password"
              id="confirmPassword"
              className="mt-1 p-2 border rounded w-full"
              placeholder="Confirm Password"
              value={confirmPassword}
              onChange={(e) => setConfirmPassword(e.target.value)}
            />
          </div>

          {/* Register Button */}
          <button
            disabled={isLoading}
            type="submit"
            className="bg-pink-500 text-white px-4 py-2 rounded cursor-pointer my-[1rem]"
          >
            {isLoading ? "Registering..." : "Register"}
          </button>
          {isLoading && <Loader />}
        </form>

        <div className="mt-4">
          <p className="text-black">
            Already have an account?{" "}
            <Link to={redirect ? `/login?redirect=${redirect}` : "/login"} className="text-pink-500 hover:underline">
              Login
            </Link>
          </p>
        </div>
      </div>

      <img
        src="https://images.unsplash.com/photo-1576502200916-3808e07386a5?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=2065&q=80"
        alt=""
        className="h-[65rem] w-[59%] xl:block md:hidden sm:hidden rounded-lg"
      />
    </section>
  );
};

export default Register;
