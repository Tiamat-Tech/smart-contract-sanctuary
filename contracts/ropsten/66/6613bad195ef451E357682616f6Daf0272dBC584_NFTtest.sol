// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract NFTtest is ERC721Enumerable, Ownable, AccessControl {

    using Strings for uint256;

    bytes32 public constant WHITE_LIST_ROLE = keccak256("WHITE_LIST_ROLE");
    uint256 public constant PRICE = 0.005 ether;
    uint256 public constant TOTAL_NUMBER_OF_NFTTEST = 100;

    uint256 public giveaway_reserved = 10;
    uint256 public pre_mint_reserved = 20;

    mapping(address => bool) private _pre_sale_minters;

    bool public paused_mint = true;
    bool public paused_pre_mint = true;
    string private _baseTokenURI = "";


    // withdraw addresses
    address wallet_split;

    // initial team
    address test1 = 0xc0edbD0933472430693a2501Ff5F7E7DD364b241;
    address test2 = 0xaf41b038f0510075Be1aC47580800d2B9CB18fdB;
    address test3 = 0xe8d35d040345f764D31d580530aCF28c84971CFE;

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
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, test1);
        _setupRole(DEFAULT_ADMIN_ROLE, test2);
        _setupRole(DEFAULT_ADMIN_ROLE, test3);

        _setupRole(WHITE_LIST_ROLE, msg.sender);
        _setupRole(WHITE_LIST_ROLE, test1);
        _setupRole(WHITE_LIST_ROLE, test2);
        _setupRole(WHITE_LIST_ROLE, test3);
    }

    fallback() external payable { }

    receive() external payable { }

    function mint(uint256 num) public payable whenMintNotPaused(){
        uint256 supply = totalSupply();
        uint256 tokenCount = balanceOf(msg.sender);
        require( num <= 12,                                                             "NFTTest: You can mint a maximum of 12 NFTs" );
        require( tokenCount + num <= 13,                                                "NFTTest: You can mint a maximum of 13 NFTs per wallet" );
        require( supply + num <= TOTAL_NUMBER_OF_NFTTEST - giveaway_reserved,       "NFTTest: Exceeds maximum NFTs supply" );
        require( msg.value >= PRICE * num,                                              "NFTTest: Ether sent is less than PRICE * num" );

        for(uint256 i; i < num; i++){
            _safeMint( msg.sender, supply + i );
        }
    }

    function pre_mint() public payable whenPreMintNotPaused() preMintAllowedAccount(msg.sender){
        require( pre_mint_reserved > 0,         "NFTTest: Exceeds pre mint reserved NFTs supply" );
        require( msg.value >= PRICE,            "NFTTest: Ether sent is less than PRICE" );
        _pre_sale_minters[msg.sender] = false;
        pre_mint_reserved -= 1;
        uint256 supply = totalSupply();
        _safeMint( msg.sender, supply);
        emit redeemedPreMint(msg.sender);
    }

    function giveAway(address _to) external onlyRole(WHITE_LIST_ROLE) {
        require(giveaway_reserved > 0, "NFTTest: Exceeds giveaway reserved NFTs supply" );
        giveaway_reserved -= 1;
        uint256 supply = totalSupply();
        _safeMint( _to, supply);
    }

    function pauseMint() public onlyRole(WHITE_LIST_ROLE) {
        paused_mint = true;
        emit MintPaused(msg.sender);
    }

    function unpauseMint() public onlyRole(WHITE_LIST_ROLE) {
        paused_mint = false;
        emit MintUnpaused(msg.sender);
    }

    function pausePreMint() public onlyRole(WHITE_LIST_ROLE) {
        paused_pre_mint = true;
        emit PreMintPaused(msg.sender);
    }

    function unpausePreMint() public onlyRole(WHITE_LIST_ROLE) {
        paused_pre_mint = false;
        emit PreMintUnpaused(msg.sender);
    }

    function updateWalletSplitterAddress(address _wallet_split) public onlyRole(WHITE_LIST_ROLE) {
        wallet_split = _wallet_split;
    }

    function setPreMintRoleBatch(address[] calldata _addresses) external onlyRole(WHITE_LIST_ROLE) {
        for(uint256 i; i < _addresses.length; i++){
            _pre_sale_minters[_addresses[i]] = true;
            emit setPreMintRole(_addresses[i]);
        }
    }

    function setBaseURI(string memory baseURI) public onlyRole(WHITE_LIST_ROLE) {
        _baseTokenURI = baseURI;
    }

    function withdrawAmountToSplitter(uint256 amount) public onlyRole(WHITE_LIST_ROLE) {
        uint256 _balance = address(this).balance ;
        require(_balance > 0, "NFTTest: withdraw amount call without balance");
        require(_balance-amount >= 0, "NFTTest: withdraw amount call with more than the balance");
        require(payable(wallet_split).send(amount), "NFTTest: FAILED withdraw amount call");
    }

    function withdrawAllToSplitter() public onlyRole(WHITE_LIST_ROLE) {
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

    function getWalletSplitter() public view onlyRole(WHITE_LIST_ROLE) returns(address splitter) {
        return wallet_split;
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function is_pre_mint_allowed(address account) public view  returns (bool) {
        return _pre_sale_minters[account];
    }

    function getBaseURI() public view returns (string memory) {
        return _baseTokenURI;
    }
}