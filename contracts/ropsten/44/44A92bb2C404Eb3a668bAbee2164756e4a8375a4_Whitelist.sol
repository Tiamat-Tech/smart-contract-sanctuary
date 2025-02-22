// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';


contract Whitelist is Ownable {
    using SafeERC20 for IERC20;

    mapping(address => bool) public whitelist;

    event TokensRecovered(address token, address to, uint value);
    event Whitelisted(address user);
    event RemovedFromWhitelist(address user);

    constructor(address _owner) {
        _transferOwnership(_owner);
    }

    function batchAddToWhitelist(address[] memory _users) external onlyOwner {
        for (uint i = 0; i < _users.length; i++) {
            _addToWhitelist(_users[i]);
        }
    }

    function addToWhitelist(address _user) external onlyOwner {
        _addToWhitelist(_user);
    }

    function _addToWhitelist(address _user) internal {
        require(!whitelist[_user], 'Already whitelisted');
        whitelist[_user] = true;
        emit Whitelisted(_user);
    }

    function removeFromWhitelist(address _user) external onlyOwner {
        require(whitelist[_user], 'Not whitelisted');
        whitelist[_user] = false;
        emit RemovedFromWhitelist(_user);
    }


    function recoverTokens(IERC20 _token, address _destination) external onlyOwner {
        require(_destination != address(0), 'Auction: Zero address not allowed');

        uint balance = _token.balanceOf(address(this));
        if (balance > 0) {
            _token.safeTransfer(_destination, balance);
            emit TokensRecovered(address(_token), _destination, balance);
        }
    }
}