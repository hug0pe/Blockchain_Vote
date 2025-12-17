// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {VotingNFT} from "./VotingNFT.sol";

contract SimpleVotingSystem is AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");

    enum WorkflowStatus {
        REGISTER_CANDIDATES,
        FOUND_CANDIDATES,
        VOTE,
        COMPLETED
    }

    WorkflowStatus public status;
    uint256 public voteStartTime;

    struct Candidate {
        uint256 id;
        string name;
        uint256 voteCount;
        uint256 fundsReceived;
    }

    mapping(uint256 => Candidate) public candidates;
    mapping(address => bool) public voters;
    uint256[] private candidateIds;

    VotingNFT public votingNFT;

    event CandidateRegistered(uint256 id, string name);
    event WorkflowStatusChanged(WorkflowStatus status);
    event Voted(address voter, uint256 candidateId);
    event FundsSent(uint256 candidateId, uint256 amount);

    constructor(address _nftAddress) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        status = WorkflowStatus.REGISTER_CANDIDATES;
        votingNFT = VotingNFT(_nftAddress);
    }

    modifier onlyStatus(WorkflowStatus _status) {
        _onlyStatus(_status);
        _;
    }

    function _onlyStatus(WorkflowStatus _status) internal view {
        require(status == _status, "Invalid workflow status");
    }

    function setWorkflowStatus(WorkflowStatus _status) external onlyRole(ADMIN_ROLE) {
        status = _status;

        if (_status == WorkflowStatus.VOTE) {
            voteStartTime = block.timestamp;
        }

        emit WorkflowStatusChanged(_status);
    }

    function addCandidate(string memory _name)
        public
        onlyRole(ADMIN_ROLE)
        onlyStatus(WorkflowStatus.REGISTER_CANDIDATES)
    {
        require(bytes(_name).length > 0, "Candidate name cannot be empty");
        uint256 candidateId = candidateIds.length + 1;
        candidates[candidateId] = Candidate({id: candidateId, name: _name, voteCount: 0, fundsReceived: 0});
        candidateIds.push(candidateId);

        emit CandidateRegistered(candidateId, _name);
    }

    function vote(uint256 _candidateId) public onlyStatus(WorkflowStatus.VOTE) {
        require(block.timestamp >= voteStartTime + 1 hours, "Voting not open yet");
        require(!voters[msg.sender], "You have already voted");
        require(!votingNFT.hasNFT(msg.sender), "You already own a voting NFT");
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");

        voters[msg.sender] = true;
        candidates[_candidateId].voteCount += 1;

        votingNFT.mint(msg.sender);

        emit Voted(msg.sender, _candidateId);
    }

    function fundCandidate(uint256 _candidateId)
        external
        payable
        onlyRole(FOUNDER_ROLE)
        onlyStatus(WorkflowStatus.FOUND_CANDIDATES)
    {
        require(msg.value > 0, "No ETH sent");
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");

        candidates[_candidateId].fundsReceived += msg.value;

        emit FundsSent(_candidateId, msg.value);
    }

    receive() external payable {}

    fallback() external payable {}

    function getWinner() external view onlyStatus(WorkflowStatus.COMPLETED) returns (Candidate memory winner) {
        uint256 maxVotes;
        for (uint256 i = 0; i < candidateIds.length; i++) {
            Candidate memory candidate = candidates[candidateIds[i]];
            if (candidate.voteCount > maxVotes) {
                maxVotes = candidate.voteCount;
                winner = candidate;
            }
        }
    }

    function getTotalVotes(uint256 _candidateId) public view returns (uint256) {
        require(_candidateId > 0 && _candidateId <= candidateIds.length, "Invalid candidate ID");
        return candidates[_candidateId].voteCount;
    }

    function getCandidatesCount() public view returns (uint256) {
        return candidateIds.length;
    }
}
