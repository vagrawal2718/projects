import { Link } from "react-router-dom";
import HeartIcon from "./HeartIcon";

const Product = ({ product }) => {
  return (
    <div className="w-[30rem] ml-[2rem] p-3 relative">
      <div className="relative">
        <img
          src={product.image}
          alt={product.name}
          className="w-[30rem] rounded"
        />
        <HeartIcon product={product} />
      </div>

      <div className="p-4">
        <Link to={`/product/${product._id}`}>
          <h2 className="flex justify-between items-center">
            <div className="text-lg">{product.name}</div>
            <span className="bg-pink-100 text-pink-800 text-sm font-medium mr-2 px-2.5 py-0.5 rounded-full dark:bg-pink-900 dark:text-pink-300">
              $ {product.price}
            </span>
          </h2>
        </Link>

        <p className="text-sm text-gray-500 mt-2">
          Sold by:{" "}
          <span className="font-semibold text-white">
            {product.seller?.username || "Unknown Seller"}
          </span>{" "}
          (<span className="text-pink-500">{product.seller?.email || "N/A"}</span>)
        </p>
        
      </div>
    </div>
  );
};

export default Product;