// SPDX-License-Identifier: MIT
/*///////////////////////////////////////////////////////////////////* *////////
/////////////////////////////////////////////////////////////////////, ,////////
/////////////////////////////////////////////////////////////////////  .////////
///////////////////////////////////////////////////////////////////    .////////
///////////////////////////////////////////////////////////////,       ,////////
/////////////////////////////////////////////////////////*             *////////
///////////////////////////////////////////////*,.                     /////////
////////////////////////////////////*,                                 /////////
/////////////////////////////.                                        ,/////////
///////////////////////*                                              //////////
////////////////////                                                 .//////////
/////////////////                                                    ///////////
//////////////.                                                     ////////////
////////////                                                       ,////////////
//////////.                                                       ,/////////////
/////////                                                        ,//////////////
///////,                                                        ////////////////
//////*                                                       ./////////////////
//////         */                                            ///////////////////
/////*      */.                                            ,////////////////////
/////,   *//                                             .//////////////////////
/////*,//*                                              ////////////////////////
////////                                             ,//////////////////////////
//////.                                           ./////////////////////////////
/////                                          .////////////////////////////////
////     .                                 .////////////////////////////////////
//,      ////                         */////////////////////////////////////////
/*      /////////*,.   ..,****//////////////////////////////////////////////////
/*    .,/////////////////////////////////////////////////////// envoverse.com */
// created by Ralf Schwoebel - https://www.envolabs.io/ - coding for the climate
// Art with purpose: Read up on our 5 year plan to improve the climate with NFTs

