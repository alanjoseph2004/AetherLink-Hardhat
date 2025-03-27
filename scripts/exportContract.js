// scripts/exportContract.js
const fs = require('fs');
const path = require('path');

async function main() {
  // Get the contract artifact
  const ProductRegistration = await ethers.getContractFactory("ProductRegistration");
  
  // Path to the frontend project
  const frontendDir = path.resolve(__dirname, '../../product-registration-frontend/contracts');
  
  // Ensure the directory exists
  if (!fs.existsSync(frontendDir)) {
    fs.mkdirSync(frontendDir, { recursive: true });
  }

  // Write contract address
  fs.writeFileSync(
    path.join(frontendDir, 'contract-address.json'),
    JSON.stringify({ address: process.env.DEPLOYED_CONTRACT_ADDRESS }, null, 2)
  );

  // Get the contract artifact
  const artifact = artifacts.readArtifact('ProductRegistration');
  
  // Write contract ABI
  fs.writeFileSync(
    path.join(frontendDir, 'ProductRegistration.json'),
    JSON.stringify(artifact, null, 2)
  );

  console.log("Exported contract details to frontend project!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });