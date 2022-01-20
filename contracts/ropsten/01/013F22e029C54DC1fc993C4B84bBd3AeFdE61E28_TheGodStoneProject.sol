//Contract based on [https://docs.openzeppelin.com/contracts/3.x/erc721](https://docs.openzeppelin.com/contracts/3.x/erc721)
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

// Library Import
import "contracts/StructDeclaration.sol";

contract TheGodStoneProject is ERC721, ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;
    
    uint256 public maxMintPerTx = 3;
    //int256 public commonStonePrice = 10000000000000000; //0.01 ETH
    uint256 public commonStonePrice = 10000000000000000; //0.01 ETH

    bool public saleActive = false;
    bool public reserveActive = false;
    string public _setBaseURI;
    string public baseExtension = ".json";

    /**
    Mapping of ALL stone classes
    mapping used for assigning tokenId and storing stone properties 
    */
    mapping (uint256 => StoneClass) public mapStoneClass;


    constructor() ERC721("The God Stone Project", "TGSP") { 
        // Initialise <mapStoneClass>
        StoneClass storage _commonClass = mapStoneClass[1];
        _commonClass.name = "CommonStone";
        _commonClass.maxSupply = 1296;
        _commonClass.stonesRequired = 0;
        _commonClass.upperIndex = 1296;
        _commonClass.classIndex = 1;

        StoneClass storage _yellowClass = mapStoneClass[2];
        _yellowClass.name = "YellowStone";
        _yellowClass.maxSupply = 324;
        _yellowClass.stonesRequired = 4;
        _yellowClass.upperIndex = 1620;
        _yellowClass.classIndex = 2;

        StoneClass storage _OrangeClass = mapStoneClass[3];
        _OrangeClass.name = "OrangeStone";
        _OrangeClass.maxSupply = 108;
        _OrangeClass.stonesRequired = 3;
        _OrangeClass.upperIndex = 1728;
        _OrangeClass.classIndex = 3;


        StoneClass storage _AquaClass = mapStoneClass[4];
        _AquaClass.name = "AquaStone";
        _AquaClass.maxSupply = 36;
        _AquaClass.stonesRequired = 3;
        _AquaClass.upperIndex = 1764;
        _AquaClass.classIndex = 4;

        StoneClass storage _GreenClass = mapStoneClass[5];
        _GreenClass.name = "GreenStone";
        _GreenClass.maxSupply = 12;
        _GreenClass.stonesRequired = 3;
        _GreenClass.upperIndex = 1776;
        _GreenClass.classIndex = 5;

        StoneClass storage _RedClass = mapStoneClass[6];
        _RedClass.name = "RedStone";
        _RedClass.maxSupply = 4;
        _RedClass.stonesRequired = 3;
        _RedClass.upperIndex = 1780;
        _RedClass.classIndex = 6;

        StoneClass storage _PurpleClass = mapStoneClass[7];
        _PurpleClass.name = "PurpleStone";
        _PurpleClass.maxSupply = 2;
        _PurpleClass.stonesRequired = 3;
        _PurpleClass.upperIndex = 1782;
        _PurpleClass.classIndex = 7;

        StoneClass storage _TheGodStoneClass = mapStoneClass[8];
        _TheGodStoneClass.name = "TheGodStone";
        _TheGodStoneClass.maxSupply = 1;
        _TheGodStoneClass.stonesRequired = 2;
        _TheGodStoneClass.upperIndex = 1783;
        _TheGodStoneClass.classIndex = 8;
    }

    // RETURNS THE TOTAL CURRENT SUPPLY FOR A PARTICULAR CLASS OF STONES
    function getCurrentStoneSupply(uint256 _indx) public view returns(uint256){
        return mapStoneClass[_indx].arrayOfStones.length;
    }

    // GET PROPERTY OF A STONE BY CLASS INDEX AND TOKENID
    function getStoneProperty(uint256 stoneClassIndex, uint256 tokenId) public view returns (Stone memory stone){
        Stone[] memory stones = mapStoneClass[stoneClassIndex].arrayOfStones;
        for (uint256 i = 0; i < stones.length; i ++) {
            if (tokenId == stones[i].stoneId){
                return stones[i];
            }
        }
    }

    // RETRIEVE BASEURI
    function _baseURI() internal view virtual override returns (string memory) {
        return _setBaseURI;
    }

    // SET BASEURI
    function setBaseURI(string memory baseURI) public onlyOwner {   
        _setBaseURI = baseURI;
    }

    // SET BASEEXTENSION
    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), baseExtension)) : "";
    }

    // MINT COMMON GODSTONE FOR PUBLIC
    function mintCommonStone(uint256 amount) external payable {
        require( saleActive, "Sale is not yet active." );
        require( amount > 0, "Amount must be greater than 0." );
        require( amount <= maxMintPerTx, "Only 3 Common Stones can be minted per transaction." );
        require( msg.value >= commonStonePrice.mul(amount), "The amount of ether sent was incorrect." );

        uint classIndex = 1; // index for Common Stone (1)
        (uint256 maxSupply, uint256 currentSupply) = getSupplyInfoForStoneType(classIndex); 
        require( currentSupply.add(amount) <= maxSupply, "Maximum number of stones reached" );

        for (uint256 i = 1; i <= amount; i++) {
            Stone[] storage commonStones = mapStoneClass[classIndex].arrayOfStones;
            uint256 newTokenId = commonStones.length;
            if (newTokenId <= mapStoneClass[classIndex].upperIndex) {
                _safeMint(msg.sender, newTokenId + 1);
                Stone memory newCommonStone = Stone(newTokenId + 1, "CommonStone", false);
                commonStones.push(newCommonStone);
            }
        }
    }

    /**
    MINT ALL STONES ABOVE COMMON STONE
    stoneClassIndex:
    YellowStone (1), OrangeStone (2), AquaStone (3), GreenStone (4), RedStone (5), PurpleStone (6), TheGodStone (7)
    */
    function mintNextStone(uint256 amount, uint256 stoneClassIndex) external payable {
        require( saleActive, "Sale is not yet active." );
        require( amount == 1, "Only 1 Stone can be minted per transaction." );
        require( msg.value == 0, "The amount of ether sent should be 0." );
        
        (bool canMint, uint[] memory requiredStones) = ownerCanMintStone(msg.sender, stoneClassIndex);
        Stone[] storage _stones = mapStoneClass[stoneClassIndex].arrayOfStones;

        require(canMint, "You do not have the required type of stones");
        require((_stones.length.add(amount)) <= mapStoneClass[stoneClassIndex].maxSupply, "There are no more stones");

        uint256 newTokenId; // tokenId for the minted stone
        if (_stones.length == 0) {
            newTokenId = mapStoneClass[stoneClassIndex].upperIndex + 1;
        } else{
            newTokenId = mapStoneClass[stoneClassIndex].upperIndex + _stones.length + 1;
        }
        // if (_stones.length == 0) {
        //     newTokenId = mapStoneClass[stoneClassIndex - 1].upperIndex + 1;
        // } else{
        //     newTokenId = mapStoneClass[stoneClassIndex - 1].upperIndex + _stones.length + 1;
        // }

        _safeMint(msg.sender, newTokenId);
        Stone memory newYellowStone = Stone(newTokenId, mapStoneClass[stoneClassIndex].name, false);
        _stones.push(newYellowStone);
        setStonePropertyToUsed( stoneClassIndex - 1, requiredStones); 
        
    }

    /**
    GET MAX SUPPLY FOR STONE TYPE & CURRENT MINTED SUPPLY
    Returns
    Max supply (uint256)
    Current minted supply (uint256)
    */
    function getSupplyInfoForStoneType(uint256 _index) public view returns (uint256, uint256) {
        return (mapStoneClass[_index].maxSupply, mapStoneClass[_index].arrayOfStones.length);
    }

    /**
    INPUT:
    stoneClassIndex: class index of stone (e.g for YellowStone index is 0)
    requiredStones: array of tokenId
    */
    function setStonePropertyToUsed( uint256 stoneClassIndex , uint256[] memory usedStones) internal {
        Stone[] storage stones = mapStoneClass[stoneClassIndex].arrayOfStones;
            for (uint256 i = 0; i < usedStones.length; i++) {
                for (uint256 x = 0; x < stones.length; x++) {
                    if (usedStones[i] == stones[x].stoneId) {
                        stones[x].isUsed = true;
                    }
                }
            }  
    }
    
    // SET COMMON STONE MINT PRICE
    function setCommonStonePrice(uint256 price) public onlyOwner {
        commonStonePrice = price;
    }

    // TOGGLE SALE STATE ON/OFF
    function toggleSale() public onlyOwner {
        saleActive = !saleActive;
    }

    // TOGGLE RESERVE STATE ON/OFF
    function toggleReserve() public onlyOwner {
        reserveActive = !reserveActive;
    }

    // WITHDRAW FUNDS FROM SMART CONTRACT
    function withdraw() public payable onlyOwner {
        uint256 balance = address(this).balance;
        payable(owner()).transfer(balance);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // GET reserveActive STATE
    function getResearcState() public view onlyOwner returns (bool) {
        return reserveActive;
    }


    // View the tokenId by index from array of all minted stones 
    function viewTokenIdByIndex(uint256 index) public view returns (uint256){
        return tokenByIndex(index);
    }

    // /**
    // Get all tokenIDs from 'owner' for this contract
    // TESTED-WORKS!
    // */
    function getTokenIdsOfOwner(address _address) public view returns (uint256[] memory){
        uint256 ownerTokenBalance = balanceOf(_address);
        uint256[] memory ownerTokenIDs = new uint[](ownerTokenBalance);
        
        for(uint256 i = 0; i < ownerTokenBalance; i++){
            ownerTokenIDs[i] = tokenOfOwnerByIndex(_address, i);
        }
        return ownerTokenIDs;
    }
    
    /** 
    USER CAN ONLY MINT THE NEXT STONE IF THEY OWN THE REQUIRED NUMBER OF PREVIOUS STONES
    1. Determine if user owns the required number of stones to mint the next stone
    2. Determine if each of these stones have already been 'used' (to mint the next stone)
    If Stone.isUsed = true, this stine cannot be used to mint the next stone up.

    Input:
    < arrayMintedStoneType > array of PREDECESSOR stones (all)
    < numOfRequiredStones > number of required redecessor stones to mint the next stone
    e.g User wants to mint YellowStone:
        < arrayMintedStoneType > would be the array of CommonStones
        < numOfRequiredStones > the number of CommonStones required to mint a YellowStone

    Returns:
    Owner has required number of stones to mint the next stone (bool)
    Exact number of required stones (that have NOT been 'used') - array of tokenId

    Since the returning array of tokenId is fixed, its length may be greater than the number of required tokenId that have not been 'used'.
    The extra elements are represented as '0'.
    If the user possesses more than the required number of stones, the excess will not be included in the returning array. 
    */
    function ownerHasRequiredStones(address _addr, Stone[] memory arrayMintedStoneType, uint256 numOfRequiredStones) internal view returns (bool, uint[] memory){

        uint[] memory allOwnedStoneIds = getTokenIdsOfOwner(_addr);
        // Array of tokenIds
        uint[] memory requiredStones = new uint256[](allOwnedStoneIds.length);

        // Count the number of Common Stone tokenIds 
        uint256 count = 0;
        
        for (uint256 i = 0; i < allOwnedStoneIds.length; i ++){
            for ( uint256 x = 0; x < arrayMintedStoneType.length; x ++) {
                if ( allOwnedStoneIds[i] == arrayMintedStoneType[x].stoneId && arrayMintedStoneType[x].isUsed == false) {
                    
                    if (count < numOfRequiredStones){
                        // Only add to requiredStones THE EXACT number of required stones
                        requiredStones[i] = arrayMintedStoneType[x].stoneId;
                        count = count + 1;
                    }
                }
            }
        }
        return count >= numOfRequiredStones ? (true, requiredStones) : (false, requiredStones);
    }


    /**
    User enters the index for the class of stone that they want to mint
    e.g to mint a YellowStone, enter < 1 >

    Returns:
    Owner has required number of stones to mint the next stone (bool)
    Exact number of required stones (that have NOT been 'used') - array of tokenId
    */
    function ownerCanMintStone(address _addr, uint256 stoneClassIndex) public view returns (bool, uint[] memory) {
        return ownerHasRequiredStones(_addr, mapStoneClass[stoneClassIndex - 1].arrayOfStones, mapStoneClass[stoneClassIndex].stonesRequired);
    }


}