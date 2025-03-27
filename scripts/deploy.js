const hre = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  // Get the contract factory
  const ProductRegistration = await hre.ethers.getContractFactory("ProductRegistration");
  
  // Deploy the contract
  const productRegistration = await ProductRegistration.deploy();
  
  // Wait for the contract to be deployed
  await productRegistration.waitForDeployment();
  
  // Get the deployed contract address
  const address = await productRegistration.getAddress();
  
  console.log("ProductRegistration contract deployed to:", address);
  
  // Optionally, write the address to a file
  const contractsDir = path.join(__dirname, "..", "frontend", "contracts");
  
  // Ensure the directory exists
  if (!fs.existsSync(contractsDir)) {
    fs.mkdirSync(contractsDir, { recursive: true });
  }
  
  // Write contract address
  fs.writeFileSync(
    path.join(contractsDir, "contract-address.json"),
    JSON.stringify({ address: address }, null, 2)
  );
}

// Recommended pattern for catching and logging errors
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });