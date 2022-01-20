//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract mintNFT is ERC721 {
    struct catData {
        string catName;
        string yourName;
        string comment;
        string favorite;
        uint32 metDay;
        uint32 leftDay;
        address owner; //컬러정보 불러오기 위함 
        color catColor;
    }

    struct color {
        uint8 R;
        uint8 G; 
        uint8 B;
        bool set;
    }

    //_owners : tokenID -> owner address ,   <cat 토큰 -> owner>
    //_balance : owner -> token count,       <onwer -> cat's number>
    //token ID for mapping
    uint256 public tokenID;
    //color 
    color currentColor;
    bytes32 colorHex;
    //색 설정시 사용
    bool fullFlag;
    bool turnFlag;

    //mapping from token ID to cat's data    <cat 토큰 -> cataData>
    mapping (uint256 => catData) private _catData;
    //mapping from owner to owner's color    <owner -> color>
    mapping (address => color) private _myColor;
    //mapping from owner to owner's color    <color -> owner>
    mapping (bytes32 => address) private _whoColor;


    //initialize
    constructor(uint8 R, uint8 G, uint8 B, bool full, bool turn) ERC721("elyCat", "EC") {
        tokenID = 0;
        currentColor.R = R;
        currentColor.G = G;  
        currentColor.B = B;
        fullFlag = full;
        turnFlag = turn;
    }
            

    function _setColorInfo() private {

        colorHex = keccak256(abi.encode(currentColor.R , currentColor.G , currentColor.B));  
        currentColor.set = true;
        _myColor[msg.sender] = currentColor; 
        _whoColor[colorHex] = msg.sender;

        if(turnFlag == true){
            currentColor.R--;
            currentColor.G = 255;
            currentColor.B = 255;
            turnFlag = false;
        }
        else {
            if(currentColor.G == currentColor.B){
                currentColor.G--;
            }
            else {
                currentColor.B--;
                if(currentColor.B == 0){
                    turnFlag = true;
                }
                if(currentColor.B == 0 && currentColor.R == 0){
                    fullFlag = true;
                }
            }
        }
    }


    function mint(
        string memory catName,
        string memory yourName,
        string memory comment,
        string memory favorite,
        uint32 metDay,
        uint32 leftDay
    ) public {
        require(fullFlag == false, "The planet's stars were full");
        if(_myColor[msg.sender].set == false){
            _setColorInfo();
        }
        _catData[tokenID] = catData(catName, yourName, comment, favorite, metDay, leftDay, msg.sender, currentColor);
        _mint(msg.sender,tokenID);
        tokenID++;
        console.log("fullFalg : ",fullFlag);
        console.log("turnFalg : ",turnFlag);
    }

    

    // return functions

    function getColor() public view returns(color memory){
        //console.log(currentColor);
        return currentColor;
    }

    function catDataOf (uint256 _tokenID) public view returns (catData memory) {
        require(tokenID >= 0, "This is not valid token");
        (_catData[_tokenID]);
        return _catData[_tokenID];
    }
    function myColorOf (address _owner) public view returns (color memory) {
        require(_owner != address(0), "This is invalid address");
        return _myColor[_owner];
    }

    function whoColorOf (bytes32 _color) public view returns (address) {
        return _whoColor[_color];
    }

    function getOwner() public view returns (address) {
        console.log(msg.sender);
        return msg.sender;
    }

    function getTokenID() public view returns (uint256) {
        return tokenID - 1;
    }
}