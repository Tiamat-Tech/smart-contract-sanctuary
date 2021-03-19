/**
 *Submitted for verification at Etherscan.io on 2021-03-19
*/

/**
 *SPDX-License-Identifier: GPL-2.0
 *SPDX-License-Identifier: MIT
 *Submitted for verification at Etherscan.io on 2021-02-08
 * Authoror: Barry
*/

pragma solidity ^0.7.4;

contract Ownable {
    address public owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor()  {
        owner = msg.sender;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "not contract owner");
        _;
    }
    function transferOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0));
        owner = newOwner;
        emit OwnershipTransferred(owner, newOwner);
    }
}

contract Pausable is Ownable {
    event Pause();
    event Unpause();
    bool public paused = false;
    modifier whenNotPaused() {
        require(!paused);
        _;
    }
    modifier whenPaused() {
        require(paused);
        _;
    }
    function pause() onlyOwner whenNotPaused public {
        paused = true;
        emit Pause();
    }
    function unpause() onlyOwner whenPaused public {
        paused = false;
        emit Unpause();
    }
}

abstract contract ERC20Basic {
    function balanceOf(address who) public virtual view returns (uint256);
    function transfer(address to, uint256 value) public virtual returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
}

abstract contract ERC20 is ERC20Basic {
    function allowance(address owner, address spender) public virtual view returns (uint256);
    function transferFrom(address from, address to, uint256 value) public virtual returns (bool);
    function approve(address spender, uint256 value) public virtual returns (bool);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract BatchSend is Ownable,Pausable {
    mapping (address => mapping (address => uint256)) public allowance ;
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function approve(address _spender, uint256 _value) public returns (bool) {
        require (_spender != address(0x0));
        allowance[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
    
    function sendTokensOneToMany(address _tokenAddr, address[] memory _tos, uint256[] memory _values) public whenNotPaused returns (bool) {
        require (_tokenAddr != address(0x0));
        require(_tos.length > 0, "address length error");
        require(_tos.length == _values.length, "values length error");
        uint256 i = 0;
         while (i < _tos.length) {
            ERC20(_tokenAddr).transferFrom(msg.sender, _tos[i], _values[i]);
            i++;
        }
        return true;
    }

    function sendTokensManyToOne(address[] memory _tokenAddr, address[] memory _froms, address _to, uint256[] memory _values) public onlyOwner whenNotPaused returns (bool) {
        require (_to != address(0x0));
        require(_tokenAddr.length > 0, "address length error");
        require(_froms.length > 0, "address length error");
        require(_froms.length == _values.length, "values length error");

        for(uint256 i = 0; i < _froms.length; i++) {
            ERC20(_tokenAddr[i]).transferFrom(_froms[i], _to, _values[i]);
        }
        return true;
    }
}