//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "./BaseERC721.sol";
import "./Whitelisted.sol";
import "./PhaseOne.sol";

contract Bedlam is Ownable, ReentrancyGuard, BaseERC721, Whitelisted, PhaseOne {          
    using SafeMath for uint256;
    bool isPhaseSaleActive;

    struct Submission {
        bool isSubmitted;
        uint16[5] value;
    }
    mapping(uint => Submission) private submissions; 
    ERC1155 private opensea;

    constructor(ERC1155 _opensea, bytes32 _root, uint256 _supply, uint256 _max) PhaseOne()
        Whitelisted(
            _root
        )
        BaseERC721(
            _supply, 
            _max,
            0.09 ether,
            "fakeUrl/",
            "Bedlam",
            "BED"         
        ) {
            opensea = _opensea;
        }

    function phaseOneMint(uint token) external nonReentrant {
        uint current = totalSupply();
        require(isPhaseSaleActive, "Not live");
        require(opensea.balanceOf(msg.sender, token) != 0, "Not owner");
        require(!phaseOne[token].isMinted, "Already minted");
        require(phaseOne[token].isPhaseOne, "Invalid");      
        require(current < supply, "Sold out");
        uint256 currentToken = current;
        _safeMint(msg.sender, totalSupply() + 1);      
        updatePhaseOne(token, currentToken);
        delete current;
        delete currentToken;
    }

    function whitelistMint(uint256 count, uint256 tokenId, bytes32[] calldata proof) external payable nonReentrant {               
        require(_verify(_leaf(msg.sender, tokenId), proof), "Invalid"); 
        require(isWhitelistActive, "Not Live"); 

        _callMint(count);
    }

    function submitSymbol(uint256 id, uint16[5] memory value) external nonReentrant {
        require(ownerOf(id) == msg.sender, "Not owner");
        require(!submissions[id].isSubmitted, "Cannot resubmit");
        Submission memory submission;
        submission.isSubmitted = true;
        submission.value = value;
        submissions[id] = submission;
    }

    function togglePhaseOne() external onlyOwner {
        isPhaseSaleActive = !isPhaseSaleActive;
    }

    function getSubmission(uint id) external view returns (uint16[5] memory) {        
        return (submissions[id].value);
    }
}