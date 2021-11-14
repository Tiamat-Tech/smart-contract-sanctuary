// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20, Ownable{
    
    bool private _mintingFinished = false;
    
    event MintFinished();


    modifier canMint() {
        require(!_mintingFinished, "minting is finished");
        _;
    }

    
    constructor() ERC20("hmmk", "HMMK"){
        _mint(_msgSender(), 100000000000000000000000);
    }
    
    

    function mintingFinished() public view returns (bool) {
        return _mintingFinished;
    }

    function mint(address account, uint256 amount) public canMint onlyOwner{
        _mint(account, amount);
    }

    function finishMinting() public canMint onlyOwner{
        _finishMinting();
    }

 
    function _finishMinting() internal virtual onlyOwner{
        _mintingFinished = true;

        emit MintFinished();
    }
}