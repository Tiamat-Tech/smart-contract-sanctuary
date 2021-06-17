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
    struct sendPair {
        address payable _address;
        uint256 _amount;
    }

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

    function isWhitelist(address payable account) public view returns(bool) {
        return whitelist[account];
    }

    constructor(address _tokenAddress) {
        payableToken = IERC20(_tokenAddress);
    }

    function setERC20Token(address _tokenAddress) public onlyOwner {
        require(_tokenAddress.isContract(), "Address is not token address");
        payableToken = IERC20(_tokenAddress);
    }

    function _validAddresses(sendPair[] memory _pairs, uint256 _balance) internal pure returns(bool) {
        uint256 _sum = 0;
        for (uint256 k = 0; k < _pairs.length; k++) {
            if (_pairs[k]._address == address(0)) return false;
            _sum = _sum + _pairs[k]._amount;
        }
        if (_sum > _balance) return false;
        return true;
    }

    function multiTransferFrom(sendPair[] memory pairs) public {
        uint256 _balance = payableToken.balanceOf(_msgSender());
        require(_validAddresses(pairs, _balance), "Invalid data!");
        for (uint256 i = 0; i < pairs.length; i++) {
            address payable _account = pairs[i]._address;
            uint256 _amount = pairs[i]._amount;
            require(payableToken.transferFrom(_msgSender(), _account, _amount), "Failed to send to account");
        }
    }
}