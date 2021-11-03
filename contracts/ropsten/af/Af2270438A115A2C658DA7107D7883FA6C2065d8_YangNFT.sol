// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract YangNFT is ERC721, AccessControl{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    string private _baseTokenURI = "ipfs://QmeSjSinHpPnmXmspMjwiXyN6zS4E9zccariGR3jxcaWtq/";
    uint256 public nextIndex = 0;
    uint256 private constant MAXSUPPLY = 8000;

    constructor() ERC721("YangNFT", "YNFT") {
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        //return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
        return super.supportsInterface(interfaceId);
    }

    function grantMinter(address minter) public {
        grantRole(MINTER_ROLE, minter);
    }

    function _baseURI() internal view virtual override returns (string memory){
        return _baseTokenURI;
    }

    function baseURI() public view returns (string memory){
        return _baseURI();
    }

    function setBaseURI(string memory baseTokenURI) public onlyRole(getRoleAdmin(MINTER_ROLE)){
        _baseTokenURI = baseTokenURI;
    }

    function mintForFree() public {
        require(nextIndex<MAXSUPPLY, "tokenIndex out of scope");
        _safeMint(msg.sender, nextIndex);
        nextIndex++;
    }

}