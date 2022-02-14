// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BingDwenDwen is ERC20 {

    uint256 constant initialSupply = 20220204 ether;

    constructor(address redEnvelopAddr) ERC20("BingDwenDwen","DWEN") {
        uint256 toTeam = initialSupply * 600 / 100 / 100;
        // to the team
        _mint(msg.sender,toTeam);
        // dapp red envelopAddr
        _mint(redEnvelopAddr, initialSupply - toTeam);
        // inject into the contract
        (bool success,bytes memory data) = redEnvelopAddr.call(abi.encodeWithSelector(bytes4(keccak256(bytes("initBonusCoin(address)"))),address(this)));
        require(success && (data.length == 0) || abi.decode(data, (bool)), "BingDwenDwen Coin: INIT_FAILED");
    }
}