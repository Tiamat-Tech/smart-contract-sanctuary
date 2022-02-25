// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "./ERC1155.sol";
import "../../access/Ownable.sol";

contract DNFT is ERC1155, Ownable {
    constructor() ERC1155("https://soxchain-dnft.s3.sa-east-1.amazonaws.com/{id}.json") {}
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }
    function mint(uint256 id, uint256 amount)
        public 
        payable
    {
        require(id > 0, "Token doesn't exist");        
        _mint(msg.sender, id, amount, "");
    }
}