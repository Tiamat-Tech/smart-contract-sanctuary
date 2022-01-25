// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract trialErc721 is ERC721 ,Ownable{

    uint public tokenId;
    constructor() ERC721("Trial", "TRA") {
    }

    function batchMint(address _to,uint _amount)  public onlyOwner{
        for(uint i;i<_amount;i++){
            tokenId++;
            _mint(_to,tokenId);
        }
    }
    
}