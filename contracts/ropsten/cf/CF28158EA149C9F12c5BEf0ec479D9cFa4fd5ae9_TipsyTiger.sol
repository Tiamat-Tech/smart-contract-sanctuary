// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';


contract TipsyTiger is ERC721Enumerable, Ownable {

    using SafeMath for uint256; //new

    string public TIPSYTIGER_PROVENANCE = ""; //new
    string _baseTokenURI;
    uint256 private _reserved = 100;
    uint256 private _price = 0.07 ether;
    bool public _paused = true;
    mapping(address => bool) public whitelisted; //new

    // team addresses
    address t1 = 0x21A874EAcCC2195db7d390aC715c47efdA96B6ee;
    address t2 = 0xa89e2B274A39258ADF28182EE2e39da53B7bD4cB;

    constructor(string memory baseURI) ERC721("Tipsy Tiger Club", "TIPSY")  {
        setBaseURI(baseURI);

        // team gets the first 4 tigers
        _safeMint( t1, 0);
        _safeMint( t2, 1);
    
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }


    function mintTiger(uint256 num) public payable {
        uint256 supply = totalSupply();
        require( !_paused, "Sale paused" );
        require( num < 21, "You can mint a maximum of 20 Tigers" );
        require( supply + num < 10000 - _reserved, "Exceeds maximum supply" );
        require( msg.value >= _price * num, "Ether sent is not correct" );

        for(uint256 i; i < num; i++){
            _safeMint( msg.sender, supply + i );
        }
    }

    // what does this function do??
    function walletOfOwner(address _owner) public view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

      // reserve some tigers aside
    function giveAway(address _to, uint256 _amount) external onlyOwner() {
        require( _amount <= _reserved, "Exceeds reserved Tiger supply" );

        uint256 supply = totalSupply();
        for(uint256 i; i < _amount; i++){
            _safeMint( _to, supply + i );
        }

        _reserved -= _amount;
    }

    // Set new mint price
    function setPrice(uint256 _newPrice) public onlyOwner() {
        _price = _newPrice;
    }

    /*     
    * Set provenance once it's calculated
    */
    function setProvenanceHash(string memory provenanceHash) public onlyOwner {
        TIPSYTIGER_PROVENANCE = provenanceHash;
    }

    // Internal
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function getPrice() public view returns (uint256){
        return _price;
    }

    // start or pause sale
    function pause(bool val) public onlyOwner {
        _paused = val;
    }

    // add address from white list - new
    function whitelistUser(address _user) public onlyOwner {
    whitelisted[_user] = true;
    }
    
    // remove address from whitelist - new  
    function removeWhitelistUser(address _user) public onlyOwner {
    whitelisted[_user] = false;
    }


}