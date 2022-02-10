// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "./simple-vote-v1.sol";

contract MyBallotV2 is MyBallotV1 {
    // new variable of v2
    address public chairman_v2;
    
    function version() external pure override returns (string memory) {
        return "2.0";
    }

    function initialize(uint256 _numProposalNames) public override initializer {
        super.initialize(_numProposalNames);
        chairman_v2 = 0x1CAA12DBc2da0c825247dFCCC444b003a89cB4aA;
    }
}