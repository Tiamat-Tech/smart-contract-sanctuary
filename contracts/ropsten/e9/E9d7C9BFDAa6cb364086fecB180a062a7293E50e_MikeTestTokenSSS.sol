//SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
//import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

//  \ \   /                             \  |_) |         
//   \   / _ \  |   |   _` |  __| _ \  |\/ | | |  /  _ \ 
//      | (   | |   |  (   | |    __/  |   | |   <   __/ 
//     _|\___/ \__,_| \__,_|_|  \___| _|  _|_|_|\_\\___| 

/**
 * Request testnet LINK and ETH here: https://faucets.chain.link/
 * Find information on LINK Token Contracts and get the latest ETH and LINK faucets here: https://docs.chain.link/docs/link-token-contracts/
* https://docs.chain.link/docs/vrf-contracts/
* Network: Kovan
*/

contract MikeTestTokenSSS is ERC721Enumerable, Ownable { // , VRFConsumerBase
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    uint256 public PRICE = 0.1 ether;

    /* definice stavu:
    *   PRESALE     WHITELISTING
    *   0           x               opensale, limit = 10 + Y*wl + 10               
    *   0           x               opensale, limit = 10 + Y*wl + 10
    *   1           0               presale, limit = 10
    *   1           1               whitelisting, limit = 10 + Y*wl
    */

    // jestli je aktualne omezen pristup na presale
    bool private PRESALE = true;

    // jestli je v ramci presale zapnuty whitelisting
    bool private WHITELISTING = false;

    // uplne pozastaveni prodeje
    bool public PAUSE = true;

	// nastaveni jestli se ma ukazat obrazek nebo ne
	bool public REVEALED = false;

    // vychozi merkle
    bytes32 private MERKLE = 0x0000000000000000000000000000000000000000000000000000000000000000;

    // loterijni sood slouzici jako proof
    uint256 public LOTTERY_SEED;

    // pocet probehlych whitelistu, je to nejspis levnejsi nez map
    uint256 activeWhitelists = 0;

    // zamek aby se nedalo uri menit vic nez jednou
    //bool private URI_LOCK = false;

    // moje vychozi ipfs hidden uri, 4.0 zrusila _setBaseUri
    string public mikeUri;

    bytes32 internal vrfKeyHash;
    uint256 internal vrfFee;

	event Tstevent(bytes32 req);

    Counters.Counter private _tokenIdTracker;

    constructor(string memory baseURI)
    ERC721("MikeTestTokenSSS", "MIKE25SSS")
    //VRFConsumerBase(
    //    0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9, // VRF Coordinator
    //    0xa36085F69e2889c224210F603D836748e7dC0088  // LINK Token
    //)
    {
    //    vrfKeyHash = 0x6c3699283bda56ad74f6b855546325b68d482e983852a7a82979cc4807b641f4;
    //    vrfFee = 0.1 * 10 ** 18;
          
    	// nastav poprve adresu k hidden, tohle bude CID -1 pouze s falesnym obrazkem a json souborem
        // zbytek nahravas az pred reveal
        setBaseUri(baseURI);
    }

    /* VRF start */
	/*
    function getRandomSeed() public onlyOwner returns (bytes32 requestId) {
        require(LINK.balanceOf(address(this)) >= vrfFee, "Not enough LINK - fill contract with faucet.");
        return requestRandomness(vrfKeyHash, vrfFee);
    }

	// TEST
	//event EvTest(bytes32 reqst);

    // tohle se fakticky vraci zpet
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        LOTTERY_SEED = randomness;
    	emit Tstevent(requestId);
    }

    // TODO 
    //function withdrawLink() external {} - Implement a withdraw function to avoid locking your LINK in the contract
	*/

    /* VRF end */

    // obecne omezeni prodeje
    modifier saleIsOpen {

        // jestli uz se prodaly vsechny tokeny
        require(totalToken() <= 7777, "All tokens sold.");

        // pozastaveny prodej
        require(!PAUSE, "Sale is paused.");

        _;
    }
	
	// vylepsena metoda tokenuri, uz neni potreba baseuri, stejne tak uz neni potreba ale sequence id protoze losujeme random na konci
	function tokenURI(uint256 tokenId) public view virtual override(ERC721) returns (string memory) {
	
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory baseURI = _baseURI();
        string memory sequenceId;

        // pokud neni odhaleno, vracej -1 metadata
        if (REVEALED) {
            sequenceId = Strings.toString(tokenId);
        } else {
            sequenceId = "-1";
        }
        return string(abi.encodePacked(baseURI, sequenceId));
	}

  	function _baseURI() internal view virtual override returns (string memory) {
    	return mikeUri;
  	}

    // u kolikateho jsme
    function totalToken() public view returns (uint256) {
        return _tokenIdTracker.current();
    }

    // hromadny mint
    function mint(uint256 _howmany, bytes32[] calldata _proof) public payable saleIsOpen {

        // k obecnemu omezeni prodeje uz doslo v saleIsOpen

        // pocet tokenu
        uint256 total = totalToken();

        // over limity pro presale - 1. vlna s 10 tokeny, whitelistove vlny s 2 tokeny, sale s 2 tokeny
        if (PRESALE) {
            if (WHITELISTING) {
                require(_howmany <= 2, "Too many tokens to mint.");
            }

            else {
                require(_howmany <= 10, "Too many tokens to mint.");
            }
        }
        else {
            require(_howmany <= 10, "Too many tokens to mint.");
        }

        // kontrola dostupneho mnozstvi tokenu
        require(total + _howmany <= 7777, "Not enough tokens.");

        // kontrola mnozstvi v ramci omezeni na vsech whitelistech
        // presale = 10, whitelist = 2, opensale = 10 - ZRUSEN
        if (PRESALE) {
            require(balanceOf(msg.sender) + _howmany <= activeWhitelists * 2 + 10, "You reached limit for this sale phase. Wait for another one.");
        }

        // kontrola mnozstvi penez
        require(msg.value >= PRICE.mul(_howmany), "Not enough ETH to purchase tokens.");

        // overeni 
        address wallet = _msgSender();

        // pokud se jednalo presale whitelisting, kontroluj whitelist
        if (WHITELISTING) {
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(MerkleProof.verify(_proof, MERKLE, leaf), "Address is not whitelisted.");
        }

        for(uint8 i = 0; i < _howmany; i++){
            _mintAnElement(wallet);
        }
    }

    // single mint
    function _mintAnElement(address _to) private {
        _tokenIdTracker.increment();
        _safeMint(_to, _tokenIdTracker.current());
    }

    // tokeny co spadaji do penezenky nakupujiciho
    function walletOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);
        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    // nastav merkel
    function setTree(bytes32 _merkle) public onlyOwner{
        MERKLE = _merkle;
    }

    // nastav presale
    function setPresale(bool _presale) public onlyOwner{
        PRESALE = _presale;
    }

    // nastav whitelisting
    function setWhitelisting(bool _whitelisting) public onlyOwner{
        WHITELISTING = _whitelisting;
    }

    // raise whitelist pocet
    function raiseWhitelistCount() public onlyOwner{
        activeWhitelists += 1;
    }

    // nastav cenu
    function setPrice(uint256 _price) public onlyOwner{
        PRICE = _price;
    }

    // nastav reveal
    function setReveal(bool _reveal) public onlyOwner{
        REVEALED = _reveal;
    }

    // nastav pauzu
    function setPause(bool _pause) public onlyOwner{
        PAUSE = _pause;
    }

    // vyber penez
    function withdraw() public payable onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw.");
        (bool success,) = payable(msg.sender).call{value: balance}("");
        require(success, "Transfer failed.");
    }

    // nastav uri
    function setBaseUri(string memory _newUrl) public onlyOwner{
        //require(!URI_LOCK, "URI has been already changed one time.");        
        mikeUri = _newUrl;
        // nastav zamek aby bylo videt, ze uz se neda zmenit
    }   

}