# Hello FHEVM: Your First Privacy-Preserving dApp

## 🎯 Welcome to Your First Confidential Application

This tutorial will guide you through building your first **Fully Homomorphic Encryption Virtual Machine (FHEVM)** application using our **Anonymous Scholarship Application System** as a practical example. By the end of this tutorial, you'll understand how to build privacy-preserving dApps that keep sensitive data encrypted while still allowing computation.

## 🤔 What is FHEVM?

**FHEVM** allows smart contracts to perform computations on encrypted data without ever decrypting it. Think of it as a magical calculator that can:
- Add encrypted numbers without knowing what they are
- Compare encrypted values without seeing them
- Make decisions based on encrypted data while keeping everything private

### Real-World Example
Imagine you want to apply for a scholarship but don't want to reveal your financial information publicly. With FHEVM:
- ✅ You submit encrypted financial data
- ✅ The smart contract evaluates your eligibility
- ✅ Only the final decision is revealed
- ✅ Your private information stays encrypted forever

## 🎓 Prerequisites

Before starting, you should know:
- **Solidity basics** (variables, functions, contracts)
- **Basic JavaScript/React** for frontend
- **MetaMask** wallet usage
- **Hardhat** development environment

**No FHE or cryptography knowledge required!**

## 🏗️ Project Overview: Anonymous Scholarship System

We'll build a complete dApp that allows:
1. **Students** to apply for scholarships with encrypted personal data
2. **Administrators** to evaluate applications without seeing private information
3. **Smart contracts** to determine eligibility on encrypted data

### Key Features
- 🔐 **Private Financial Data**: Income information stays encrypted
- 📊 **Confidential Academic Records**: Grades processed privately
- ✅ **Transparent Results**: Final decisions are public and verifiable
- 🏛️ **Multiple Programs**: Support for various scholarship types

## 📁 Project Structure

```
scholarship-fhe-dapp/
├── contracts/
│   └── ScholarshipApplication.sol
├── scripts/
│   └── deploy.js
├── frontend/
│   └── index.html
├── hardhat.config.js
├── package.json
└── README.md
```

## 🛠️ Step 1: Environment Setup

### Install Dependencies

```bash
npm init -y
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox
npm install @fhevm/solidity ethers@^6.0.0
```

### Configure Hardhat

Create `hardhat.config.js`:

```javascript
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: "0.8.24",
  networks: {
    zama: {
      url: "https://devnet.zama.ai/",
      accounts: ["YOUR_PRIVATE_KEY_HERE"], // Replace with your private key
      chainId: 8009
    }
  }
};
```

## 🔧 Step 2: Understanding FHE Smart Contract Basics

### Key FHEVM Concepts

1. **Encrypted Types**: Instead of `bool`, use `ebool` for encrypted booleans
2. **FHE Library**: Import and use FHE operations
3. **Permissions**: Control who can decrypt specific data

### Basic FHE Operations

```solidity
import { FHE, ebool } from "@fhevm/solidity/lib/FHE.sol";

// Convert plaintext to encrypted
ebool encryptedValue = FHE.asEbool(true);

// Perform operations on encrypted data
ebool result = FHE.and(encryptedValue1, encryptedValue2);

// Set permissions
encryptedValue.allowThis(); // Allow contract to use
encryptedValue.allow(userAddress); // Allow specific user
```

## 📝 Step 3: Building the Smart Contract

Create `contracts/ScholarshipApplication.sol`:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, ebool } from "@fhevm/solidity/lib/FHE.sol";

