// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

//@version 0.3.0

import "@openzeppelin/[email protected]/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/[email protected]/access/Ownable.sol";
import "@openzeppelin/[email protected]/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TemplateFinal is ERC721Enumerable, Ownable {

    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

   //Testnet addresses
    address tm0 = 0xDc3Ee5969611a47C4Bd4ef088a55E1ba61701827;   //0
    address tm1 = 0xA3BDaa505a72FC6B3e15E69Ac1577aEcd0E2736b;   //1
    address tm2 = 0x2F075618681D45458aE20E17ca3CCf1C797d6E1a;   //2

    string baseTokenURI;
    string constant PROVENANCE_HASH = "cc354b3fcacee8844dcc9861004da081f71df9567775b3f3a43412752752c0bf";

    uint private constant MAX_TOKENS = 10**3;                   //1000 Things
    uint private constant TXN_MINT_LIMIT = 20;                  //10 per txn
    uint private mintPrice = 20000000 gwei;                     //0.02 Ether
    bool private salePaused = true;

     constructor(string memory _baseTokenURI) ERC721("CryptoMutts", "CMUTT") {
      setBaseURI(_baseTokenURI);
    }

    function isSalePaused() public view returns (bool) {
      return salePaused;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function getPrice() public view returns (uint) {
        return mintPrice;
    }

    function setPrice(uint _newPrice) public onlyOwner {
        mintPrice = _newPrice;
    }

    function walletOfTokenOwner(address _tokenOwner) public view returns(uint[] memory) {
        uint tokenCount = balanceOf(_tokenOwner);

        uint[] memory tokensId = new uint[](tokenCount);
        for(uint i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(_tokenOwner, i);
        }
        return tokensId;
    }

    function getMaxTokens() public pure returns (uint) {
        return MAX_TOKENS;
    }

    function getProvenance() public pure returns (string memory) {
      return PROVENANCE_HASH;
    }

    function putANameOnIt() public pure returns (string memory) {
      return "Project by Kenny Schachter.";
    }

    function saleToggle() public onlyOwner {
        salePaused = !salePaused;
    }

    function publicMint(uint _amount) public payable {
        uint _supply = totalSupply();

        require( !salePaused,                       "Contract is paused." );
        require( _amount > 0,                       "Must mint at least 1 Thing");
        require( _supply + _amount <= MAX_TOKENS,   "Exceeds maximum token supply." );
        require( _amount <= TXN_MINT_LIMIT,         "Limited to 20 mints per transaction.");
        require( msg.value >= mintPrice * _amount,  "Ether sent is not correct for token price." );

        for(uint i; i < _amount; i++){
            _safeMint(msg.sender, _supply + i);
        }
    }

    function reservedMint(uint _amount) public payable {
        uint _supply = totalSupply();

        require( msg.sender == owner()
          || msg.sender == tm0
          || msg.sender == tm1
          //Assurance
          || msg.sender == tm2
        );

        require( _supply + _amount <= MAX_TOKENS,   "Exceeds maximum token supply.");

        for(uint i; i < _amount; i++){
            _safeMint(msg.sender, _supply + i);
        }
    }

    /**
    * Payout with withdrawal pattern
    */
    function withdraw() public payable onlyOwner {
        uint tenthCut = address(this).balance / 10;
        uint quarterCut = address(this).balance / 4;

        payable(tm0).send(tenthCut);                            //0
        payable(tm1).send(quarterCut);                          //1
        payable(msg.sender).transfer(address(this).balance);    //Remainder to owner
    }

    /**
     * Recover any ERC20 tokens sent to contract
     */
    function withdrawTokens(IERC20 _token) public onlyOwner {
        require(address(_token) != address(0));

        _token.transfer(msg.sender, _token.balanceOf(address(this)));
    }
}