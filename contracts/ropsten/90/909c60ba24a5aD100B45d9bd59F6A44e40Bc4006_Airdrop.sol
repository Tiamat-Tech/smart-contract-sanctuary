// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Airdrop is Ownable {

    function doAirdrop(
        address _tokenAddress,
        address[] calldata _recipients,
        uint256[] calldata _tokenAmount
    ) public onlyOwner returns (uint256) {
        uint256 i = 0;
        while (i < _recipients.length) {
            IERC20(_tokenAddress).transferFrom(msg.sender, _recipients[i], _tokenAmount[i]);
            i += 1;
        }
        return (i);
    }
}