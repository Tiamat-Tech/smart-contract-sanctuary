// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/// @custom:security-contact [email protected]
contract Hopmints is ERC1155, Ownable, Pausable, ERC1155Burnable {
     using Strings for uint256;

     // Token name
    string private _name = "Hopmints";

    // Token symbol
    string private _symbol = "HPMTS";

    // Optional mapping for token URIs
    mapping (uint256 => string) private _tokenURIs;

    // Base URI
    string private _baseURI;

    //returns the name
     function name() public view virtual returns (string memory) {
        return _name;
    }

    // returns the symbol
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }
    
    constructor() ERC1155("") {}

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function baseURI() public view returns (string memory) {
        return _baseURI;
    }


    function _tokenURI(uint id) public view virtual returns(string memory) {
        string memory currentURI = _tokenURIs[id];
        string memory base = baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return currentURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(currentURI).length > 0) {
            return string(abi.encodePacked(base, currentURI));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(base, id.toString()));
    }

   function uri(uint id) public view override virtual returns (string memory) {
        return _tokenURI(id);
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data, string memory tokenURI)
        public {
        _tokenURIs[id] = tokenURI;
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        public
        onlyOwner
    {
        _mintBatch(to, ids, amounts, data);
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}