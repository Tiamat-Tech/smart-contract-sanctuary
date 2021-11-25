//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract FortuneCookie is ERC721, Ownable{

    using Counters for Counters.Counter;
    Counters.Counter private _cookieIds;

    struct Cookie {
        uint256 id;
        string uri;
        string crackedUri;
        string fortune;
        bool cracked;

    }

    mapping(uint256=> Cookie) private cookies;
    
    constructor() ERC721("Fortune Cookie NF Token", "FOOKIENFT"){}

    function crackTheCookie(uint256 cookieId) public returns(string memory) {
        require(_exists(cookieId), "ERC721Metadata: URI query for nonexistent token");
        Cookie storage cookie = cookies[cookieId];
        cookie.cracked = true;
        return cookie.fortune;
    } 
    
    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function supply() public view returns(uint256){
        return _cookieIds.current();
    }

    function bakeCookie(string calldata uri_, string calldata crackedUri_, string calldata fortune_) public onlyOwner returns(uint256){
        
        _cookieIds.increment();

        Cookie memory cookie = Cookie({
            id: _cookieIds.current(),
            uri:uri_,
            crackedUri:crackedUri_,
            fortune:fortune_,
            cracked: false
        });

        cookies[cookie.id] = cookie;
        _mint(msg.sender, cookie.id);
        return cookie.id;
    }
    
    function tokenURI(uint256 cookieId) public view virtual override returns(string memory) {
        require(_exists(cookieId), "ERC721Metadata: URI query for nonexistent token");

        Cookie memory cookie = cookies[cookieId];
        if(cookie.cracked){ 
            return cookie.crackedUri;
        }
        else return cookie.uri;
    }
}