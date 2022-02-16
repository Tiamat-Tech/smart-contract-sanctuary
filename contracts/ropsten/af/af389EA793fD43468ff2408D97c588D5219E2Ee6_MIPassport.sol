// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract MIPassport is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Strings for uint256;

    bytes32 public merkleRoot;

    string public baseURI;

    enum WorkflowStatus {
        Disabled,
        Enabled
    }

    WorkflowStatus public workflow;

    mapping(address => uint256) public tokensPerWallet;

    constructor(
        string memory _initBaseURI
    ) ERC721("MetaIsland Passport", "MIP") {
        workflow = WorkflowStatus.Disabled;
        setBaseURI(_initBaseURI);
    }

    function verifyEligibility(bytes32[] calldata _merkleProof) public view returns (bool) {
      bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
      return MerkleProof.verify(_merkleProof, merkleRoot, leaf);
    }

    function freeMint(bytes32[] calldata _merkleProof) external nonReentrant
    {
        uint256 supply = totalSupply();
        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));

        require(workflow == WorkflowStatus.Enabled, "MetaIsland Passport: Contract not active");
        require(tokensPerWallet[msg.sender] + 1 <= 1, "MetaIsland Passport: Free mint is 1 token only");
        require(MerkleProof.verify(_merkleProof, merkleRoot, leaf), "MetaIsland Passport: You are not eligible");

        tokensPerWallet[msg.sender] += 1;
        _safeMint(msg.sender, supply + 1);
    }

    function setMerkleRoot(bytes32 root) public onlyOwner {
        merkleRoot = root;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function enableMint() external onlyOwner {
        workflow = WorkflowStatus.Enabled;
    }

    function disableMint() external onlyOwner {
        workflow = WorkflowStatus.Disabled;
    }

    function revokePassport(uint256 _tokenId) external onlyOwner {
        _transfer(ownerOf(_tokenId), msg.sender, _tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        if (tokenId < 500000) {
            return baseURI;
        }
        return tokenId.toString();
    }

}