// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract BryanContract is Ownable {
    using SafeMath for uint256;
    using Address for address;

    IERC20 public payableToken;

    mapping(address => bool) private whitelist;
    /**
        Define whitelist
     */
    function addWhitelist(address payable account) public onlyOwner {
        whitelist[account] = true;
    }

    function removeWhitelist(address payable account) public onlyOwner {
        whitelist[account] = false;
    }

    function isWhitelist(address account) public view returns(bool) {
        return whitelist[account];
    }

    constructor(address _tokenAddress) {
        payableToken = IERC20(_tokenAddress);
        addWhitelist(payable(_msgSender()));
    }

    function setERC20Token(address _tokenAddress) public onlyOwner {
        require(_tokenAddress.isContract(), "Address is not token address");
        payableToken = IERC20(_tokenAddress);
    }

    function _validAddresses(address[] memory _accounts, uint256[] memory _amounts, uint256 _balance) internal pure returns(bool) {
        uint256 _sum = 0;
        for (uint256 k = 0; k < _accounts.length; k++) {
            if (address(_accounts[k]) != _accounts[k]) return false;
            _sum = _sum.add(_amounts[k]);
        }
        if (_sum > _balance) return false;
        return true;
    }

    function multiTransferFrom(address[] memory receivers, uint256[] memory amounts) public {
        require(receivers.length == amounts.length, "Accounts and amounts are not matched!");
        require(isWhitelist(_msgSender()), "You are not in whitelist!");

        uint256 _balance = payableToken.balanceOf(_msgSender());
        require(_validAddresses(receivers, amounts, _balance), "Invalid data!");
        
        for (uint256 i = 0; i < receivers.length; i++) {
            payableToken.transferFrom(_msgSender(), address(receivers[i]), amounts[i]);
        }
    }
}