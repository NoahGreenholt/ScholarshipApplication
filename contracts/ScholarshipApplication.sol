// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint8, ebool } from "@fhevm/solidity/lib/FHE.sol";

contract AnonymousScholarshipApplication {
    using FHE for ebool;

    struct Application {
        address applicant;
        ebool hasFinancialNeed;      // FHE encrypted boolean
        ebool meetsAcademicCriteria; // FHE encrypted boolean
        ebool isEligible;            // FHE encrypted boolean
        uint256 timestamp;
        bool processed;
    }

    struct ScholarshipProgram {
        string name;
        string description;
        uint256 maxApplications;
        uint256 currentApplications;
        bool isActive;
        address administrator;
    }

    uint256 public applicationCount;
    uint256 public programCount;
    
    mapping(uint256 => Application) public applications;
    mapping(uint256 => ScholarshipProgram) public programs;
    mapping(address => uint256[]) public applicantApplications;
    mapping(uint256 => uint256[]) public programApplications; // programId => applicationIds

    event ApplicationSubmitted(uint256 indexed applicationId, uint256 indexed programId, address indexed applicant);
    event ApplicationProcessed(uint256 indexed applicationId, bool approved);
    event ProgramCreated(uint256 indexed programId, string name, address administrator);

    modifier onlyProgramAdmin(uint256 _programId) {
        require(programs[_programId].administrator == msg.sender, "Not program administrator");
        _;
    }

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

    function submitApplication(
        uint256 _programId,
        bool _hasFinancialNeed,
        bool _meetsAcademicCriteria
    ) external {
        require(_programId > 0 && _programId <= programCount, "Invalid program ID");
        require(programs[_programId].isActive, "Program not active");
        require(programs[_programId].currentApplications < programs[_programId].maxApplications, "Program full");

        // Convert boolean to FHE encrypted boolean using asEbool
        ebool encryptedFinancialNeed = FHE.asEbool(_hasFinancialNeed);
        ebool encryptedAcademicCriteria = FHE.asEbool(_meetsAcademicCriteria);
        
        // Calculate eligibility: both conditions must be true
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

        // Set permissions for FHE data
        encryptedFinancialNeed.allowThis();
        encryptedAcademicCriteria.allowThis();
        isEligible.allowThis();
        
        // Allow program administrator to view eligibility
        isEligible.allow(programs[_programId].administrator);

        // Update mappings
        applicantApplications[msg.sender].push(applicationCount);
        programApplications[_programId].push(applicationCount);
        programs[_programId].currentApplications++;

        emit ApplicationSubmitted(applicationCount, _programId, msg.sender);
    }

    function processApplication(
        uint256 _applicationId,
        uint256 _programId,
        bool _approved
    ) external onlyProgramAdmin(_programId) {
        require(!applications[_applicationId].processed, "Already processed");
        
        applications[_applicationId].processed = true;
        
        emit ApplicationProcessed(_applicationId, _approved);
    }

    function getApplicationEligibility(uint256 _applicationId) external view returns (ebool) {
        require(
            applications[_applicationId].applicant == msg.sender || 
            msg.sender == address(this),
            "Not authorized"
        );
        return applications[_applicationId].isEligible;
    }

    function getMyApplications(address _applicant) external view returns (uint256[] memory) {
        return applicantApplications[_applicant];
    }

    function getProgramApplications(uint256 _programId) external view returns (uint256[] memory) {
        require(programs[_programId].administrator == msg.sender, "Not authorized");
        return programApplications[_programId];
    }

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

    function toggleProgramStatus(uint256 _programId) external onlyProgramAdmin(_programId) {
        programs[_programId].isActive = !programs[_programId].isActive;
    }

    function getApplicationBasicInfo(uint256 _applicationId) external view returns (
        address applicant,
        uint256 timestamp,
        bool processed
    ) {
        Application memory app = applications[_applicationId];
        return (app.applicant, app.timestamp, app.processed);
    }
}