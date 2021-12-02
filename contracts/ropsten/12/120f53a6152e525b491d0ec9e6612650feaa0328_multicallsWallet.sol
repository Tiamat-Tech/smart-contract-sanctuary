/**
 *Submitted for verification at Etherscan.io on 2021-12-02
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract multicallsWallet {

    address public owner;
    address public pendingOwner;
    mapping(address => bool) public members;

    constructor () payable {
        owner = payable(msg.sender);
    }

     receive() external payable {
    }

    struct Call {
        address target;
        bytes callData;
    }
    function multicalls(Call[] memory calls) public returns (uint256 blockNumber, bytes[] memory returnData) {
        require(members[msg.sender], "not member");
        blockNumber = block.number;
        returnData = new bytes[](calls.length);
        for(uint256 i = 0; i < calls.length; i++) {
            (bool success, bytes memory ret) = calls[i].target.call(calls[i].callData);
            require(success);
            returnData[i] = ret;
        }
    }

    function setOwner(address _owner) public {
        require(msg.sender == owner, "not owner");
        pendingOwner = _owner;
    }
    
    function acceptOwner() public {
        require(msg.sender == pendingOwner, "not pendingOwner");
        owner = pendingOwner;
    }
    
    function addmember(address _member) public {
        require(msg.sender == owner, "not owner");
        members[_member] = true;
    }
    
    function removemember(address _member) public {
        require(msg.sender == owner, "not owner");
        members[_member] = false;
    }
    
    function withdrawToken(IERC20 token, address recipient, uint256 amount) public {
        require(members[msg.sender], "not member");
        token.transfer(recipient, amount);
    }

    function withdrawTokens(IERC20[] memory _tokens, address recipient) public {
        require(members[msg.sender], "not member");
        for(uint i=0; i < _tokens.length; i++){
            IERC20 token = IERC20 (_tokens[i]);
            token.transfer(recipient, token.balanceOf(address(this)));
        }
    }

    function withdrawEther(address payable _to, uint _amount) public {
        require(members[msg.sender], "not member");
        (bool success, ) = _to.call{value: _amount}("");
        require(success, "Failed to send Ether");
    }
    
    function withdrawEtherAll(address payable _to) public {
        require(members[msg.sender], "not member");
        uint amount = address(this).balance;
        (bool success, ) = _to.call{value: amount}("");
        require(success, "Failed to send Ether");
    }
}