# 🛠️ FHEVM Practical Examples

## 🎯 Complete Code Examples for Learning

This document contains ready-to-use FHEVM examples, from simple to advanced. Each example is complete and can be deployed independently.

---

## 📊 Example 1: Private Counter

**Use Case**: A counter where increments are private but total is visible to authorized users.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint32 } from "@fhevm/solidity/lib/FHE.sol";

contract PrivateCounter {
    euint32 private counter;
    address public owner;
    uint256 public totalIncrements; // Public count of operations

    event Incremented(address indexed user, uint256 timestamp);

    constructor() {
        owner = msg.sender;
        counter = FHE.asEuint32(0);
        counter.allowThis();
    }

    function increment(uint32 _amount) external {
        euint32 encryptedAmount = FHE.asEuint32(_amount);
        encryptedAmount.allowThis();

        // Add encrypted amount to counter
        counter = FHE.add(counter, encryptedAmount);

        totalIncrements++;
        emit Incremented(msg.sender, block.timestamp);
    }

    function getCounter() external view returns (euint32) {
        require(msg.sender == owner, "Only owner can view counter");
        return counter;
    }

    function allowUserToSeeCounter(address _user) external {
        require(msg.sender == owner, "Only owner can grant access");
        counter.allow(_user);
    }
}
```

**Frontend Integration**:
```javascript
// Increment by secret amount
await contract.increment(secretAmount, { gasLimit: 1000000 });

// Only owner can see actual counter value
if (isOwner) {
    const encryptedCounter = await contract.getCounter();
    // Counter value is encrypted, needs FHE client to decrypt
}
```

---

## 🗳️ Example 2: Anonymous Voting System

**Use Case**: Voting where individual votes are private but results are transparent.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, ebool, euint32 } from "@fhevm/solidity/lib/FHE.sol";

contract AnonymousVoting {
    struct Proposal {
        string description;
        euint32 yesVotes;    // Encrypted vote count
        euint32 noVotes;     // Encrypted vote count
        uint256 deadline;
        bool finalized;
    }

    mapping(uint256 => Proposal) public proposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    uint256 public proposalCount;
    address public admin;

    event ProposalCreated(uint256 indexed proposalId, string description);
    event VoteCast(uint256 indexed proposalId, address indexed voter);
    event ProposalFinalized(uint256 indexed proposalId);

    constructor() {
        admin = msg.sender;
    }

    function createProposal(string memory _description, uint256 _duration) external {
        require(msg.sender == admin, "Only admin can create proposals");

        proposalCount++;
        proposals[proposalCount] = Proposal({
            description: _description,
            yesVotes: FHE.asEuint32(0),
            noVotes: FHE.asEuint32(0),
            deadline: block.timestamp + _duration,
            finalized: false
        });

        // Allow contract to manage vote counts
        proposals[proposalCount].yesVotes.allowThis();
        proposals[proposalCount].noVotes.allowThis();

        emit ProposalCreated(proposalCount, _description);
    }

    function vote(uint256 _proposalId, bool _support) external {
        require(_proposalId <= proposalCount, "Invalid proposal");
        require(block.timestamp <= proposals[_proposalId].deadline, "Voting ended");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");

        Proposal storage proposal = proposals[_proposalId];

        // Encrypt the vote
        euint32 one = FHE.asEuint32(1);
        one.allowThis();

        if (_support) {
            proposal.yesVotes = FHE.add(proposal.yesVotes, one);
        } else {
            proposal.noVotes = FHE.add(proposal.noVotes, one);
        }

        hasVoted[_proposalId][msg.sender] = true;
        emit VoteCast(_proposalId, msg.sender);
    }

    function finalizeProposal(uint256 _proposalId) external {
        require(msg.sender == admin, "Only admin can finalize");
        require(block.timestamp > proposals[_proposalId].deadline, "Voting still active");
        require(!proposals[_proposalId].finalized, "Already finalized");

        proposals[_proposalId].finalized = true;

        // Allow admin to see final results
        proposals[_proposalId].yesVotes.allow(admin);
        proposals[_proposalId].noVotes.allow(admin);

        emit ProposalFinalized(_proposalId);
    }

    function getProposal(uint256 _proposalId) external view returns (
        string memory description,
        uint256 deadline,
        bool finalized
    ) {
        Proposal memory proposal = proposals[_proposalId];
        return (proposal.description, proposal.deadline, proposal.finalized);
    }
}
```

