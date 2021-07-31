//SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./interfaces/IERC20.sol";
import '@openzeppelin/contracts/access/Ownable.sol';

interface IDO {
    function isOpen() external view returns (bool);
    function commitTokens(uint256 amount, bool agreement) external returns (bool);
}

contract IDORush is Ownable {
    IDO public ido;
    IERC20 public token;

    mapping(address => bool) public executors;

    modifier onlyExecutor() {
        require(executors[msg.sender], "Executor only");
        _;
    }

    constructor(address _ido, address _token) {
        ido = IDO(_ido);
        token = IERC20(_token);

        setExecutor(owner(), true);

        token.approve(address(ido), uint(-1));
    }

    function setExecutor(address executor, bool set) public onlyOwner {
        if(set) {
            executors[executor] = true;
        } else {
            delete executors[executor];
        }
    }

    function exec() public onlyExecutor returns (bool){
        if(!ido.isOpen()) {
            return false;
        }

        uint bal = token.balanceOf(address(this));
        if (bal == 0) {
            return false;
        }

        return ido.commitTokens(bal, true);
    }

    function withdraw(address _token) public onlyOwner {
        token = IERC20(_token);
        token.transfer(owner(), token.balanceOf(address(this)));
    }
}