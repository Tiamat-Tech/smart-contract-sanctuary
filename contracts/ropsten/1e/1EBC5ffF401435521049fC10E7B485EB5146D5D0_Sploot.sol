// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "hardhat/console.sol";


contract Sploot is ERC721, Ownable {
    uint private mintTracker;
    uint private burnTracker;

    bytes32 public merkleRoot;
    mapping(address => uint) public allowlistClaimed;

    string private _baseTokenURI;
    uint private constant maxMints = 3000;
    uint private constant mintPrice = 60000000000000000;
    bool private paused = true;
    bool private open = false;

    mapping(uint => uint) private dataMap;

    constructor(bytes32 _merkleRoot) ERC721("Sploot", "SPLOOT") {
        _baseTokenURI = "";
        merkleRoot = _merkleRoot;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
    
    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function mint(bytes32[] calldata proof, uint256 allowedAmount, bool free, uint mintAmount) public payable {
        require(!paused || msg.sender == owner());
        require(mintTracker+mintAmount <= maxMints, "That exceeds the max amount of NFTs");

        require((allowlistClaimed[msg.sender] + mintAmount) <= allowedAmount || open, "Address can not mint that many."); //Make sure they haven't used up their mints
        require(MerkleProof.verify(proof, merkleRoot, getLeaf(msg.sender, allowedAmount, free))|| open, "Minter is not allowlisted."); //Make sure their address, allowed amount, and if they have to pay matches the allowlist
        require(msg.value == mintPrice*mintAmount || (free && !open), "It costs 0.06 eth to mint a Sploot.");

        allowlistClaimed[msg.sender] = allowlistClaimed[msg.sender] + mintAmount; //Update how many they have minted
        
        for (uint256 i = 0; i < mintAmount; i++) {
            _mint(msg.sender, mintTracker+i);
        }
        mintTracker = mintTracker+mintAmount;
    }

    function getLeaf(address addr, uint256 amount, bool free) public pure returns(bytes32) {
        return keccak256(abi.encodePacked(addr, amount, free));
    }

    function adminMint(uint amount) public onlyOwner {
        for (uint256 i = 0; i < amount; i++) {
            mintTracker++;
            _mint(msg.sender, mintTracker);
        }
    }

    function setRoot(bytes32 root) public onlyOwner {
        merkleRoot = root;
    }

    function pauseUnpause(bool p) public {
        paused = p;
    }

    function openToPublic(bool o) public onlyOwner {
        open = o;
    }

    function totalSupply() public view returns(uint) {
        return mintTracker-burnTracker;
    }

    function burn(uint tokenId) public virtual {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Caller is not owner nor approved");
        burnTracker++;
        _burn(tokenId);
    }

    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

}