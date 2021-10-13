// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract NFTtest is ERC721Enumerable, Ownable {

    using Strings for uint256;

    uint256 public constant PRICE = 0.005 ether;
    uint256 public constant TOTAL_NUMBER_OF_NFTTEST = 100;

    uint256 public giveaway_reserved = 10;
    uint256 public pre_mint_reserved = 20;

    uint256 public constant MAX_PER_WALLET = 7;
    uint256 public constant PRESALE_MAX = 2;
    uint256 public constant MAX_PER_TXN = 5;


    mapping(address => bool) private _pre_sale_minters;
    mapping(address => uint256) public _pre_sale_purchases;

    bool public paused_mint = true;
    bool public paused_pre_mint = true;
    string private _baseTokenURI = "";


    // withdraw addresses
    address wallet_split;


    modifier whenMintNotPaused() {
        require(!paused_mint, "NFTTest: mint is paused");
        _;
    }

    modifier whenPreMintNotPaused() {
        require(!paused_pre_mint, "NFTTest: pre mint is paused");
        _;
    }

    modifier preMintAllowedAccount(address account) {
        require(is_pre_mint_allowed(account), "NFTTest: account is not allowed to pre mint");
        _;
    }

    event MintPaused(address account);

    event MintUnpaused(address account);

    event PreMintPaused(address account);

    event PreMintUnpaused(address account);

    event setPreMintRole(address account);

    event redeemedPreMint(address account);

    constructor(
        address _wallet_split
    )
        ERC721("New NTF Test", "NNFT")
    {
        wallet_split = _wallet_split;

    }

    fallback() external payable { }

    receive() external payable { }

    function mint(uint256 num) public payable whenMintNotPaused(){
        uint256 tokenCount = balanceOf(msg.sender);
        require( num <= MAX_PER_TXN, "NFTTest: You can mint a maximum of MAX_PER_TXN NFTs" );
        require( tokenCount + num <= MAX_PER_WALLET, "NFTTest: You can mint a maximum of MAX_PER_WALLET NFTs per wallet" );
        require( totalSupply() + num <= TOTAL_NUMBER_OF_NFTTEST - giveaway_reserved, "NFTTest: Exceeds maximum NFTs supply" );
        require( msg.value >= PRICE * num, "NFTTest: Ether sent is less than PRICE * num" );

        for(uint256 i = 0; i < num; i++){
            _safeMint( msg.sender, totalSupply() + 1 );
        }
    }

    function pre_mint(uint256 num) public payable whenPreMintNotPaused() preMintAllowedAccount(msg.sender){
        require( pre_mint_reserved > 0, "NFTTest: Exceeds pre mint reserved NFTs supply" );
        require(_pre_sale_purchases[msg.sender] + num <= PRESALE_MAX, "EXCEED_ALLOC OF PRESALE_MAX NFTs MAX");
        require( msg.value >= PRICE * num, "NFTTest: Ether sent is less than PRICE * num" );

        if (_pre_sale_purchases[msg.sender] + num == 2) { _pre_sale_minters[msg.sender] = false; }    

        for (uint256 i = 0; i < num; i++) {
            pre_mint_reserved -= 1;
             _pre_sale_purchases[msg.sender]++;
            _safeMint(msg.sender, totalSupply() + 1);
        }
        emit redeemedPreMint(msg.sender);
    }

    function giveAway(address _to) external onlyOwner {
        require(giveaway_reserved > 0, "NFTTest: Exceeds giveaway reserved NFTs supply" );
        giveaway_reserved -= 1;
        _safeMint( _to, totalSupply() + 1);
    }

    function pauseMint() public onlyOwner {
        paused_mint = true;
        emit MintPaused(msg.sender);
    }

    function unpauseMint() public onlyOwner {
        paused_mint = false;
        emit MintUnpaused(msg.sender);
    }

    function pausePreMint() public onlyOwner {
        paused_pre_mint = true;
        emit PreMintPaused(msg.sender);
    }

    function unpausePreMint() public onlyOwner {
        paused_pre_mint = false;
        emit PreMintUnpaused(msg.sender);
    }

    function updateWalletSplitterAddress(address _wallet_split) public onlyOwner {
        wallet_split = _wallet_split;
    }

    function addToPresaleList(address[] calldata _addresses) external onlyOwner {
        for(uint256 i; i < _addresses.length; i++){
            address entry = _addresses[i];
            require(entry != address(0), "NULL_ADDRESS");
            require(!_pre_sale_minters[entry], "DUPLICATE_ENTRY");
            _pre_sale_minters[entry] = true;
            emit setPreMintRole(entry);
        }
    }

        function removeFromPresaleList(address[] calldata entries) external onlyOwner {
        for(uint256 i = 0; i < entries.length; i++) {
            address entry = entries[i];
            require(entry != address(0), "NULL_ADDRESS");
            _pre_sale_minters[entry] = false;
        }
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }


    function withdrawAmountToSplitter(uint256 amount) public onlyOwner {
        uint256 _balance = address(this).balance ;
        require(_balance > 0, "NFTTest: withdraw amount call without balance");
        require(_balance-amount >= 0, "NFTTest: withdraw amount call with more than the balance");
        require(payable(wallet_split).send(amount), "NFTTest: FAILED withdraw amount call");
    }

    function withdrawAllToSplitter() public onlyOwner {
        uint256 _balance = address(this).balance ;
        require(_balance > 0, "NFTTest: withdraw all call without balance");
        require(payable(wallet_split).send(_balance), "NFTTest: FAILED withdraw all call");
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "NFTTest: URI query for nonexistent token");

        string memory baseURI = getBaseURI();
        string memory json = ".json";
        return bytes(baseURI).length > 0
            ? string(abi.encodePacked(baseURI, tokenId.toString(), json))
            : '';
    }

    function walletOfOwner(address _owner) public view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

   function presalePurchasedCount(address addr) external view returns (uint256) {
        return _pre_sale_purchases[addr];
    }

    function getWalletSplitter() public view onlyOwner returns(address splitter) {
        return wallet_split;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function is_pre_mint_allowed(address account) public view  returns (bool) {
        return _pre_sale_minters[account];
    }

    function getBaseURI() public view returns (string memory) {
        return _baseTokenURI;
    }
}