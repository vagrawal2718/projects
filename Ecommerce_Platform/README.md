# MERN E-Commerce Platform

A full-stack e-commerce application built with the MERN stack (MongoDB, Express.js, React, Node.js). This project includes functionality for users to buy and sell products.

## Features

- **Shopping Cart**: Add products, adjust quantities, and proceed to checkout.
- **User Authentication**: Secure user registration and login using JSON Web Tokens (JWT) and password hashing (bcrypt).
- **Product Management**: Users can perform full CRUD (Create, Read, Update, Delete) operations on products, categories, and brands. 
- **Product Reviews & Ratings**: Users can leave reviews and ratings on products.
- **Search & Filtering**: Users can search for products and filter them by category, brand, and price.

## Tech Stack

| Category | Technology |
|----------|------------|
| Frontend | React, Redux Toolkit (RTK Query), Tailwind CSS, Vite |
| Backend | Node.js, Express.js, RESTful API |
| Database | MongoDB with Mongoose (ODM) |
| Authentication | JSON Web Tokens (JWT), bcrypt.js |

## Getting Started

### Prerequisites

- **Node.js**: Must have Node.js version 18.x or 20.x (or higher) installed. The project will not run on older versions like Node 12.
- **MongoDB**: Make sure you have MongoDB installed and the server is running on its default port.

### Installation & Setup

#### Install Backend Dependencies
From the project's root directory, run:

```bash
npm install
```

(This installs Express, Mongoose, nodemon, concurrently, etc.)

#### Install Frontend Dependencies
Navigate into the frontend directory and install its dependencies:

```bash
cd frontend
npm install
cd ..
```

(This installs React, Vite, Tailwind, etc.)

### Running the Application

Once the setup is complete, you can run both the frontend and backend servers with a single command from the root directory.

```bash
npm run dev
```

This command uses concurrently to:

- Start the backend server with nodemon on http://localhost:5000.
- Start the frontend Vite development server, typically on http://localhost:5173.

You can now open http://localhost:5173 in your browser to use the application.