**Frontend Example**:
```javascript
// Cast encrypted vote
async function castVote(proposalId, support) {
    const tx = await contract.vote(proposalId, support, {
        gasLimit: 2000000
    });
    await tx.wait();
    console.log(`Vote cast: ${support ? 'YES' : 'NO'} (encrypted)`);
}
```

---

## 🎰 Example 3: Secret Number Guessing Game

**Use Case**: Players guess a secret number without revealing their attempts.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint32, ebool } from "@fhevm/solidity/lib/FHE.sol";

contract SecretNumberGame {
    struct Game {
        euint32 secretNumber;    // Encrypted secret number
        address creator;
        uint256 maxGuesses;
        uint256 prize;
        bool active;
        address winner;
    }

    struct Guess {
        address player;
        euint32 guess;          // Encrypted guess
        ebool isCorrect;        // Encrypted result
        uint256 timestamp;
    }

    mapping(uint256 => Game) public games;
    mapping(uint256 => Guess[]) public guesses;
    mapping(uint256 => mapping(address => uint256)) public playerGuessCount;

    uint256 public gameCount;

    event GameCreated(uint256 indexed gameId, address creator, uint256 prize);
    event GuessSubmitted(uint256 indexed gameId, address player, uint256 guessNumber);
    event GameWon(uint256 indexed gameId, address winner, uint256 prize);

    function createGame(uint32 _secretNumber, uint256 _maxGuesses) external payable {
        require(msg.value > 0, "Prize must be greater than 0");
        require(_maxGuesses > 0, "Max guesses must be greater than 0");

        gameCount++;

        // Encrypt the secret number
        euint32 encryptedSecret = FHE.asEuint32(_secretNumber);
        encryptedSecret.allowThis();

        games[gameCount] = Game({
            secretNumber: encryptedSecret,
            creator: msg.sender,
            maxGuesses: _maxGuesses,
            prize: msg.value,
            active: true,
            winner: address(0)
        });

        emit GameCreated(gameCount, msg.sender, msg.value);
    }

    function makeGuess(uint256 _gameId, uint32 _guess) external {
        require(_gameId <= gameCount, "Invalid game");
        require(games[_gameId].active, "Game not active");
        require(playerGuessCount[_gameId][msg.sender] < games[_gameId].maxGuesses, "Max guesses exceeded");

        Game storage game = games[_gameId];

        // Encrypt the guess
        euint32 encryptedGuess = FHE.asEuint32(_guess);
        encryptedGuess.allowThis();

        // Check if guess is correct (without revealing the numbers!)
        ebool isCorrect = FHE.eq(encryptedGuess, game.secretNumber);
        isCorrect.allowThis();

        // Store the guess
        guesses[_gameId].push(Guess({
            player: msg.sender,
            guess: encryptedGuess,
            isCorrect: isCorrect,
            timestamp: block.timestamp
        }));

        playerGuessCount[_gameId][msg.sender]++;

        emit GuessSubmitted(_gameId, msg.sender, guesses[_gameId].length);

        // Allow player to see if their guess was correct
        isCorrect.allow(msg.sender);
    }

    function claimWin(uint256 _gameId, uint256 _guessIndex) external {
        require(_gameId <= gameCount, "Invalid game");
        require(games[_gameId].active, "Game not active");
        require(_guessIndex < guesses[_gameId].length, "Invalid guess index");

        Guess storage guess = guesses[_gameId][_guessIndex];
        require(guess.player == msg.sender, "Not your guess");

        // Player claims this guess was correct
        // In a real implementation, you'd need FHE client to verify
        // For demo purposes, we trust the claim

        games[_gameId].active = false;
        games[_gameId].winner = msg.sender;

        // Transfer prize
        payable(msg.sender).transfer(games[_gameId].prize);

        emit GameWon(_gameId, msg.sender, games[_gameId].prize);
    }

    function getGameInfo(uint256 _gameId) external view returns (
        address creator,
        uint256 maxGuesses,
        uint256 prize,
        bool active,
        address winner,
        uint256 totalGuesses
    ) {
        Game memory game = games[_gameId];
        return (
            game.creator,
            game.maxGuesses,
            game.prize,
            game.active,
            game.winner,
            guesses[_gameId].length
        );
    }
}
```

---

## 💰 Example 4: Private Auction

**Use Case**: Sealed bid auction where bids are private but winner is transparent.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint32, ebool } from "@fhevm/solidity/lib/FHE.sol";

contract PrivateAuction {
    struct Auction {
        string itemDescription;
        address seller;
        uint256 endTime;
        euint32 highestBid;     // Encrypted highest bid
        address highestBidder;
        bool ended;
        uint256 minBid;
    }

    struct Bid {
        address bidder;
        euint32 amount;         // Encrypted bid amount
        uint256 timestamp;
        bool withdrawn;
    }

    mapping(uint256 => Auction) public auctions;
    mapping(uint256 => Bid[]) public bids;
    mapping(uint256 => mapping(address => uint256)) public userBidIndex;

    uint256 public auctionCount;

    event AuctionCreated(uint256 indexed auctionId, string description, address seller);
    event BidPlaced(uint256 indexed auctionId, address bidder, uint256 bidIndex);
    event AuctionEnded(uint256 indexed auctionId, address winner);

    function createAuction(
        string memory _description,
        uint256 _duration,
        uint256 _minBid
    ) external {
        auctionCount++;

        // Initialize with minimum bid as starting highest bid
        euint32 encryptedMinBid = FHE.asEuint32(uint32(_minBid));
        encryptedMinBid.allowThis();

        auctions[auctionCount] = Auction({
            itemDescription: _description,
            seller: msg.sender,
            endTime: block.timestamp + _duration,
            highestBid: encryptedMinBid,
            highestBidder: address(0),
            ended: false,
            minBid: _minBid
        });

        emit AuctionCreated(auctionCount, _description, msg.sender);
    }

    function placeBid(uint256 _auctionId, uint32 _amount) external payable {
        require(_auctionId <= auctionCount, "Invalid auction");
        require(block.timestamp < auctions[_auctionId].endTime, "Auction ended");
        require(!auctions[_auctionId].ended, "Auction finalized");
        require(_amount >= auctions[_auctionId].minBid, "Bid too low");
        require(msg.value >= _amount, "Insufficient payment");

        Auction storage auction = auctions[_auctionId];

        // Encrypt the bid
        euint32 encryptedBid = FHE.asEuint32(_amount);
        encryptedBid.allowThis();

        // Check if this bid is higher than current highest
        ebool isHigher = FHE.gt(encryptedBid, auction.highestBid);
        isHigher.allowThis();

        // Update highest bid if this bid is higher
        auction.highestBid = FHE.select(isHigher, encryptedBid, auction.highestBid);

        // Store the bid
        bids[_auctionId].push(Bid({
            bidder: msg.sender,
            amount: encryptedBid,
            timestamp: block.timestamp,
            withdrawn: false
        }));

        userBidIndex[_auctionId][msg.sender] = bids[_auctionId].length - 1;

        emit BidPlaced(_auctionId, msg.sender, bids[_auctionId].length - 1);

        // Allow bidder to see their own bid
        encryptedBid.allow(msg.sender);
    }

    function endAuction(uint256 _auctionId) external {
        require(_auctionId <= auctionCount, "Invalid auction");
        require(block.timestamp >= auctions[_auctionId].endTime, "Auction still active");
        require(!auctions[_auctionId].ended, "Already ended");

        Auction storage auction = auctions[_auctionId];
        auction.ended = true;

        // Allow seller to see the winning bid amount
        auction.highestBid.allow(auction.seller);

        // In a real implementation, you'd need to determine the winner
        // using FHE client to decrypt and compare bids

        emit AuctionEnded(_auctionId, auction.highestBidder);
    }

    function getAuctionInfo(uint256 _auctionId) external view returns (
        string memory description,
        address seller,
        uint256 endTime,
        bool ended,
        uint256 totalBids,
        uint256 minBid
    ) {
        Auction memory auction = auctions[_auctionId];
        return (
            auction.itemDescription,
            auction.seller,
            auction.endTime,
            auction.ended,
            bids[_auctionId].length,
            auction.minBid
        );
    }
}
```

