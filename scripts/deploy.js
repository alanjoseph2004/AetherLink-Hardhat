async function main() {
  const unlockTime = Math.floor(Date.now() / 1000) + 60; // Current time + 60 seconds

  // Deploy the Lock contract
  const Lock = await ethers.getContractFactory("Lock");
  const lock = await Lock.deploy(unlockTime);
  console.log("Lock deployed to:", await lock.getAddress());

  // Deploy the ProductRegistration contract
  const ProductRegistration = await ethers.getContractFactory("ProductRegistration");
  const productRegistration = await ProductRegistration.deploy();
  console.log("ProductRegistration contract deployed to:", await productRegistration.getAddress());

  // Deploy the Bidding contract
  const Bidding = await ethers.getContractFactory("Bidding");
  const bidding = await Bidding.deploy();
  console.log("Bidding contract deployed to:", await bidding.getAddress());
}

// Execute the main function
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
