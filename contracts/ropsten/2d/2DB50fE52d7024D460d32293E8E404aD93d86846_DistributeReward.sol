// SPDX-License-Identifier: MIT
import "./MyRevengeNFT.sol";

pragma solidity ^0.8.0;

contract DistributeReward {

    address public constant team = 0x283c0C9d54E42b01154d41b4cd3E9645b6b530A8;
    address public constant dev = 0x408ECB06EF97705Afb02646ae1E5537F370a6bfB;
    address public constant NFTContract = 0x373c157d16cB66F4d5B81cE81971ED321912e2FA;

    function distribute() external {
        require(MyRevengeNFT(NFTContract).balanceOf(msg.sender) >= 1);
        uint256 balance = address(this).balance;
        uint256 devReward = balance * 9 / 100;
        uint256 teamReward = balance * 5 / 100;
        uint256 NFTReward =  balance * 85 / 100;

        payable(dev).transfer(devReward);
        payable(team).transfer(teamReward);
        payable(msg.sender).transfer(NFTReward);
    }

    function getNFTHolderBalance() public view returns(uint256) {
        uint256 balance = address(this).balance;
        uint256 NFTReward =  balance * 85 / 100;

        return NFTReward;
    }
}