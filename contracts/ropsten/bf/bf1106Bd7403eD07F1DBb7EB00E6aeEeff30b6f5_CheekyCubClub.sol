// Hi. If you have any questions or comments in this smart contract please let me know at:
// Whatsapp +923178866631, website : http://corecis.org
//
//
// Complete DApp created by Corecis 
//
//
//
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

/*
        _____ _               _          
        /  __ \ |             | |         
        | /  \/ |__   ___  ___| | ___   _ 
        | |   | '_ \ / _ \/ _ \ |/ / | | |
        | \__/\ | | |  __/  __/   <| |_| |
        \____/_| |_|\___|\___|_|\_\\__, |
                                    __/ |
                                    |___/ 

/                                    _____       _     
                                    /  __ \     | |    
                                    | /  \/_   _| |__  
                                    | |   | | | | '_ \ 
                                    | \__/\ |_| | |_) |
                                    \____/\__,_|_.__/ 
                                                    

/                                                _____ _       _     
                                                /  __ \ |     | |    
                                                | /  \/ |_   _| |__  
                                                | |   | | | | | '_ \ 
                                                | \__/\ | |_| | |_) |
                                                \____/_|\__,_|_.__/ 



*/

contract CheekyCubClub is ERC721("Cheeky Cub Club", "CCC") {
    IERC721 public Lion;
    IERC721 public Cougar;
    string public baseURI;
    bool public isSaleActive;
    uint256 public circulatingSupply;
    address public owner = msg.sender;
    uint256 public constant totalSupply = 10333;
    mapping(uint => uint) public BreededLion;
    mapping(uint => uint) public BreededCougar;
    constructor(address _lion, address _cougar, address _owner) {
        Lion = IERC721(_lion);
        Cougar = IERC721(_cougar);
        owner = _owner;
    }

    /////////////////////////////////
    //    breeding conditioner     //
    /////////////////////////////////
    // ✅ done Checked
    function breedingCondition(uint _howMany, uint _Lion, uint _Cougar)internal{
        require(Lion.ownerOf(_Lion) == msg.sender, "your are not owner of this Lion");
        require(Cougar.ownerOf(_Cougar) == msg.sender, "your are not owner of this Cougar");
        require(breededLion(_Lion) != true && breededCougar(_Cougar) != true, "already Breeded");
        require(_howMany <= Lion.balanceOf(msg.sender), "You dont have enough Lions");
        require(_howMany <= Cougar.balanceOf(msg.sender), "You dont have enough Cougars");
        BreededLion[_Lion] = _Cougar;
        BreededCougar[_Cougar] =_Lion;
    }
    // ✅ done Checked
    function checkAvailabilityOfLion(uint _Lion) public view returns(string memory message){
        if(breededLion(_Lion) == true){
            return message = "not availability";
        }else{
            return message = "available";
        }
    }
    // ✅ done Checked
    function checkAvailabilityOfCougar(uint _Cougar) public view returns(string memory message){
        if(breededCougar(_Cougar) == true){
            return message = "not availability";
        }else{
            return message = "available";
        }
    }
    // ✅ done Checked
    function breededLion(uint _Lion) public view returns(bool breeded){
            if(BreededLion[_Lion] > 0){
                return breeded = true;
            }
    }
    // ✅ done Checked
    function breededCougar(uint _Cougar) public view returns(bool breeded){
            if(BreededCougar[_Cougar] > 0){
                return breeded = true;
            }
    }

    ////////////////////
    //  PUBLIC SALE   //
    ////////////////////

    // Purchase NFT

    // ✅ done Checked
    function breedCub(uint256 _howMany, uint _Lion, uint _Cougar)
        external
        tokensAvailable(_howMany)
    {
        require(
            isSaleActive && circulatingSupply <= 10333,
            "Sale is not active"
        );
        breedingCondition(_howMany,_Lion,_Cougar);
        _mint(msg.sender, ++circulatingSupply);
    }

    //////////////////////////
    // Only Owner Methods   //
    //////////////////////////
    
    // ✅ done Checked
    function stopSale() external onlyOwner {
        isSaleActive = false;
    }
    // ✅ done Checked
    function startSale() external onlyOwner {
        isSaleActive = true;
    }


    // Hide identity or show identity from here
    // ✅ done Checked
    function setBaseURI(string memory __baseURI) external onlyOwner {
        baseURI = __baseURI;
    }

    ///////////////////
    // Query Method  //
    ///////////////////
    
    // ✅ done Checked
    function tokensRemaining() public view returns (uint256) {
        return totalSupply - circulatingSupply;
    }
    
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    ///////////////////
    //   Modifiers   //
    ///////////////////

    // ✅ done Checked
    modifier tokensAvailable(uint256 _howMany) {
        require(_howMany <= tokensRemaining(), "Try minting less tokens");
        _;
    }

    // ✅ done Checked
    modifier onlyOwner() {
        require(owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }
}