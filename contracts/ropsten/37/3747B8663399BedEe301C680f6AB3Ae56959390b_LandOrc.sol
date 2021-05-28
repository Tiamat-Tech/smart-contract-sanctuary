// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LandOrc is ERC20, Ownable {
    address lorcNFTAddress;

    constructor() ERC20("LandOrc", "LORC") {
        // Mint 21Million tokens to msg.sender
        _mint(msg.sender, 21000000 * 10 ** uint(decimals()));
    }

    /**
     * Throws if called by any account other than the LORC NFT Contract.
     */
    modifier isNFTContract() {
        require(lorcNFTAddress == _msgSender(), "Caller is not the LORC NFT Contract");
        _;
    }
    
    function increaseSupply(uint256 _amount) external isNFTContract{
        _mint(owner(), _amount);
    }

    function decreaseSupply(uint256 _amount) external isNFTContract{
        _burn(owner(), _amount);
    }

    /**
     * Only Owner can mint token
     */
    function mint(address _account, uint256 _amount) public onlyOwner {
        _mint(_account, _amount);
    }

    /**
     * Only Owner can burn token
     */
    function burn(address _account, uint256 _amount) public onlyOwner {
        _burn(_account, _amount);
    }
}