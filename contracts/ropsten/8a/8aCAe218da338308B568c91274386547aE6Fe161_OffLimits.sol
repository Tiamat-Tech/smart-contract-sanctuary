// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OffLimits is ERC1155, Ownable {
    string public name = "OffLimits";
    string public symbol = "OLA";

    constructor(address operator) ERC1155("") { 
        _mint(operator, 1, 250, "");
        _mint(operator, 2, 25, "");
    }
    
    function uri(uint256 index) public view virtual override returns (string memory) {
        require(index == 1 || index == 2, "URI query for nonexistent token");
        
        if (index == 1) {
            return "ipfs://QmRhhTusRt6h5ZPa73HFaPVCkT1BXW8THGS8us1dwRyjgt";   
        } else {
            return "ipfs://QmP3QRqzSxuEDyFFAAPvVmG6mfDLZkRAG8ExgcEs5G3MMQ";
        }
    }
    
    function contractURI() public pure returns (string memory) {
        return "ipfs://QmRjfWVcUfNBGDQeSeShF7rxf8pzDUnEXxbr7hxJvJj4tq";
    }
}