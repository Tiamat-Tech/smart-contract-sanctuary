// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract InvitationalNFT is
    ERC721URIStorage,
    AccessControl
{
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => bool) public minted; // checks if user have already minted invitational nft or not 
    mapping(address => uint256) public ownersToIds; // maps user to owned NFT ID
    mapping(address => uint256) public lastWithdrawTimestamps;  

    uint256 public mintTimeout; // a period of time to wait since the last withdraw in order to mint NFT
    bool public mintEnabled;
    string public baseURI;

    uint256 private _lastMintedId;
    mapping(string => bool) private hasTokenWithURI;
    EnumerableSet.AddressSet private vaults;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory baseURI_,
        address _admin,
        bool _mintEnabled,
        uint256 _mintTimeout
    ) ERC721(_name, _symbol) {
        baseURI = baseURI_;
        mintEnabled = _mintEnabled;
        mintTimeout = _mintTimeout;
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    modifier onlyValidVault(address sender) {
        require(
            vaults.contains(sender), 
            "Invalid vault"
        );
        _;
    }

    /**
     * @notice Adds new vault
     * @param _contract new vault address
     */
    function addVault(address _contract) external onlyRole(DEFAULT_ADMIN_ROLE) {
        vaults.add(_contract);
    }

    /**
     * @notice Sets mintTimeout
     * @param _mintTimeout new mint timeout value
     */
    function setMintTimeout(uint256 _mintTimeout) external onlyRole(DEFAULT_ADMIN_ROLE) {
        mintTimeout = _mintTimeout;
    }

    /**
     * @notice Mint nft
     * @param _tokenURI token URI
     * @param _to current address to transfer nft
     */
    function mint(string calldata _tokenURI, address _to)
        external
    {
        address sender = _msgSender();
        require(mintEnabled, "mint disabled");
        require(!hasTokenWithURI[_tokenURI], "ERC721Main: URI already exists");
        require(ownersToIds[_to] == 0, "already has invitation");
        require(_to != address(0) && _to != address(this) && _to != sender, "Wrong addresses");
        require(
            !minted[sender],
            "Invitational NFT was already minted"
        );
        require(
            lastWithdrawTimestamps[sender] != 0 && 
            block.timestamp >= lastWithdrawTimestamps[sender] + mintTimeout,
            "mint is not allowed yet"
        );

        minted[sender] = true;
        // prefix because _lastMintedId cannot be 0
        uint256 tokenId = ++_lastMintedId;      
        ownersToIds[_to] = tokenId;
        hasTokenWithURI[_tokenURI] = true;
        _mint(_to, tokenId);
        _setTokenURI(tokenId, _tokenURI);

    }
    /**
     * @notice Priveleged function to mint nft without timeout
     * @param _tokenURI token URI
     * @param _to current address to transfer nft
     */
    function mintWithoutTimeout(string calldata _tokenURI, address _to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(mintEnabled, "mint disabled");
        require(ownersToIds[_to] == 0, "already has invitation");
        require(!hasTokenWithURI[_tokenURI], "ERC721Main: URI already exists");
        // prefix because _lastMintedId cannot be 0
        uint256 tokenId = ++_lastMintedId;      
        ownersToIds[_to] = tokenId;        
        hasTokenWithURI[_tokenURI] = true;
        _mint(_to, tokenId);
        _setTokenURI(tokenId, _tokenURI);

    }

    function enableMint() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!mintEnabled, "already enabled");
        mintEnabled = true;
    }

    function disableMint() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(mintEnabled, "already disabled");
        mintEnabled = false;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControl)
        returns (bool)
    {
        return
            ERC721.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721URIStorage)
        returns (string memory)
    {
        return ERC721URIStorage.tokenURI(tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721) {
        ERC721._beforeTokenTransfer(from, to, tokenId);
    }

    function burn(address _from) onlyValidVault(_msgSender()) external {
        uint256 tokenId = ownersToIds[_from];
        lastWithdrawTimestamps[_from] = block.timestamp;
        if (tokenId != 0) {
            delete ownersToIds[_from];
            hasTokenWithURI[tokenURI(tokenId)] = false;
            ERC721URIStorage._burn(tokenId);    
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        revert("Token isn't transferable");
    }
}