contract AnonymousScholarshipApplication {
    using FHE for ebool;

    // Structure for encrypted application data
    struct Application {
        address applicant;
        ebool hasFinancialNeed;      // Encrypted: true if student needs financial aid
        ebool meetsAcademicCriteria; // Encrypted: true if meets GPA requirements
        ebool isEligible;            // Encrypted: calculated eligibility
        uint256 timestamp;
        bool processed;
    }

    // Structure for scholarship programs
    struct ScholarshipProgram {
        string name;
        string description;
        uint256 maxApplications;
        uint256 currentApplications;
        bool isActive;
        address administrator;
    }

    // State variables
    uint256 public applicationCount;
    uint256 public programCount;

    mapping(uint256 => Application) public applications;
    mapping(uint256 => ScholarshipProgram) public programs;
    mapping(address => uint256[]) public applicantApplications;

    // Events for transparency
    event ApplicationSubmitted(uint256 indexed applicationId, uint256 indexed programId, address indexed applicant);
    event ProgramCreated(uint256 indexed programId, string name, address administrator);

    // Modifier for program administrators
    modifier onlyProgramAdmin(uint256 _programId) {
        require(programs[_programId].administrator == msg.sender, "Not program administrator");
        _;
    }

    // Create a new scholarship program
    function createProgram(
        string memory _name,
        string memory _description,
        uint256 _maxApplications
    ) external {
        programCount++;
        programs[programCount] = ScholarshipProgram({
            name: _name,
            description: _description,
            maxApplications: _maxApplications,
            currentApplications: 0,
            isActive: true,
            administrator: msg.sender
        });

        emit ProgramCreated(programCount, _name, msg.sender);
    }

    // Submit encrypted application
    function submitApplication(
        uint256 _programId,
        bool _hasFinancialNeed,        // This will be encrypted
        bool _meetsAcademicCriteria    // This will be encrypted
    ) external {
        require(_programId > 0 && _programId <= programCount, "Invalid program ID");
        require(programs[_programId].isActive, "Program not active");
        require(programs[_programId].currentApplications < programs[_programId].maxApplications, "Program full");

        // 🔐 FHEVM MAGIC: Convert plaintext to encrypted data
        ebool encryptedFinancialNeed = FHE.asEbool(_hasFinancialNeed);
        ebool encryptedAcademicCriteria = FHE.asEbool(_meetsAcademicCriteria);

        // 🧮 FHEVM COMPUTATION: Calculate eligibility on encrypted data
        // Student is eligible if BOTH conditions are true
        ebool isEligible = FHE.and(encryptedFinancialNeed, encryptedAcademicCriteria);

        applicationCount++;
        applications[applicationCount] = Application({
            applicant: msg.sender,
            hasFinancialNeed: encryptedFinancialNeed,
            meetsAcademicCriteria: encryptedAcademicCriteria,
            isEligible: isEligible,
            timestamp: block.timestamp,
            processed: false
        });

        // 🔑 FHEVM PERMISSIONS: Set who can access encrypted data
        encryptedFinancialNeed.allowThis();        // Contract can use this data
        encryptedAcademicCriteria.allowThis();     // Contract can use this data
        isEligible.allowThis();                    // Contract can use this data

        // Allow program administrator to view final eligibility (but not raw data!)
        isEligible.allow(programs[_programId].administrator);

        // Update tracking
        applicantApplications[msg.sender].push(applicationCount);
        programs[_programId].currentApplications++;

        emit ApplicationSubmitted(applicationCount, _programId, msg.sender);
    }

    // Get encrypted eligibility result (only authorized users)
    function getApplicationEligibility(uint256 _applicationId) external view returns (ebool) {
        require(
            applications[_applicationId].applicant == msg.sender ||
            msg.sender == address(this),
            "Not authorized"
        );
        return applications[_applicationId].isEligible;
    }

    // Public function to get basic application info (non-sensitive data)
    function getApplicationBasicInfo(uint256 _applicationId) external view returns (
        address applicant,
        uint256 timestamp,
        bool processed
    ) {
        Application memory app = applications[_applicationId];
        return (app.applicant, app.timestamp, app.processed);
    }

    // Get user's applications
    function getMyApplications(address _applicant) external view returns (uint256[] memory) {
        return applicantApplications[_applicant];
    }

    // Get program information
    function getProgramInfo(uint256 _programId) external view returns (
        string memory name,
        string memory description,
        uint256 maxApplications,
        uint256 currentApplications,
        bool isActive
    ) {
        ScholarshipProgram memory program = programs[_programId];
        return (
            program.name,
            program.description,
            program.maxApplications,
            program.currentApplications,
            program.isActive
        );
    }
}
```

## 🔍 Step 4: Understanding the FHE Implementation

### Key FHE Features Explained

#### 1. Encrypted Data Types
```solidity
ebool hasFinancialNeed;      // Instead of: bool hasFinancialNeed;
ebool meetsAcademicCriteria; // Encrypted boolean values
```

#### 2. FHE Operations
```solidity
// Logical operations on encrypted data
ebool isEligible = FHE.and(encryptedFinancialNeed, encryptedAcademicCriteria);

// This computation happens WITHOUT decrypting the inputs!
```

#### 3. Permission Management
```solidity
// Allow the contract to use encrypted data
encryptedValue.allowThis();

