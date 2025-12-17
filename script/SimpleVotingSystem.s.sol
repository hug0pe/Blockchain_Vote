// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {SimpleVotingSystem} from "../src/SimpleVotingSystem.sol";
import {VotingNFT} from "../src/VotingNFT.sol";

contract SimpleVotingSystemDeploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        VotingNFT nft = new VotingNFT();
        SimpleVotingSystem voting = new SimpleVotingSystem(address(nft));

        nft.grantRole(nft.MINTER_ROLE(), address(voting));

        vm.stopBroadcast();
    }
}

