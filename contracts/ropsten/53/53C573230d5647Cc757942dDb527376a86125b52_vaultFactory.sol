pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract vaultFactory {
    vault[] public vaults;
    function createVault(string memory name, string memory symbol, address keyAddress, uint256 keyTokenId) public payable returns (vault) {
        require(IERC721(keyAddress).ownerOf(keyTokenId) == msg.sender, "must own the NFT");
        vault newVault = new vault(name, symbol, keyAddress, keyTokenId);
        vaults.push(newVault);
        return newVault;
    }
}

contract vault is ERC721, Ownable {
    string public _name;
    string public _symbol;
    address public _owner;
    address public _keyAddress;
    uint256 public _keyTokenId;
    constructor(string memory name, string memory symbol,
        address keyAddress, uint256 keyTokenId) ERC721(name, symbol) {
            _name = name;
            _symbol = symbol;
            _owner = msg.sender;
            _keyAddress = keyAddress;
            _keyTokenId = keyTokenId; 
        }

        function returnKey() public view returns (address, uint256){
            return (_keyAddress, _keyTokenId);
        }
}

contract contentNFTs is ERC721 {
    string public _name;
    string public _symbol;
    uint256 public tokennumber;
    constructor (string memory name, string memory symbol) ERC721(name, symbol){
        _name = name;
        _symbol = symbol;
        tokennumber = 0;
    }
    function mintNFT() public returns (uint256){
        uint256 newItemId = tokennumber;
        _safeMint(msg.sender, newItemId);
        tokennumber++; 
        return newItemId;
    }
}