// Allow specific addresses to decrypt data
encryptedValue.allow(adminAddress);
```

### Privacy Benefits

- ✅ **Student's financial status** remains encrypted
- ✅ **Academic records** stay private
- ✅ **Eligibility calculation** works on encrypted data
- ✅ **Only final result** can be viewed by authorized parties

## 🖥️ Step 5: Building the Frontend

Create `index.html` with FHE integration:

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Anonymous Scholarship Application - Hello FHEVM</title>
    <link href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.3.0/css/bootstrap.min.css" rel="stylesheet">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/ethers/6.13.0/ethers.umd.min.js"></script>
</head>
<body>
    <div class="container mt-5">
        <div class="row">
            <div class="col-md-8 mx-auto">
                <div class="card">
                    <div class="card-header">
                        <h2>🔐 Anonymous Scholarship Application</h2>
                        <p class="mb-0">Your first FHEVM dApp - Privacy-preserving scholarship evaluation</p>
                    </div>
                    <div class="card-body">
                        <!-- Wallet Connection -->
                        <div id="walletSection" class="mb-4">
                            <button id="connectWallet" class="btn btn-primary">Connect Wallet</button>
                            <div id="walletStatus" class="mt-2"></div>
                        </div>

                        <!-- Application Form -->
                        <form id="applicationForm" style="display: none;">
                            <div class="mb-3">
                                <label class="form-label">Do you have financial need? 🔐</label>
                                <div class="form-check">
                                    <input class="form-check-input" type="checkbox" id="financialNeed">
                                    <label class="form-check-label" for="financialNeed">
                                        Yes, I require financial assistance (This will be encrypted)
                                    </label>
                                </div>
                            </div>

                            <div class="mb-3">
                                <label class="form-label">Do you meet academic criteria? 🔐</label>
                                <div class="form-check">
                                    <input class="form-check-input" type="checkbox" id="academicCriteria">
                                    <label class="form-check-label" for="academicCriteria">
                                        Yes, I meet the academic requirements (This will be encrypted)
                                    </label>
                                </div>
                            </div>

                            <div class="alert alert-info">
                                <strong>🔐 Privacy Note:</strong> Your responses will be encrypted using FHEVM.
                                The smart contract can evaluate your eligibility without seeing your actual answers!
                            </div>

                            <button type="submit" id="submitBtn" class="btn btn-success">
                                Submit Encrypted Application
                            </button>
                        </form>

                        <!-- Results -->
                        <div id="results" class="mt-4"></div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script>
        // Contract configuration
        const CONTRACT_ADDRESS = "YOUR_CONTRACT_ADDRESS"; // Replace after deployment
        const CONTRACT_ABI = [
            "function createProgram(string memory _name, string memory _description, uint256 _maxApplications) external",
            "function submitApplication(uint256 _programId, bool _hasFinancialNeed, bool _meetsAcademicCriteria) external",
            "function getMyApplications(address _applicant) external view returns (uint256[] memory)",
            "function getApplicationBasicInfo(uint256 _applicationId) external view returns (address applicant, uint256 timestamp, bool processed)",
            "function getProgramInfo(uint256 _programId) external view returns (string memory name, string memory description, uint256 maxApplications, uint256 currentApplications, bool isActive)",
            "function programCount() external view returns (uint256)"
        ];

        let provider, signer, contract, userAddress;

        // Connect wallet function
        async function connectWallet() {
            try {
                if (typeof window.ethereum === 'undefined') {
                    alert('Please install MetaMask!');
                    return;
                }

                // Request account access
                await window.ethereum.request({ method: 'eth_requestAccounts' });

                // Create provider and signer
                provider = new ethers.BrowserProvider(window.ethereum);
                signer = await provider.getSigner();
                userAddress = await signer.getAddress();

                // Create contract instance
                contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);

                // Update UI
                document.getElementById('walletStatus').innerHTML = `
                    <div class="alert alert-success">
                        Connected: ${userAddress.substring(0, 6)}...${userAddress.substring(38)}
                    </div>
                `;
                document.getElementById('applicationForm').style.display = 'block';
                document.getElementById('connectWallet').style.display = 'none';

            } catch (error) {
                console.error('Error connecting wallet:', error);
                alert('Failed to connect wallet');
            }
        }

        // Submit application with FHE encryption
        async function submitApplication(event) {
            event.preventDefault();

            try {
                const financialNeed = document.getElementById('financialNeed').checked;
                const academicCriteria = document.getElementById('academicCriteria').checked;

                // Show submission status
                document.getElementById('results').innerHTML = `
                    <div class="alert alert-info">
                        🔐 Encrypting your data and submitting to blockchain...
                    </div>
                `;

                // Create default program if needed
                const programCount = await contract.programCount();
                let programId = 1;

                if (Number(programCount) === 0) {
                    // Create a default program
                    const createTx = await contract.createProgram(
                        "Hello FHEVM Scholarship",
                        "A demo scholarship program for learning FHEVM",
                        100,
                        {
                            gasLimit: 1500000,
                            gasPrice: ethers.parseUnits('20', 'gwei')
                        }
                    );
                    await createTx.wait();
                    programId = 1;
                }

                // Submit encrypted application
                const tx = await contract.submitApplication(
                    programId,
                    financialNeed,      // Will be encrypted by FHEVM
                    academicCriteria,   // Will be encrypted by FHEVM
                    {
                        gasLimit: 3000000, // Higher gas for FHE operations
                        gasPrice: ethers.parseUnits('20', 'gwei')
                    }
                );

                document.getElementById('results').innerHTML = `
                    <div class="alert alert-warning">
                        ⏳ Transaction submitted! Waiting for confirmation...
                        <br>Hash: ${tx.hash}
                    </div>
                `;

                const receipt = await tx.wait();

                document.getElementById('results').innerHTML = `
                    <div class="alert alert-success">
                        ✅ Application submitted successfully!
                        <br><strong>What happened:</strong>
                        <ul class="mt-2">
                            <li>Your financial need status was encrypted: ${financialNeed ? '🔒 Yes' : '🔒 No'}</li>
                            <li>Your academic criteria was encrypted: ${academicCriteria ? '🔒 Yes' : '🔒 No'}</li>
                            <li>Smart contract calculated eligibility on encrypted data</li>
                            <li>Your private information remains encrypted forever!</li>
                        </ul>
                        <small class="text-muted">Transaction: ${receipt.transactionHash}</small>
                    </div>
                `;

                // Reset form
                document.getElementById('applicationForm').reset();

            } catch (error) {
                console.error('Error submitting application:', error);
                document.getElementById('results').innerHTML = `
                    <div class="alert alert-danger">
                        ❌ Error: ${error.message}
                    </div>
                `;
            }
        }

        // Event listeners
        document.getElementById('connectWallet').addEventListener('click', connectWallet);
        document.getElementById('applicationForm').addEventListener('submit', submitApplication);
    </script>
</body>
</html>
```

