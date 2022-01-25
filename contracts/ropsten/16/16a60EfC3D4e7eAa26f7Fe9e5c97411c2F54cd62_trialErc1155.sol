// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract trialErc1155 is ERC1155,Ownable{
    constructor() ERC1155("") {
    for(uint i ;i<20;i++){
        _mint(msg.sender, i, 10**4, "");
    }
    }
    function batchMint(address _to,uint[] calldata _ids,uint[] calldata _amount) public onlyOwner{
        _mintBatch(_to,_ids,_amount,"");
    }
}