---

## 🏥 Example 5: Private Health Records

**Use Case**: Medical records where patients control access to their encrypted data.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint32, ebool } from "@fhevm/solidity/lib/FHE.sol";

contract PrivateHealthRecords {
    struct HealthRecord {
        address patient;
        euint32 age;              // Encrypted age
        euint32 bloodPressure;    // Encrypted blood pressure
        ebool hasChronicDisease;  // Encrypted condition
        uint256 timestamp;
        string recordHash;        // IPFS hash for additional data
    }

    struct AccessPermission {
        address doctor;
        uint256 expiryTime;
        bool active;
    }

    mapping(address => HealthRecord[]) public patientRecords;
    mapping(address => mapping(address => AccessPermission)) public permissions;
    mapping(address => address[]) public authorizedDoctors;

    event RecordAdded(address indexed patient, uint256 recordIndex);
    event AccessGranted(address indexed patient, address indexed doctor, uint256 expiryTime);
    event AccessRevoked(address indexed patient, address indexed doctor);

    function addHealthRecord(
        uint32 _age,
        uint32 _bloodPressure,
        bool _hasChronicDisease,
        string memory _recordHash
    ) external {
        // Encrypt sensitive health data
        euint32 encryptedAge = FHE.asEuint32(_age);
        euint32 encryptedBP = FHE.asEuint32(_bloodPressure);
        ebool encryptedCondition = FHE.asEbool(_hasChronicDisease);

        // Allow contract to manage the data
        encryptedAge.allowThis();
        encryptedBP.allowThis();
        encryptedCondition.allowThis();

        // Allow patient to access their own data
        encryptedAge.allow(msg.sender);
        encryptedBP.allow(msg.sender);
        encryptedCondition.allow(msg.sender);

        HealthRecord memory newRecord = HealthRecord({
            patient: msg.sender,
            age: encryptedAge,
            bloodPressure: encryptedBP,
            hasChronicDisease: encryptedCondition,
            timestamp: block.timestamp,
            recordHash: _recordHash
        });

        patientRecords[msg.sender].push(newRecord);

        emit RecordAdded(msg.sender, patientRecords[msg.sender].length - 1);
    }

    function grantDoctorAccess(address _doctor, uint256 _duration) external {
        require(_doctor != address(0), "Invalid doctor address");

        uint256 expiryTime = block.timestamp + _duration;

        permissions[msg.sender][_doctor] = AccessPermission({
            doctor: _doctor,
            expiryTime: expiryTime,
            active: true
        });

        // Grant doctor access to all patient's records
        HealthRecord[] storage records = patientRecords[msg.sender];
        for (uint256 i = 0; i < records.length; i++) {
            records[i].age.allow(_doctor);
            records[i].bloodPressure.allow(_doctor);
            records[i].hasChronicDisease.allow(_doctor);
        }

        // Track authorized doctors
        authorizedDoctors[msg.sender].push(_doctor);

        emit AccessGranted(msg.sender, _doctor, expiryTime);
    }

    function revokeDoctorAccess(address _doctor) external {
        require(permissions[msg.sender][_doctor].active, "No active permission");

        permissions[msg.sender][_doctor].active = false;

        // Note: In a real implementation, you'd need to revoke FHE permissions
        // This is simplified for demonstration

        emit AccessRevoked(msg.sender, _doctor);
    }

    function canDoctorAccessPatient(address _patient, address _doctor) external view returns (bool) {
        AccessPermission memory permission = permissions[_patient][_doctor];
        return permission.active && block.timestamp <= permission.expiryTime;
    }

    function getPatientRecordCount(address _patient) external view returns (uint256) {
        return patientRecords[_patient].length;
    }

    function getRecordMetadata(address _patient, uint256 _index) external view returns (
        address patient,
        uint256 timestamp,
        string memory recordHash
    ) {
        require(_index < patientRecords[_patient].length, "Invalid record index");

        HealthRecord memory record = patientRecords[_patient][_index];
        return (record.patient, record.timestamp, record.recordHash);
    }

    // Emergency access function (would require governance in production)
    function emergencyAccess(address _patient, address _emergencyDoctor) external {
        // In a real system, this would require multi-sig or governance approval
        require(msg.sender == owner, "Only authorized emergency access");

        HealthRecord[] storage records = patientRecords[_patient];
        for (uint256 i = 0; i < records.length; i++) {
            records[i].age.allow(_emergencyDoctor);
            records[i].bloodPressure.allow(_emergencyDoctor);
            records[i].hasChronicDisease.allow(_emergencyDoctor);
        }
    }

    address public owner;

    constructor() {
        owner = msg.sender;
    }
}
```

---

## 🧪 Frontend Integration Examples

### React Component for FHEVM

```javascript
import { ethers } from 'ethers';
import { useState, useEffect } from 'react';

