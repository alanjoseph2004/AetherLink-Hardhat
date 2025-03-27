const { ethers } = require("hardhat");

async function main() {
  // 1. Deploy the contract
  const ProductRegistration = await ethers.getContractFactory("ProductRegistration");
  const productRegistration = await ProductRegistration.deploy();
  await productRegistration.waitForDeployment();

  const contractAddress = await productRegistration.getAddress(); // Get the contract address
  console.log("ProductRegistration contract deployed to:", contractAddress);

  // Get signers (accounts)
  const [owner, producer1, producer2, otherUser] = await ethers.getSigners();

  // 2. Grant Producer Role (if needed)
  // The owner (deployer) automatically has the DEFAULT_ADMIN_ROLE and PRODUCER_ROLE.
  // Let's grant the PRODUCER_ROLE to producer1.
  const PRODUCER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("PRODUCER_ROLE")); // Get the role

  let tx = await productRegistration.grantRole(PRODUCER_ROLE, producer1.address);
  await tx.wait();
  console.log(`Granted PRODUCER_ROLE to ${producer1.address}`);


  // 3. Register Products

  // Connect to the contract using the producer1 signer
  const productRegistrationAsProducer1 = productRegistration.connect(producer1);


  tx = await productRegistrationAsProducer1.registerProduct(
    "Awesome Widget",
    "A really cool widget that does amazing things",
    "100 units",
    ethers.parseEther("1.5") // Price in ETH (wei)
  );
  await tx.wait();
  console.log("Registered Product 1");


  tx = await productRegistrationAsProducer1.registerProduct(
    "Deluxe Gadget",
    "The best gadget you'll ever own!",
    "50 units",
    ethers.parseEther("5")
  );
  await tx.wait();
  console.log("Registered Product 2");


  // Register a product as the owner (who also has PRODUCER_ROLE)
  tx = await productRegistration.registerProduct(
        "Admin Product",
        "A product owned by the admin",
        "200 units",
        ethers.parseEther("2")
    );
    await tx.wait();
    console.log("Registered Product 3 (by Owner/Admin)");


  // 4. Update a Product (as Producer1)
  const productIdToUpdate = 1; // Let's update the first product

  tx = await productRegistrationAsProducer1.updateProduct(
    productIdToUpdate,
    "120 units",
    ethers.parseEther("1.75"),
    "Even more amazing details!"
  );
  await tx.wait();
  console.log(`Updated Product ${productIdToUpdate}`);


  // 5. Change Product Status (as Producer1)
  const productIdToChangeStatus = 2;

  // Enum ProductStatus { Active, Inactive, Recalled }
  const ProductStatus = {
    Active: 0,
    Inactive: 1,
    Recalled: 2,
  };

  tx = await productRegistrationAsProducer1.changeProductStatus(
    productIdToChangeStatus,
    ProductStatus.Recalled
  );
  await tx.wait();
  console.log(`Changed status of Product ${productIdToChangeStatus} to Recalled`);

  // 6. Get Product Details
  const productDetails = await productRegistration.getProduct(1); // get Product 1
  console.log("Product 1 Details:", productDetails);

  // 7. Get products by producer
  const productsByProducer1 = await productRegistration.getProductsByProducer(producer1.address, 0, 10); // get all products of producer1
  console.log("Products by producer1:", productsByProducer1);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });