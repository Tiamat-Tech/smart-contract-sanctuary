pragma solidity >=0.7.3;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyCryptoLions is ERC721, Ownable {

    struct Charactor {
        string name;
        uint16 level;
    }

    Charactor[] public charactors;

    uint256 public MAX_APES;
    uint256 public REVEAL_TIMESTAMP;


    constructor(string memory name, string memory symbol, uint256 maxNftSupply, uint256 saleStart)
        ERC721(name, symbol)
    {
        MAX_APES = maxNftSupply;
        REVEAL_TIMESTAMP = saleStart + (86400 * 9);
    }

    function mint(string memory name, address account) public onlyOwner {
        uint256 cardid = charactors.length;
        charactors.push(Charactor(name, 1));
        _mint(account, cardid);
    }

    function mintFree(string memory name, uint16 level) public {
        uint256 cardid = charactors.length;
        charactors.push(Charactor(name, level));
        _mint(_msgSender(), cardid);
    }


    /**
     * DM Gargamel in Discord that you're standing right behind him.
     */
    function setRevealTimestamp(uint256 revealTimeStamp) public onlyOwner {
        REVEAL_TIMESTAMP = revealTimeStamp;
    } 

    function getMaxApes() public view returns (uint256){
        return MAX_APES;
    } 

    function getRevealTimeStamp() public view returns (uint256){
        return REVEAL_TIMESTAMP;
    } 


}