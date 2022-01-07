// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LeiTingToken is ERC20, Ownable {
    constructor() ERC20("LeiTingToken", "LTT") {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }

    //测试用，直接给调用者铸造新币
    function mintToMe(uint256 amount) public {
        _mint(msg.sender, amount);
    }
}