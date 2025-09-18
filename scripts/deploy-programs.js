const { ethers } = require("hardhat");

async function main() {
  console.log("Deploying all preset programs to blockchain...");

  // Get the contract factory
  const ScholarshipApplication = await ethers.getContractFactory("AnonymousScholarshipApplication");

  // Connect to existing deployed contract
  const contractAddress = "0x9FC9675877f6d6ea2cD9CCC3a37F81DA641765FE";
  const contract = ScholarshipApplication.attach(contractAddress);

  console.log("Connected to contract at:", contractAddress);

  // Check current program count
  const initialCount = await contract.programCount();
  console.log("Initial program count:", initialCount.toString());

  // Define all preset programs
  const presetPrograms = [
    {
      name: "Global Tech Innovation Scholarship",
      description: "Supporting students in Computer Science, AI, and Blockchain technology. Awards $5,000 to outstanding candidates with demonstrated technical skills and innovative project portfolios.",
      maxApplications: 25
    },
    {
      name: "Sustainable Future Engineering Grant", 
      description: "For engineering students focused on renewable energy, environmental solutions, and sustainable development. $3,500 award for students committed to solving climate challenges.",
      maxApplications: 20
    },
    {
      name: "Digital Arts & Design Excellence Award",
      description: "Supporting creative students in digital media, graphic design, and user experience. $2,800 scholarship for innovative digital artists and designers.",
      maxApplications: 15
    },
    {
      name: "Healthcare Heroes Scholarship",
      description: "For pre-med, nursing, and healthcare students dedicated to improving global health outcomes. $4,200 award for future healthcare professionals.",
      maxApplications: 30
    },
    {
      name: "Entrepreneurship & Business Leadership Fund",
      description: "Supporting student entrepreneurs and future business leaders with innovative startup ideas. $3,000 grant for students with viable business concepts.",
      maxApplications: 18
    },
    {
      name: "Underrepresented Communities STEM Grant",
      description: "Promoting diversity in STEM fields by supporting students from underrepresented backgrounds. $4,500 scholarship for qualified candidates.",
      maxApplications: 22
    }
  ];

  console.log(`Deploying ${presetPrograms.length} programs...`);

  // Deploy each program
  for (let i = 0; i < presetPrograms.length; i++) {
    const program = presetPrograms[i];
    
    console.log(`\nDeploying program ${i + 1}: ${program.name}`);
    
    try {
      // Create program on blockchain
      const tx = await contract.createProgram(
        program.name,
        program.description,
        program.maxApplications
      );
      
      console.log(`Transaction sent: ${tx.hash}`);
      
      // Wait for confirmation
      const receipt = await tx.wait();
      console.log(`Program ${i + 1} confirmed in block: ${receipt.blockNumber}`);
      
      // Get the new program count to verify
      const newCount = await contract.programCount();
      console.log(`Program created with ID: ${newCount.toString()}`);
      
    } catch (error) {
      console.error(`Failed to deploy program ${i + 1}:`, error.message);
    }
  }

  // Final verification
  const finalCount = await contract.programCount();
  console.log(`\nDeployment complete!`);
  console.log(`Programs deployed: ${finalCount - initialCount}`);
  console.log(`Total programs on chain: ${finalCount.toString()}`);

  // List all programs
  console.log("\nVerifying deployed programs:");
  for (let i = 1; i <= finalCount; i++) {
    try {
      const programInfo = await contract.getProgramInfo(i);
      console.log(`Program ${i}: ${programInfo.name}`);
      console.log(`  - Max Applications: ${programInfo.maxApplications}`);
      console.log(`  - Current Applications: ${programInfo.currentApplications}`);
      console.log(`  - Active: ${programInfo.isActive}`);
    } catch (error) {
      console.log(`Program ${i}: Error retrieving info`);
    }
  }
}

main()
  .then(() => {
    console.log("All programs deployed successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("Deployment failed:", error);
    process.exit(1);
  });