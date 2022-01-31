// SPDX-License-Identifier: MIT
//
//
// Complete DApp created by Corecis 
//
// Whatsapp +923178866631, website : http://corecis.org
// Hi. If you have any questions or comments in this smart contract please let me know at:
//
//

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
 
/*  
         _____ _               _          
        /  __ \ |             | |         
        | /  \/ |__   ___  ___| | ___   _ 
        | |   | '_ \ / _ \/ _ \ |/ / | | |
        | \__/\ | | |  __/  __/   <| |_| |
        \____/_| |_|\___|\___|_|\_\\__,  |
                                    __/  |
                                    |___/ 

/                                    _____       _     
                                    /  __ \     | |    
                                    | /  \/_   _| |__  
                                    | |   | | | | '_ \ 
                                    | \__/\ |_| | |_)|
                                    \____/\__,_|_.__/ 
                                                    

/                                                _____ _       _     
                                                /  __ \ |     | |    
                                                | /  \/ |_   _| |__  
                                                | |   | | | | | '_ \ 
                                                | \__/\ | |_| | |_)|
                                                \____/_|\__,_|_.__/ 



*/

contract CheekyCubClub is ERC721("Cheeky Cub Club", "CCC") {
    IERC721 public Lion;
    IERC721 public Cougar;
    string public baseURI;
    bool public isSaleActive;
    uint256 public circulatingSupply;
    address public owner = msg.sender;
    uint256 public itemPrice = 0.07 ether;
    uint256 public itemPricePresale = 0.07 ether;
    uint256 public constant totalSupply = 8000;
    address internal lion;
    address internal cougar;
    // address public marketing = 0xc66C9f79AAa0c8E6F3d12C4eFc7D7FE7c1f8B89C;
    // address public dev = 0xc66C9f79AAa0c8E6F3d12C4eFc7D7FE7c1f8B89C;

    address public marketing;
    address public dev;

    bool public isAllowListActive;
    uint256 public allowListMaxMint = 2;
    mapping(address => bool) public onAllowList;
    mapping(address => uint256) public allowListClaimedBy;
    mapping(uint => uint) public BreededLion;
    mapping(uint => uint) public BreededCougar;
    constructor(address _lion, address _cougar, address _market, address _dev, address _owner) {
        Lion = IERC721(_lion);
        Cougar = IERC721(_cougar);
        marketing = _market;
        dev = _dev;
        owner = _owner;
    }

    ////////////////////
    //   ALLOWLIST    //
    ////////////////////
    // ✅ done used
    function addToAllowList(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++)
            onAllowList[addresses[i]] = true;
    }

    function removeFromAllowList(address[] calldata addresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < addresses.length; i++)
            onAllowList[addresses[i]] = false;
    }

    /////////////////////////////////
    //    breeding conditioner     //
    /////////////////////////////////
    // ✅ done used
    function breedingCondition(uint _howMany, uint _Lion, uint _Cougar)internal{
        require(Lion.ownerOf(_Lion) == msg.sender, "your are not owner of this Lion");
        require(Cougar.ownerOf(_Cougar) == msg.sender, "your are not owner of this Cougar");
        require(breededLion(_Lion) != true && breededCougar(_Cougar) != true, "already Breeded");
        require(_howMany <= Lion.balanceOf(msg.sender), "You dont have enough Lions");
        require(_howMany <= Cougar.balanceOf(msg.sender), "You dont have enough Cougars");
        BreededLion[_Lion] = _Cougar;
        BreededCougar[_Cougar] =_Lion;
    }
    // ✅ done used
    function checkAvailabilityOfLion(uint _Lion) public view returns(string memory message){
        if(breededLion(_Lion) == true){
            return message = "not availability";
        }else{
            return message = "available";
        }
    }
    // ✅ done used
    function checkAvailabilityOfCougar(uint _Cougar) public view returns(string memory message){
        if(breededCougar(_Cougar) == true){
            return message = "not availability";
        }else{
            return message = "available";
        }
    }
    // ✅ done used
    function breededLion(uint _Lion) public view returns(bool breeded){
            if(BreededLion[_Lion] > 0){
                return breeded = true;
            }
    }
    // ✅ done used
    function breededCougar(uint _Cougar) public view returns(bool breeded){
            if(BreededCougar[_Cougar] > 0){
                return breeded = true;
            }
    }

    ////////////////////
    //    PRESALE     //
    ////////////////////

    // Purchase presale NFTs
    function breedPresaleCub(uint256 _howMany, uint _Lion, uint _Cougar)
        external
        payable
        tokensAvailable(_howMany)
    {
        require(isAllowListActive, "Allowlist is not active");
        require(onAllowList[msg.sender], "You are not in allowlist");
        require(
            allowListClaimedBy[msg.sender] + _howMany <= allowListMaxMint,
            "Purchase exceeds max allowed"
        );
        require(
            msg.value >= _howMany * itemPricePresale,
            "Try to send more ETH"
        );
        breedingCondition(_howMany,_Lion,_Cougar);
        allowListClaimedBy[msg.sender] += _howMany;
        _mint(msg.sender, ++circulatingSupply);
    }

    ////////////////////
    //  PUBLIC SALE   //
    ////////////////////

    // Purchase NFT
    
    // ✅ done used
    function breedCub(uint256 _howMany, uint _Lion, uint _Cougar)
        external
        payable
        tokensAvailable(_howMany)
    {
        require(
            isSaleActive && circulatingSupply <= 8000,
            "Sale is not active"
        );
        breedingCondition(_howMany,_Lion,_Cougar);
        _mint(msg.sender, ++circulatingSupply);
    }

    //////////////////////////
    // Only Owner Methods   //
    //////////////////////////
    
    // ✅ done used
    function stopSale() external onlyOwner {
        isSaleActive = false;
    }
    // ✅ done used
    function startSale() external onlyOwner {
        isSaleActive = true;
    }

    // Owner can withdraw ETH from here
    function withdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;

        uint256 _30_percent = (balance * 0.30 ether) / 1 ether;
        uint256 _68_percent = (balance * 0.68 ether) / 1 ether;
        uint256 _2_percent = (balance * 0.02 ether) / 1 ether;

        payable(msg.sender).transfer(_68_percent);
        payable(marketing).transfer(_30_percent);
        payable(dev).transfer(_2_percent);
    }

    // set limit of allowlist
    // ✅ done used
    function setAllowListMaxMint(uint256 _allowListMaxMint) external onlyOwner {
        allowListMaxMint = _allowListMaxMint;
    }

    // Change price in case of ETH price changes too much
    // ✅ done used
    function setPrice(uint256 _newPrice) external onlyOwner {
        itemPrice = _newPrice;
    }

    // Change presale price in case of ETH price changes too much
    // ✅ done used
    function setPricePresale(uint256 _itemPricePresale) external onlyOwner {
        itemPricePresale = _itemPricePresale;
    }

    // Hide identity or show identity from here
    // ✅ done used
    function setBaseURI(string memory __baseURI) external onlyOwner {
        baseURI = __baseURI;
    }
    // ✅ done used
    function setIsAllowListActive(bool _isAllowListActive) external onlyOwner {
        isAllowListActive = _isAllowListActive;
    }

    ///////////////////
    // Query Method  //
    ///////////////////
    
    // ✅ done used
    function tokensRemaining() public view returns (uint256) {
        return totalSupply - circulatingSupply;
    }
    
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    ///////////////////
    //   Modifiers   //
    ///////////////////

    // ✅ done used
    modifier tokensAvailable(uint256 _howMany) {
        require(_howMany <= tokensRemaining(), "Try minting less tokens");
        _;
    }

    // ✅ done used
    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }
}