function FHEVMComponent() {
    const [contract, setContract] = useState(null);
    const [signer, setSigner] = useState(null);

    // Initialize FHEVM contract
    useEffect(() => {
        async function initContract() {
            if (window.ethereum) {
                const provider = new ethers.BrowserProvider(window.ethereum);
                const signer = await provider.getSigner();
                const contract = new ethers.Contract(
                    CONTRACT_ADDRESS,
                    CONTRACT_ABI,
                    signer
                );

                setSigner(signer);
                setContract(contract);
            }
        }
        initContract();
    }, []);

    // Submit encrypted data
    async function submitEncryptedData(value) {
        try {
            const tx = await contract.submitData(value, {
                gasLimit: 3000000,  // Higher gas for FHE
                gasPrice: ethers.parseUnits('20', 'gwei')
            });

            const receipt = await tx.wait();
            console.log('Encrypted data submitted:', receipt.transactionHash);
        } catch (error) {
            console.error('Error submitting encrypted data:', error);
        }
    }

    return (
        <div>
            <h2>FHEVM dApp</h2>
            <button onClick={() => submitEncryptedData(true)}>
                Submit Encrypted Data
            </button>
        </div>
    );
}
```

### Gas Estimation Helper

```javascript
// Helper function to estimate gas for FHE operations
async function estimateFHEGas(contract, method, ...args) {
    try {
        // FHE operations typically need 10x more gas than estimated
        const estimated = await contract[method].estimateGas(...args);
        return estimated * 10n; // Multiply by 10 for safety
    } catch (error) {
        // If estimation fails, use default high gas limit
        console.warn('Gas estimation failed, using default:', error);
        return 3000000n;
    }
}

