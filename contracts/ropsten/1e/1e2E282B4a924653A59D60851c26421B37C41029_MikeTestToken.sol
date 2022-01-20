//SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

//  \ \   /                             \  |_) |         
//   \   / _ \  |   |   _` |  __| _ \  |\/ | | |  /  _ \ 
//      | (   | |   |  (   | |    __/  |   | |   <   __/ 
//     _|\___/ \__,_| \__,_|_|  \___| _|  _|_|_|\_\\___| 


contract MikeTestToken is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    uint256 public constant COUNT = 7777;
    uint256 public PRICE = 0.1 ether;

    // omezeni poctu tokenu na majitele
    uint256 public constant MAX_PER_WALLET = 77;

    // omezeni na jeden mint v presale
    uint256 public constant MAX_PER_MINT_PRESALE = 2;

    // omezeni na jeden mint v normalnim prodeji
    uint256 public constant MAX_PER_MINT_SALE = 10;

    // jestli je aktualne omezen pristup na presale
    bool private PRESALE = true;

    // uplne pozastaveni prodeje
    bool private PAUSE = true;

	// nastaveni jestli se ma ukazat obrazek nebo ne
	bool private REVEALED = false;

	// defaultni adresa ipfs - falesna adresa odkazujici na prazdnej soubor jsonu, json ani neni potreba
	string private hiddenUrl = "ipfs://ipfs.io/ipfs/xxxxxxxxxxxxxxxxxxxxxxxxxx/hidden.json";

    // vychozi merkle
    bytes32 private MERKLE = 0x0000000000000000000000000000000000000000000000000000000000000000;

    Counters.Counter private _tokenIdTracker;

	// tohle je: ipfs://xxxxxxxxx/ bez tech souboru na konci
    string public baseTokenURI;

    constructor(string memory baseURI) ERC721("MikeTestToken", "MIKE25"){
    
    	// nastav poprve adresu k hidden obrazku a jsonu, tj bez toho posledniho prvku
        setBaseURI(baseURI);
    }

    // obecne omezeni prodeje
    modifier saleIsOpen {

        // jestli uz se prodaly vsechny tokeny
        require(totalToken() <= COUNT, "All tokens sold.");

        // pozastaveny prodej
        require(!PAUSE, "Sale is paused.");

        _;
    }

	// tokenURI pro ziskani konkretniho json metadata souboru
	function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
		
		require(_exists(_tokenId), "Token doesn't exist.");
		
		// pokud jeste neni zverejnenej
		if (!REVEALED) {
			return hiddenUrl;
		}
		// je zverejnenej, vratit plnou adresu
    	return string(abi.encodePacked(_baseURI(), Strings.toString(_tokenId), ".json"));
		
	}

    // getter: URI bez souboru
    function _baseURI() internal view virtual override returns (string memory) {
    
    	// tohle by nejspis melo vratit adresu konkretniho tokenu
        return baseTokenURI;
    }

    // vytvoreni base URI - json
    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    // u kolikateho jsme
    function totalToken() public view returns (uint256) {
        return _tokenIdTracker.current();
    }

    // POKUD SE MA TENHLE KONTRAKT VCETNE TOHO MINT POUZIVAT NA OPENSEA, TAK BUDE POTREBA VYTVORIT DVE MINTOVACI FCE: MINT A MINTWHITELIST, KDE V MINT NEBUDE TEN PROOF
    // hromadny mint
    function mint(uint256 _howmany, bytes32[] calldata _proof) public payable saleIsOpen { // arg: bytes memory _signature arg: uint256 _timestamp

        // k obecnemu omezeni prodeje uz doslo v saleIsOpen

        // pocet tokenu
        uint256 total = totalToken();

        // over limity pro konkretni nakup
        require(_howmany <= (PRESALE ? MAX_PER_MINT_PRESALE : MAX_PER_MINT_SALE), "Too many tokens to mint.");

        // kontrola dostupneho mnozstvi tokenu
        require(total + _howmany <= COUNT, "Not enough tokens.");

        // nesmi presahnout limit na jednu penezenku
        require(balanceOf(msg.sender) + _howmany <= MAX_PER_WALLET, "You already own maximum number of tokens.");

        // kontrola mnozstvi penez
        require(msg.value >= PRICE.mul(_howmany), "Not enough money to purchase tokens.");

        // overeni 
        address wallet = _msgSender();

        // pokud se jednalo presale whitelisting, kontroluj ECDSA podpis
        if (PRESALE) {
            //address signerOwner = signatureWallet(wallet,_timestamp,_signature);
            //require(signerOwner == owner(), "Not whitelisted for presale.");
            bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
            require(MerkleProof.verify(_proof, MERKLE, leaf), "Address is not whitelisted.");
        }

        // overeni casu - puvodne asi fungovalo tak ze dal moznost prodat konkretni token s timestamp co mel v db, a zjistit jestli uz alokace tokenu nevyprchala - tohle zatim nepotrebujeme
        //require(block.timestamp >= _timestamp - 30, "Out of time");

        // tohle puvodne ocividne fungovalo tak ze se mintoval konkretni vybranej token, proto posilal do mintu i jeho id
        for(uint8 i = 0; i < _howmany; i++){
            //require(rawOwnerOf(_tokensId[i]) == address(0) && _tokensId[i] > 0 && _tokensId[i] <= COUNT, "Token already minted");
            _mintAnElement(wallet);
        }

    }

    // single mint
    function _mintAnElement(address _to) private { // arg: uint256 _tokenId
        _tokenIdTracker.increment();
        _safeMint(_to, _tokenIdTracker.current());
        //emit welcomeToMekaVerse(_tokenId);
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

    // nastav cenu
    function setPrice(uint256 _price) public onlyOwner{
        PRICE = _price;
    }

    // nastav hiddenUrl
    function setHiddenUrl(string memory _newUrl) public onlyOwner{
        hiddenUrl = _newUrl;
    }

    // nastav reveal
    function setReveal(bool _reveal) public onlyOwner{
        REVEALED = _reveal;
    }

    // nastav pauzu
    function setPause(bool _pause) public onlyOwner{
        PAUSE = _pause;
        //emit PauseEvent(PAUSE);
    }

    // vyber penez: TODO
    function withdraw() public payable onlyOwner {
        uint balance = address(this).balance;
        require(balance > 0, "No ether left to withdraw.");
        (bool success,) = payable(msg.sender).call{value: balance}("");
        require(success, "Transfer failed.");
    }

    /*
    // tohle podle me fungovalo tak, ze si clovek vybral toho kteryho chtel dopredu, on se mu podepsal a on ho mohl koupit jdine potom ze svy penezenky
    function signatureWallet(address wallet, uint256[] memory _tokensId, uint256 _timestamp, bytes memory _signature) public view returns (address){

        // on totiz pomoci nejake funkce metamask penezenky zakodoval privatni klicem v te penezence trojici(wallet, vybrane tokenid, timestamp)
        return ECDSA.recover(keccak256(abi.encode(wallet, _tokensId, _timestamp)), _signature);

    }
    
    // over ze je podpis zpravy 
    function _verify(bytes32 data, address account) pure returns (bool) {
        return keccack256(data).recover(signature) == account;
    }
    */

    /*
    function getUnsoldTokens(uint256 offset, uint256 limit) external view returns (uint256[] memory){

        uint256[] memory tokens = new uint256[](limit);

        for (uint256 i = 0; i < limit; i++) {
            uint256 key = i + offset;
            if(rawOwnerOf(key) == address(0)){
                tokens[i] = key;
            }
        }

        return tokens;
    }
    */

    /*
    function mintUnsoldTokens(uint256[] memory _tokensId) public onlyOwner {

        require(PAUSE, "Pause is disable");

        for (uint256 i = 0; i < _tokensId.length; i++) {
            if(rawOwnerOf(_tokensId[i]) == address(0)){
                _mintAnElement(owner(), _tokensId[i]);
            }
        }
    }
    */
}