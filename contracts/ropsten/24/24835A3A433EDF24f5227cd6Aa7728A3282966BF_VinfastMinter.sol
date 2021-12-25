//SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VinfastMinter is ERC721, Ownable, ReentrancyGuard {
    
    event TokenDistributed(uint256 indexed _id, string _uri, address indexed _owner);

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    struct FormattedToken {
        uint256 id;
        string uri;
        address owner;
    }

    // Map keccak256 hashed access codes with Token IDs
    mapping (string=>uint256) _tokensAccessKeys;

    // Map token IDs with claimed status
    mapping (uint=>bool) _tokensDistributed;

    // Map token IDs with token URIs
    mapping (uint=>string) _tokenURIs;

    constructor(string memory tokenName, string memory symbol) ERC721(tokenName, symbol) {}

    function mintToken(string memory metadataURI, string memory username, string memory password)
    public
    onlyOwner
    returns (uint256)
    {
        string memory tokenAccessKey = getAccessKey(username, password);
        require(tokenByAccessKey(tokenAccessKey) == 0, "Access credentials exists");

        _tokenIds.increment();
        uint256 id = _tokenIds.current();
        _safeMint(_msgSender(), id);
        _setTokenURI(id, metadataURI);

        _tokensAccessKeys[tokenAccessKey] = id;

        return id;
    }

    // Token URI
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        _tokenURIs[tokenId] = _tokenURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns(string memory) {
        require(_exists(tokenId));
        string memory _tokenURI = _tokenURIs[tokenId];
        return _tokenURI;
    }

    // Token claimed
    function _setTokenDistributed(uint256 tokenId) internal {
        _tokensDistributed[tokenId] = true;
    }

    function tokenDistributed(uint256 tokenId) public view virtual returns(bool) {
        require(_exists(tokenId));
        bool _tokenClaimed = _tokensDistributed[tokenId];
        return _tokenClaimed;
    }

    function tokenByAccessKey(string memory tokenAccessKey) public view virtual returns(uint256) {
        return _tokensAccessKeys[tokenAccessKey];
    }

    // Data fetching
    function getAllTokens() public view returns (FormattedToken[] memory) {
        uint256 lastId = _tokenIds.current();
        uint256 counter = 0;
        FormattedToken[] memory _formattedTokens = new FormattedToken[](lastId);
        for (uint256 i = 0; i < lastId; i++) {
            if (_exists(counter + 1)) {
                string memory uri = tokenURI(counter + 1);
                address addr = ownerOf(counter + 1);
                _formattedTokens[counter] = FormattedToken(counter + 1, uri, addr);
            }
            counter++;
        }
        return _formattedTokens;
    }

    function getTokensByAddress(address addr) public view returns (FormattedToken[] memory) {
        uint256 lastId = balanceOf(addr);
        uint256 counter = 0;
        FormattedToken[] memory _formattedTokens = new FormattedToken[](lastId);
        for (uint256 i = 0; i < lastId; i++) {
            if (_exists(counter + 1) && addr == ownerOf(counter + 1)) {
                string memory uri = tokenURI(counter + 1);
                _formattedTokens[counter] = FormattedToken(counter + 1, uri, addr);
            }
            counter++;
        }
        return _formattedTokens;
    }

    function getTokenByUsernameAndPassword(string memory username, string memory password) public view returns (FormattedToken memory) {
        string memory accessKey = getAccessKey(username, password);
        uint256 tokenId = tokenByAccessKey(accessKey);
        require(_exists(tokenId), "Access credentials does not exists");
        string memory uri = tokenURI(tokenId);
        address addr = ownerOf(tokenId);
        return FormattedToken(tokenId, uri, addr);
    }

    // Access key helpers
    function getAccessKey(string memory username, string memory password) internal pure returns(string memory){
        bytes32 _hash = keccak256(abi.encodePacked(username, password));
        bytes memory _bytes = bytes32ToBytes(_hash);
        string memory converted = string(_bytes);
        return converted;
    }

    function bytes32ToBytes(bytes32 _bytes32) internal pure returns (bytes memory){
        bytes memory bytesArray = new bytes(32);
        for (uint256 i; i < 32; i++) {
            bytesArray[i] = _bytes32[i];
        }
        return bytesArray;
    }

    // Handling distribution and transfers
    function distributeReward(address to, string memory username, string memory password) public virtual onlyOwner nonReentrant{
        string memory tokenAccessKey = getAccessKey(username, password);
        uint256 tokenId = tokenByAccessKey(tokenAccessKey);
        require(_exists(tokenId), "Access credentials does not exists");
        require(!tokenDistributed(tokenId), "Already distributed");
        _setTokenDistributed(tokenId);
        transferFrom(_msgSender(), to, tokenId);

        string memory uri = tokenURI(tokenId);
        address addr = ownerOf(tokenId);
        emit TokenDistributed(tokenId, uri, addr);
    }

    // Override _isApprovedOrOwner to refuse transfering undistributed tokens
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view virtual override returns (bool) {
        require(tokenDistributed(tokenId), "It is not allowed to use standard transfer functions before token is claimed");
        require(_exists(tokenId), "ERC721: operator query for nonexistent token");
        address owner = ERC721.ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }
}