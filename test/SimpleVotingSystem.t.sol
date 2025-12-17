// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {SimpleVotingSystem} from "../src/SimpleVotingSystem.sol";
import {VotingNFT} from "../src/VotingNFT.sol";

contract SimpleVotingSystemTest is Test {
    SimpleVotingSystem voting;
    VotingNFT votingNFT;
    
    address admin = address(0x1);
    address founder = address(0x2);
    address voter1 = address(0x3);
    address voter2 = address(0x4);
    address voter3 = address(0x5);

    function setUp() public {
        vm.startPrank(admin);
        
        votingNFT = new VotingNFT();
        voting = new SimpleVotingSystem(address(votingNFT));
        
        votingNFT.grantRole(votingNFT.MINTER_ROLE(), address(voting));
        voting.grantRole(voting.FOUNDER_ROLE(), founder);
        
        vm.stopPrank();
    }

    function testAdminCanAddCandidate() public {
        vm.prank(admin);
        voting.addCandidate("Candidate 1");
        
        assert(voting.getCandidatesCount() == 1);
    }

    function testNonAdminCannotAddCandidate() public {
        vm.prank(voter1);
        vm.expectRevert();
        voting.addCandidate("Candidate 1");
    }

    function testAdminCanSetWorkflowStatus() public {
        vm.prank(admin);
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES);
        
        assert(uint(voting.status()) == uint(SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES));
    }

    function testNonAdminCannotSetWorkflowStatus() public {
        vm.prank(voter1);
        vm.expectRevert();
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES);
    }

    function testCanRegisterCandidateWhenInREGISTER_CANDIDATES() public {
        vm.prank(admin);
        voting.addCandidate("Candidate 1");
        
        assert(voting.getCandidatesCount() == 1);
    }

    function testCannotRegisterCandidateOutsideREGISTER_CANDIDATES() public {
        vm.startPrank(admin);
        voting.addCandidate("Candidate 1");
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES);
        
        vm.expectRevert();
        voting.addCandidate("Candidate 2");
        vm.stopPrank();
    }

    function testCannotVoteBeforeVotingStatus() public {
        vm.startPrank(admin);
        voting.addCandidate("Candidate 1");
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES);
        vm.stopPrank();
        
        vm.prank(voter1);
        vm.expectRevert();
        voting.vote(1);
    }

    function testCannotVoteBeforeOneHourPassed() public {
        vm.startPrank(admin);
        voting.addCandidate("Candidate 1");
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);
        vm.stopPrank();
        
        vm.prank(voter1);
        vm.expectRevert("Voting not open yet");
        voting.vote(1);
    }

    function testCanVoteAfterOneHourAndVotingStatus() public {
        vm.startPrank(admin);
        voting.addCandidate("Candidate 1");
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 1 hours + 1);
        
        vm.prank(voter1);
        voting.vote(1);
        
        assert(voting.getTotalVotes(1) == 1);
    }

    function testCannotVoteTwice() public {
        vm.startPrank(admin);
        voting.addCandidate("Candidate 1");
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 1 hours + 1);
        
        vm.startPrank(voter1);
        voting.vote(1);
        
        vm.expectRevert("You have already voted");
        voting.vote(1);
        vm.stopPrank();
    }

    function testCannotVoteWithNFT() public {
        vm.startPrank(admin);
        voting.addCandidate("Candidate 1");
        voting.addCandidate("Candidate 2");
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 1 hours + 1);
        
        vm.prank(voter1);
        voting.vote(1);
        
        vm.prank(voter1);
        vm.expectRevert("You have already voted");
        voting.vote(2);
    }

    function testVoterReceivesNFT() public {
        vm.startPrank(admin);
        voting.addCandidate("Candidate 1");
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 1 hours + 1);
        
        vm.prank(voter1);
        voting.vote(1);
        
        assert(votingNFT.hasNFT(voter1));
    }

    function testCannotFundWithoutValue() public {
        vm.startPrank(admin);
        voting.addCandidate("Candidate 1");
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES);
        vm.stopPrank();
        
        vm.prank(founder);
        vm.expectRevert("No ETH sent");
        voting.fundCandidate{value: 0}(1);
    }

    function testGetWinnerInCompletedStatus() public {
        vm.startPrank(admin);
        voting.addCandidate("Candidate 1");
        voting.addCandidate("Candidate 2");
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 1 hours + 1);
        
        vm.prank(voter1);
        voting.vote(1);
        
        vm.prank(voter2);
        voting.vote(2);
        
        vm.prank(voter3);
        voting.vote(1);
        
        vm.prank(admin);
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.COMPLETED);
        
        SimpleVotingSystem.Candidate memory winner = voting.getWinner();
        assertEq(winner.id, 1);
        assertEq(winner.voteCount, 2);
    }

    function testCannotGetWinnerOutsideCompletedStatus() public {
        vm.prank(admin);
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES);
        
        vm.expectRevert();
        voting.getWinner();
    }

    function testGetCandidatesCount() public {
        vm.startPrank(admin);
        voting.addCandidate("Candidate 1");
        voting.addCandidate("Candidate 2");
        voting.addCandidate("Candidate 3");
        vm.stopPrank();
        
        assertEq(voting.getCandidatesCount(), 3);
    }

    function testGetTotalVotes() public {
        vm.startPrank(admin);
        voting.addCandidate("Candidate 1");
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 1 hours + 1);
        
        vm.prank(voter1);
        voting.vote(1);
        
        assertEq(voting.getTotalVotes(1), 1);
    }

    function testCannotVoteForInvalidCandidate() public {
        vm.startPrank(admin);
        voting.addCandidate("Candidate 1");
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 1 hours + 1);
        
        vm.prank(voter1);
        vm.expectRevert("Invalid candidate ID");
        voting.vote(999);
    }

    function testCannotGetTotalVotesForInvalidCandidate() public {
        vm.expectRevert("Invalid candidate ID");
        voting.getTotalVotes(999);
    }

    function testCannotRegisterEmptyCandidate() public {
        vm.prank(admin);
        vm.expectRevert("Candidate name cannot be empty");
        voting.addCandidate("");
    }

    function testMultipleStatusTransitions() public {
        vm.startPrank(admin);
        
        assert(uint(voting.status()) == uint(SimpleVotingSystem.WorkflowStatus.REGISTER_CANDIDATES));
        
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES);
        assert(uint(voting.status()) == uint(SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES));
        
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);
        assert(uint(voting.status()) == uint(SimpleVotingSystem.WorkflowStatus.VOTE));
        
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.COMPLETED);
        assert(uint(voting.status()) == uint(SimpleVotingSystem.WorkflowStatus.COMPLETED));
        
        vm.stopPrank();
    }

    function testCandidateRegisteredEvent() public {
        vm.prank(admin);
        
        vm.expectEmit(true, true, true, true);
        emit SimpleVotingSystem.CandidateRegistered(1, "Candidate 1");
        
        voting.addCandidate("Candidate 1");
    }

    function testWorkflowStatusChangedEvent() public {
        vm.prank(admin);
        
        vm.expectEmit(true, true, true, true);
        emit SimpleVotingSystem.WorkflowStatusChanged(SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES);
        
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.FOUND_CANDIDATES);
    }

    function testVotedEvent() public {
        vm.startPrank(admin);
        voting.addCandidate("Candidate 1");
        voting.setWorkflowStatus(SimpleVotingSystem.WorkflowStatus.VOTE);
        vm.stopPrank();
        
        vm.warp(block.timestamp + 1 hours + 1);
        
        vm.prank(voter1);
        
        vm.expectEmit(true, true, true, true);
        emit SimpleVotingSystem.Voted(voter1, 1);
        
        voting.vote(1);
    }
}