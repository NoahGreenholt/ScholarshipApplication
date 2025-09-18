const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying AnonymousScholarshipApplication contract...");

  // Get the contract factory
  const ScholarshipApplication = await ethers.getContractFactory("AnonymousScholarshipApplication");

  // Deploy the contract
  const contract = await ScholarshipApplication.deploy();

  // Wait for deployment to complete
  await contract.waitForDeployment();

  // Get the deployed contract address
  const contractAddress = await contract.getAddress();

  console.log("AnonymousScholarshipApplication deployed to:", contractAddress);
  console.log("Transaction hash:", contract.deploymentTransaction().hash);

  // Verify the deployment
  console.log("Verifying deployment...");
  const programCount = await contract.programCount();
  console.log("Initial program count:", programCount.toString());

  return contractAddress;
}

main()
  .then((address) => {
    console.log("Deployment completed successfully!");
    console.log("Contract address:", address);
    process.exit(0);
  })
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });