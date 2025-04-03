const { ethers } = require("hardhat");
const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

function askQuestion(query) {
  return new Promise(resolve => rl.question(query, resolve));
}

async function getProductDetails() {
  const name = await askQuestion('Enter product name: ');
  const description = await askQuestion('Enter product description: ');
  const quantity = await askQuestion('Enter product quantity: ');
  const priceInEth = await askQuestion('Enter product price in ETH: ');

  return {
    name,
    description,
    quantity,
    price: ethers.parseEther(priceInEth)
  };
}

function displayProductDetails(product) {
  console.log("\n--- Product Details ---");
  console.log(`ID: ${product.id}`);
  console.log(`Name: ${product.name}`);
  console.log(`Description: ${product.description}`);
  console.log(`Quantity: ${product.quantity}`);
  console.log(`Price: ${ethers.formatEther(product.price)} ETH`);
  console.log(`Producer: ${product.producer}`);
  console.log(`Status: ${['Active', 'Inactive', 'Recalled'][product.status]}`);
  console.log("--------------------");
}

async function viewProducts(productRegistration) {
  while (true) {
    console.log("\n--- Product Viewing Menu ---");
    console.log("1. View All Products");
    console.log("2. View Products by Producer");
    console.log("3. View Specific Product Details");
    console.log("4. Return to Main Menu");

    const choice = await askQuestion('Enter your choice (1-4): ');

    switch (choice) {
      case '1':
        // Fetch total number of products
        const productCount = await productRegistration.getProductCount();
        console.log(`\nTotal Products: ${productCount}`);
        
        // Fetch and display all products
        for (let i = 1; i <= productCount; i++) {
          try {
            const product = await productRegistration.getProduct(i);
            displayProductDetails(product);
          } catch (error) {
            console.log(`Error fetching product ${i}: ${error.message}`);
          }
        }
        break;

      case '2':
        const producerAddress = await askQuestion('Enter producer address: ');
        try {
          // Fetch products by producer (adjust pagination as needed)
          const productsByProducer = await productRegistration.getProductsByProducer(producerAddress, 0, 100);
          
          if (productsByProducer.length === 0) {
            console.log("No products found for this producer.");
          } else {
            console.log(`\nProducts by Producer ${producerAddress}:`);
            productsByProducer.forEach(displayProductDetails);
          }
        } catch (error) {
          console.log(`Error fetching products: ${error.message}`);
        }
        break;

      case '3':
        const productId = await askQuestion('Enter product ID: ');
        try {
          const product = await productRegistration.getProduct(productId);
          displayProductDetails(product);
        } catch (error) {
          console.log(`Error fetching product: ${error.message}`);
        }
        break;

      case '4':
        return;

      default:
        console.log("Invalid choice. Please try again.");
    }
  }
}

async function main() {
  // 1. Deploy the contract
  const ProductRegistration = await ethers.getContractFactory("ProductRegistration");
  const productRegistration = await ProductRegistration.deploy();
  await productRegistration.waitForDeployment();
  const contractAddress = await productRegistration.getAddress();
  console.log("ProductRegistration contract deployed to:", contractAddress);

  // Get signers (accounts)
  const [owner, producer1, producer2, otherUser] = await ethers.getSigners();

  // 2. Grant Producer Role
  const PRODUCER_ROLE = ethers.keccak256(ethers.toUtf8Bytes("PRODUCER_ROLE"));
  let tx = await productRegistration.grantRole(PRODUCER_ROLE, producer1.address);
  await tx.wait();
  console.log(`Granted PRODUCER_ROLE to ${producer1.address}`);

  while (true) {
    console.log("\n--- Product Registration System ---");
    console.log("1. Register Products");
    console.log("2. View Products");
    console.log("3. Change Product Status");
    console.log("4. Exit");

    const mainChoice = await askQuestion('Enter your choice (1-4): ');

    // Define productRegistrationAsProducer1 inside the scope where it's needed
    const productRegistrationAsProducer1 = productRegistration.connect(producer1);

    switch (mainChoice) {
      case '1':
        console.log("\nRegistering Products for Producer1:");
        const numberOfProducts = await askQuestion('How many products do you want to register? ');

        for (let i = 0; i < parseInt(numberOfProducts); i++) {
          console.log(`\nEnter details for Product ${i + 1}:`);
          const productDetails = await getProductDetails();

          tx = await productRegistrationAsProducer1.registerProduct(
            productDetails.name,
            productDetails.description,
            productDetails.quantity,
            productDetails.price
          );
          await tx.wait();
          console.log(`Registered Product ${i + 1}`);
        }
        break;

      case '2':
        await viewProducts(productRegistration);
        break;

      case '3':
        const productIdToChangeStatus = await askQuestion('Enter product ID to change status: ');
        const ProductStatus = {
          Active: 0,
          Inactive: 1,
          Recalled: 2
        };

        console.log("Product Statuses:");
        Object.entries(ProductStatus).forEach(([key, value]) => {
          console.log(`${value}: ${key}`);
        });

        const newStatus = await askQuestion('Enter new status number: ');

        tx = await productRegistrationAsProducer1.changeProductStatus(
          productIdToChangeStatus,
          parseInt(newStatus)
        );
        await tx.wait();
        console.log(`Changed status of Product ${productIdToChangeStatus}`);
        break;

      case '4':
        rl.close();
        process.exit(0);

      default:
        console.log("Invalid choice. Please try again.");
    }
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });