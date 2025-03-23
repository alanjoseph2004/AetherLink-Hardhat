// This script demonstrates registering a product and retrieving product information
// using the ProductRegistration smart contract

// Import required libraries
const { ethers } = require("hardhat");

async function main() {
  console.log("Starting ProductRegistration script...");

  // Get signers
  const [admin, producer1, producer2] = await ethers.getSigners();
  console.log("Admin address:", admin.address);
  console.log("Producer1 address:", producer1.address);

  // Deploy the ProductRegistration contract
  console.log("\nDeploying ProductRegistration contract...");
  const ProductRegistration = await ethers.getContractFactory("ProductRegistration");
  const productRegistration = await ProductRegistration.deploy();
  console.log("ProductRegistration deployed to:", productRegistration.target);

  // Grant producer role to producer1
  console.log("\nGranting PRODUCER_ROLE to producer1...");
  const grantRoleTx = await productRegistration.grantProducerRole(producer1.address);
  await grantRoleTx.wait();
  console.log("PRODUCER_ROLE granted to producer1");

  // Register a product as producer1
  console.log("\nRegistering a product as producer1...");
  const productData = {
    name: "Organic Apple",
    details: "Fresh organic apples from local farms",
    quantity: "10 kg",
    price: ethers.parseEther("0.05") // 0.05 ETH
  };

  const registerTx = await productRegistration.connect(producer1).registerProduct(
    productData.name,
    productData.details,
    productData.quantity,
    productData.price
  );
  
  const receipt = await registerTx.wait();
  
  // Parse event logs to get the productId
  const productRegisterEvent = receipt.logs.find(log => {
    try {
      return productRegistration.interface.parseLog(log).name === "ProductRegistered";
    } catch (e) {
      return false;
    }
  });
  
  const parsedEvent = productRegistration.interface.parseLog(productRegisterEvent);
  const productId = parsedEvent.args.productId;
  console.log(`Product registered with ID: ${productId}`);

  // Retrieve product information
  console.log("\nRetrieving product information...");
  const product = await productRegistration.getProduct(productId);
  
  console.log("Product details:");
  console.log("- ID:", product.productId.toString());
  console.log("- Producer:", product.producer);
  console.log("- Name:", product.name);
  console.log("- Details:", product.details);
  console.log("- Quantity:", product.quantity);
  console.log("- Price:", ethers.formatEther(product.price), "ETH");
  console.log("- Status:", ["Active", "Inactive", "Recalled"][product.status]);
  console.log("- Timestamp:", new Date(Number(product.timestamp) * 1000).toLocaleString());
  console.log("- Last Updated:", new Date(Number(product.lastUpdated) * 1000).toLocaleString());

  // Update product details
  console.log("\nUpdating product...");
  const updateTx = await productRegistration.connect(producer1).updateProduct(
    productId,
    "15 kg", // updated quantity
    ethers.parseEther("0.04"), // updated price
    "Premium organic apples from certified farms" // updated details
  );
  await updateTx.wait();
  console.log("Product updated");

  // Retrieve updated product information
  console.log("\nRetrieving updated product information...");
  const updatedProduct = await productRegistration.getProduct(productId);
  
  console.log("Updated product details:");
  console.log("- Quantity:", updatedProduct.quantity);
  console.log("- Price:", ethers.formatEther(updatedProduct.price), "ETH");
  console.log("- Details:", updatedProduct.details);
  console.log("- Last Updated:", new Date(Number(updatedProduct.lastUpdated) * 1000).toLocaleString());

  console.log("\nScript execution completed successfully!");
}

// Execute the script
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("Error during script execution:", error);
    process.exit(1);
  });