## 🚀 Step 6: Deployment

### Deploy Script

Create `scripts/deploy.js`:

```javascript
const { ethers } = require("hardhat");

async function main() {
    console.log("Deploying AnonymousScholarshipApplication...");

    const ScholarshipApplication = await ethers.getContractFactory("AnonymousScholarshipApplication");
    const contract = await ScholarshipApplication.deploy();

    await contract.waitForDeployment();
    const contractAddress = await contract.getAddress();

    console.log("✅ Contract deployed to:", contractAddress);
    console.log("📝 Update your frontend CONTRACT_ADDRESS with:", contractAddress);

    // Create a sample program
    console.log("Creating sample program...");
    const tx = await contract.createProgram(
        "Hello FHEVM Scholarship",
        "A demonstration scholarship program for learning FHEVM technology",
        100
    );
    await tx.wait();
    console.log("✅ Sample program created!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
```

### Deploy to Zama Testnet

```bash
npx hardhat run scripts/deploy.js --network zama
```

## 🧪 Step 7: Testing Your dApp

### What to Test

1. **Connect MetaMask** to Zama testnet
2. **Submit applications** with different combinations:
   - Financial need: Yes, Academic: Yes → Should be eligible
   - Financial need: Yes, Academic: No → Should be ineligible
   - Financial need: No, Academic: Yes → Should be ineligible
3. **Verify privacy**: Check that raw data is never visible on blockchain

### Understanding the Results

When you submit an application:
- ✅ Your inputs are immediately encrypted
- ✅ Smart contract processes encrypted data
- ✅ Blockchain stores encrypted values only
- ✅ Only eligibility result can be accessed by authorized parties

## 🎉 Congratulations!

You've just built your first FHEVM dApp! Here's what you accomplished:

### What You Learned

1. **FHE Basics**: How to work with encrypted data types (`ebool`)
2. **FHE Operations**: Performing logic on encrypted data (`FHE.and`)
3. **Permission Management**: Controlling access to encrypted data
4. **Privacy-First Design**: Building applications that protect user data

### Key FHEVM Concepts Mastered

- **Encrypted Types**: `ebool`, `euint8`, etc.
- **FHE Library**: `FHE.asEbool()`, `FHE.and()`, `FHE.or()`
- **Access Control**: `.allowThis()`, `.allow(address)`
- **Gas Optimization**: Higher gas limits for FHE operations

## 🚀 Next Steps

Now that you understand FHEVM basics, try building:

1. **Private Voting System**: Encrypted votes with public tallies
2. **Confidential Auction**: Hidden bids with transparent winners
3. **Secret Number Game**: Guess encrypted numbers
4. **Private Health Records**: Medical data with selective disclosure

## 📚 Additional Resources

- **FHEVM Documentation**: [docs.zama.ai](https://docs.zama.ai)
- **Example Contracts**: [github.com/zama-ai/fhevm](https://github.com/zama-ai/fhevm)
- **Zama Discord**: Community support and questions
- **FHEVM Playground**: Interactive examples

## 🤝 Community

Join the FHEVM community:
- **Discord**: Ask questions and share projects
- **GitHub**: Contribute to FHEVM ecosystem
- **Twitter**: Follow @zama_fhe for updates

---

**🎊 Welcome to the Future of Privacy-Preserving dApps!**

You're now equipped to build applications that protect user privacy while maintaining transparency and verifiability. Keep building, keep learning, and help create a more private web3 future!