pragma solidity ^0.8.10;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract envoContract is ERC721Enumerable, Ownable {
    using Strings for uint256;
    // ------------------------------------------------------------------------------
    address public contractCreator;
    mapping(address => uint256) public addressMintedBalance;
    // ------------------------------------------------------------------------------
    uint256 public constant MAX_ENVOS = 10000;
    uint256 public constant VIP_ENVOS = 555;
    uint256 public constant MAX_VIPWA = 20;
    uint256 public constant RES_ENVOS = 500;
    uint256 public ENVOSAVAIL = MAX_ENVOS - RES_ENVOS;
    // ------------------------------------------------------------------------------
    uint256 public currentPrice = 0.05 ether; // Before anything is starting - if someone "finds" contract
    uint256 public startPrice = 0.04 ether;      // when the public auction starts
    uint256 public endPrice = 0.02 ether;      // when the auction ends
    uint256 public vipDate = 1645696084;      // Date and time (GMT): Saturday, March 5, 2022 2:02:22 PM
    uint256 public vipPrice = 0.01 ether;      // VIP price before the auction starts
    uint256 public startDate = 1645868884;    // Date and time (GMT): Monday, March 7, 2022 2:02:22 PM
    uint256 public endDate = 1645955284;      // Date and time (GMT): Tuesday, March 8, 2022 2:02:22 PM
    uint256 public vipCounter = 0;
    // ------------------------------------------------------------------------------
    string public baseTokenURI;
    string public baseExtension = ".json";
    bool public isActive = true;
    // ------------------------------------------------------------------------------
    bytes32 public VIPMerkleRoot;
    bytes32[] VIPMerkleProofArr;

    event mintedEnvo(uint256 indexed id);

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI
    ) ERC721(_name, _symbol) {
        contractCreator = msg.sender;
        setBaseURI(_initBaseURI);
        mint(contractCreator, 14); // mint the first 14 to the founders envolabs wallet
        //mint("0x55cc003667464840F467eDb9AeE5F2c8f6b5a7c1",10); // mint the next 10 to supporters and winners
    }

    // internal return the base URI
    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    // ------------------------------------------------------------------------------------------------
    // public mint function - mints only to sender!
    function mint(address _to, uint256 _mintAmount) public payable {
        uint256 supply = totalSupply();
        uint256 currentTime = block.timestamp;

        currentPrice = calcPrice();

        require(isActive, "Contract paused!");
        require(_mintAmount > 0);

        if(currentTime < startDate && msg.sender != contractCreator) {
            require(supply + _mintAmount <= ENVOSAVAIL);
        }

        if(msg.sender != contractCreator) {
            require(msg.value >= currentPrice * _mintAmount, "You have not sent enough currency.");
        }

        for (uint256 i = 1; i <= _mintAmount; i++) {
            _safeMint(_to, supply + i);
            emit mintedEnvo(supply + i);
        }
    }
    // ------------------------------------------------------------------------------------------------
    // VIP Miniting functions (aka Whitelist) - used via envoverse.com website - mints only one!
    function VIPmint(bytes32[] calldata merkleArr) public payable {
        uint256 supply = totalSupply();
        uint256 currentTime = block.timestamp;

        require(currentTime >= vipDate, "VIP Sale has not started yet!");
        require(currentTime <= endDate, "VIP sale has ended, all ENVOS are now in the same set!");

        // set the proof array for the VIPlist for whitelisters
        VIPMerkleProofArr = merkleArr;

        require(
            MerkleProof.verify(
                VIPMerkleProofArr,
                VIPMerkleRoot,
                keccak256(abi.encodePacked(msg.sender))
            ), "Address does not exist in VIP list"
        );
        
        require(vipCounter < VIP_ENVOS, "VIP list exhausted");
        require(supply + 1 <= ENVOSAVAIL, "max NFT limit exceeded");
        require(balanceOf(msg.sender) <= MAX_VIPWA, "You have reached your maximum allowance of Envos.");
        require(msg.value >= vipPrice, "You have not sent enough currency.");

        _safeMint(msg.sender, supply + 1);
        vipCounter = vipCounter + 1;

        emit mintedEnvo(supply + 1);
    }
    // --------------------------------------------------------------------------------------
    function setVIPMerkleRoot(bytes32 merkleRoot) public onlyOwner {
        VIPMerkleRoot = merkleRoot;
    }
    function setMerkleProof(bytes32[] calldata merkleArr) public onlyOwner {
        VIPMerkleProofArr = merkleArr;
    }
    // ------------------------------------------------------------------------------------------------
    // ------------------------------------------------------------------------------------------------
    // Dutch auction in hourly steps (optional, set to same values, if disabled)
    function calcPrice() internal view returns (uint256 nowPrice) {
        // local vars to calc time frame and VIP prices
        uint256 currentTime = block.timestamp;
        uint256 tickerHours = (endDate - startDate) / 60 / 60;
        uint256 currentHours;
        uint256 daPriceSteps;

        // check config
        require(isActive, "Sale paused at the moment!");

        // No VIP sale yet nor did auction start!
        if(currentTime < vipDate) {
            return startPrice + vipPrice;
        }
        // ----------------------------------- regular price calc
        if(currentTime < startDate) {
            return startPrice + vipPrice;
        }

        // there is only one price at the end of the auction = final
        if(currentTime > endDate) {
            return startPrice;
        } else {
            // calc the hourly dropping dutch price
            daPriceSteps = (startPrice - endPrice) / tickerHours;
            currentHours = (currentTime - startDate) / 60 / 60;
            return startPrice - (daPriceSteps * currentHours);
        }
    }
    // ------------------------------------------------------------------------------------------------
    // ------------------------------------------------------------------------------------------------
    // - useful other tools
    function VIPcheck(address usrWallet) public view returns (bool) {
        return MerkleProof.verify(
                VIPMerkleProofArr,
                VIPMerkleRoot,
                keccak256(abi.encodePacked(usrWallet)));
    }
    // -
    function showVIPproof() public view returns (bytes32[] memory) {
        return VIPMerkleProofArr;
    }
    // -
    function giveRightNumber(uint256 myNumber) public pure returns (uint) {
        return myNumber % 10;
    }
    // -
    function showCurrentPrice() public view returns (uint256) {
        return calcPrice();
    }
    // -
    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseTokenURI = _newBaseURI;
    }
    // show current blockchain time
    function showBCtime() public view returns (uint256) {
        return block.timestamp;
    }
    // give complete tokenURI back, if base is set
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0 ? string(abi.encodePacked(currentBaseURI, giveRightNumber(tokenId).toString(), "/envo", tokenId.toString(), baseExtension)) : "";
    }

    //---------------------------------------------------------------------------------------
    //---------------------------------------------------------------------------------------
    // config functions, if needed for updating the settings by creator
    function setStartPrice(uint256 newStartPrice) public onlyOwner {
        startPrice = newStartPrice;
    }
    function setEndPrice(uint256 newEndPrice) public onlyOwner {
        endPrice = newEndPrice;
    }
    function setStartDate(uint256 newStartTimestamp) public onlyOwner {
        startDate = newStartTimestamp;
    }
    function setEndDate(uint256 newEndTimestamp) public onlyOwner {
        endDate = newEndTimestamp;
    }
    function setVIPDate(uint256 newVIPTimestamp) public onlyOwner {
        vipDate = newVIPTimestamp;
    }
    // -----------------------------------------------------------------
    function withdraw() public payable onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }
    // -----------------------------------------------------------------
    function changeOwner(address newOwner) public onlyOwner {
        contractCreator = newOwner;
    }
    // -----------------------------------------------------------------
}