// SPDX-License-Identifier:MIT
pragma solidity >=0.7.0 <0.9.0;


import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./BaseRelayRecipient.sol";


contract MyNFT is ERC721PresetMinterPauserAutoId, BaseRelayRecipient {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    bytes32 private constant _MINT_FROZEN_ROLE = keccak256("MINT_FROZEN_ROLE");

    mapping(uint16 => bool) private _mintables;
    mapping(uint16 => string) private _sessionCodeToURI;
    mapping(uint256 => uint16) private _tokenIdToSessionCode;
    mapping(address =>  mapping(uint16 => bool)) private _balances;

    constructor() ERC721PresetMinterPauserAutoId("NFTSample20211020", 
                                                 "nftsample20211020", 
                                                 ""){
        _setupRole(_MINT_FROZEN_ROLE, _msgSender());
        _sessionCodeToURI[1001] = "https://bafkreidumisrh3tnlrcqvsy64s5yfffmtahdupftky3rdxjy2a3xwaafxi.ipfs.dweb.link";
        _sessionCodeToURI[1002] = "https://bafkreia5r4wobqfgvwg6l4krw5qerumwpy474zkwydi73rhjlelzxti5qu.ipfs.dweb.link";
        _sessionCodeToURI[1003] = "https://bafkreidrohliugtcjvf4iz2sa6jexhw3rcqu4rvpkowhibmghlzijkzify.ipfs.dweb.link";
        _sessionCodeToURI[1004] = "https://bafkreicnvbmldflw6uy24fzmlueeh2vfqdxyyq2ijofxcup3epte77xl5a.ipfs.dweb.link";
        _mintables[1001] = true;
        _mintables[1002] = true;
        _mintables[1003] = true;
        _mintables[1004] = true;
    }
    
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");
        string memory uri = _sessionCodeToURI[_tokenIdToSessionCode[tokenId]];
        return bytes(uri).length > 0 ? string(abi.encodePacked(uri, "")) : "";
    }
    
    function setMintable(bool mintable, uint16 sessionCode) public virtual {
        require(hasRole(_MINT_FROZEN_ROLE, _msgSender()), "must have MINT_FROZEN role to change mintable");
        require(bytes(_sessionCodeToURI[sessionCode]).length != bytes("").length, "invalid sessionCode");
        _mintables[sessionCode] = mintable;
    }
    
    function mintNFT(address to, uint16 sessionCode) public virtual {
        // TODO replace method name to mint
        require(bytes(_sessionCodeToURI[sessionCode]).length != bytes("").length, "invalid sessionCode");
        require(_mintables[sessionCode], "Mint permission is not enable");
        require(!_balances[to][sessionCode], "Cannot own the same NFT.");
        uint256 tokenId = _tokenIdCounter.current();
        _mint(to, tokenId);
        _tokenIdToSessionCode[tokenId] = sessionCode;
        _balances[to][sessionCode] = true;
        _tokenIdCounter.increment();
    }
    
    function _msgSender() internal virtual view override(BaseRelayRecipient, Context) returns (address) {
        return BaseRelayRecipient._msgSender();
    }
    
    
    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(!_balances[to][_tokenIdToSessionCode[tokenId]], "Cannot own the same NFT.");
        super.safeTransferFrom(from, to, tokenId);
        _balances[from][_tokenIdToSessionCode[tokenId]] = false;
        _balances[to][_tokenIdToSessionCode[tokenId]] = true;
    }

    /**
     * @dev See {IERC721-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(!_balances[to][_tokenIdToSessionCode[tokenId]], "Cannot own the same NFT.");
        super.safeTransferFrom(from, to, tokenId, _data);
        _balances[from][_tokenIdToSessionCode[tokenId]] = false;
        _balances[to][_tokenIdToSessionCode[tokenId]] = true;
    }

    /**
     * @dev See {IERC721-transferFrom}.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        require(!_balances[to][_tokenIdToSessionCode[tokenId]], "Cannot own the same NFT.");
        super.transferFrom(from, to, tokenId);
        _balances[from][_tokenIdToSessionCode[tokenId]] = false;
        _balances[to][_tokenIdToSessionCode[tokenId]] = true;
    }
}