pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract SimpleToucan is ERC721Enumerable, Ownable {

    using Strings for uint256;
    string _baseTokenURI;
    //TOUPACAPLYSE NOW
    uint256 private _price = 0.022 ether;
    bool public _paused = true;
    bool public _paused_premint = true;

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI
    ) ERC721(name,symbol)  {
        setBaseURI(baseURI);
    }

    function freebird(uint256 num) public payable {
        uint256 supply = totalSupply();
        require( !_paused,                      "Minting paused" );
        require( num < 30,                      "You can breed a maximum of 29 Toucans" );
        require( supply + num < 10002,          "Exceeds maximum Toucan supply" );
        require( msg.value >= _price * num,     "Eth sent is not correct" );
        for(uint256 i; i < num; i++){
            _safeMint( msg.sender, supply + i );
        }
    }

    function freebirdPremint(uint256 num) public payable {
        uint256 supply = totalSupply();
        require( !_paused_premint,               "Minting paused" );
        require( num < 3,                       "You can breed a maximum of 2 TravelToucans" );
        require( supply + num < 71,             "Exceeds maximum TravelToucans preminting supply" );
        require( msg.value >= _price * num,     "Eth sent is not correct" );
        for(uint256 i; i < num; i++){
            _safeMint( msg.sender, supply + i );
        }
    }

    function walletOfOwner(address _owner) public view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    function setPrice(uint256 _newPrice) public onlyOwner() {
        _price = _newPrice;
    }

    function getPrice() public view returns (uint256){
        return _price;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function pause(bool val) public onlyOwner {
        _paused = val;
    }

    function pause_premint(bool val) public onlyOwner {
        _paused_premint = val;
    }

    function giveAway(address _to, uint256 _amount) external onlyOwner() {
        uint256 supply = totalSupply();
        require( supply + _amount < 10002,  "Exceeds maximum TravelToucans supply" );
        for(uint256 i; i < _amount; i++){
            _safeMint( _to, supply + i );
        }
    }
}