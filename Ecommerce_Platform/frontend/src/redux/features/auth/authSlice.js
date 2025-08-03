import {createSlice} from '@reduxjs/toolkit';

const initialState = {
  userInfo: localStorage.getItem('userInfo') ? JSON.parse(localStorage.getItem('userInfo')) : null,
};
const authSlice = createSlice({ 
  name: 'auth',
  initialState,
  reducers: {
    setCredentials: (state, action) => {
      console.log("Received User Info:", action.payload);
      state.userInfo = action.payload;
      localStorage.setItem('userInfo', JSON.stringify(action.payload));
      const expirationTime= new Date(new Date().getTime() + 90*24*60*60*1000); // 90 days
      localStorage.setItem('expirationTime', expirationTime);
    },
    logout: (state) => {
      state.userInfo = null;
      localStorage.clear();
    },
  },
});

export const {setCredentials, logout} = authSlice.actions;

export default authSlice.reducer;