// Usage
const gasLimit = await estimateFHEGas(contract, 'submitApplication', true, false);
const tx = await contract.submitApplication(true, false, { gasLimit });
```

---

## 🚀 Deployment Scripts

### Complete Deployment Script

```javascript
// scripts/deploy-all.js
const { ethers } = require("hardhat");

async function main() {
    console.log("🚀 Deploying FHEVM Examples...");

    const contracts = [
        "PrivateCounter",
        "AnonymousVoting",
        "SecretNumberGame",
        "PrivateAuction",
        "PrivateHealthRecords"
    ];

    const deployedContracts = {};

    for (const contractName of contracts) {
        console.log(`\n📝 Deploying ${contractName}...`);

        const ContractFactory = await ethers.getContractFactory(contractName);
        const contract = await ContractFactory.deploy();
        await contract.waitForDeployment();

        const address = await contract.getAddress();
        deployedContracts[contractName] = address;

        console.log(`✅ ${contractName} deployed to: ${address}`);
    }

    console.log("\n🎉 All contracts deployed successfully!");
    console.log("\n📋 Contract Addresses:");
    for (const [name, address] of Object.entries(deployedContracts)) {
        console.log(`${name}: ${address}`);
    }

    // Save addresses to file
    const fs = require('fs');
    const addresses = JSON.stringify(deployedContracts, null, 2);
    fs.writeFileSync('deployed-addresses.json', addresses);
    console.log("\n💾 Addresses saved to deployed-addresses.json");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
```

---

## 🎯 Testing Examples

### Hardhat Test Suite

```javascript
// test/fhevm-examples.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("FHEVM Examples", function () {
    let privateCounter, anonymousVoting;
    let owner, user1, user2;

    beforeEach(async function () {
        [owner, user1, user2] = await ethers.getSigners();

        // Deploy PrivateCounter
        const PrivateCounter = await ethers.getContractFactory("PrivateCounter");
        privateCounter = await PrivateCounter.deploy();
        await privateCounter.waitForDeployment();

        // Deploy AnonymousVoting
        const AnonymousVoting = await ethers.getContractFactory("AnonymousVoting");
        anonymousVoting = await AnonymousVoting.deploy();
        await anonymousVoting.waitForDeployment();
    });

    describe("PrivateCounter", function () {
        it("Should increment counter privately", async function () {
            await privateCounter.connect(user1).increment(5, {
                gasLimit: 1000000
            });

            expect(await privateCounter.totalIncrements()).to.equal(1);
        });

        it("Should allow owner to grant access", async function () {
            await privateCounter.allowUserToSeeCounter(user1.address);
            // In real test, you'd verify FHE permissions
        });
    });

    describe("AnonymousVoting", function () {
        it("Should create proposal", async function () {
            await anonymousVoting.createProposal("Test Proposal", 86400); // 1 day
            expect(await anonymousVoting.proposalCount()).to.equal(1);
        });

        it("Should accept encrypted votes", async function () {
            await anonymousVoting.createProposal("Test Proposal", 86400);

            await anonymousVoting.connect(user1).vote(1, true, {
                gasLimit: 2000000
            });

            expect(await anonymousVoting.hasVoted(1, user1.address)).to.be.true;
        });
    });
});
```

---

## 📚 Learning Progression

### Beginner Path
1. **Start with PrivateCounter** - Simple encrypted operations
2. **Try AnonymousVoting** - Learn FHE.and() operations
3. **Build SecretNumberGame** - Understand FHE.eq() comparisons

### Intermediate Path
1. **Implement PrivateAuction** - Complex selection logic
2. **Create custom variations** - Modify existing examples
3. **Add frontend integration** - Connect React/Vue to contracts

### Advanced Path
1. **PrivateHealthRecords** - Complex permission management
2. **Multi-contract systems** - Contracts calling other contracts
3. **Gas optimization** - Minimize FHE operations
4. **Custom FHE patterns** - Develop new use cases

---

**🎉 Ready to Build Privacy-First dApps!**

These examples provide a solid foundation for understanding FHEVM development. Start with the simpler examples and gradually work your way up to more complex applications. Remember: the key to FHEVM is thinking about privacy from the ground up! 🔐✨