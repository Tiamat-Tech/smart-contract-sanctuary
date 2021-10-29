//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./ERC2981.sol";
import "./ITokenSale.sol";
import "./IVTailERC721.sol";

import "@imtbl/imx-contracts/contracts/Mintable.sol";

contract OwnableDelegateProxy {}

contract ProxyRegistry {
    mapping(address => OwnableDelegateProxy) public proxies;
}

/**
 * @title ERC721 contract for VTail.com
 * @dev see  [EIP-20: Basic token standard]
 */
contract VTailERC721 is IVTailERC721, ERC721, ERC2981, Ownable, Mintable {

    // the base URI for URI calls
    string private _baseUri;

    // the proxy registry address
    address _proxyRegistryAddress;

    // the minter of this token - it is minted on demand
    address private minter;

    // the max quantity that can be minted
    uint256 private mintingMax;

    // the max quantity that can be minted
    uint256 private nextIndexValue;

    // the token owners
    uint256[] private tokenHashes;

    // mofifier - only minter can mint
    modifier onlyMinter() {
        require(msg.sender == minter, "Only the minter can mint tokens");
        _;
    }
    /**
     * @dev Initializes the contract with the minter, the mintingMax and the total supply.
     * @param name the token name
     * @param symbol the token symbol
     * @param _mintingMax the total number of tokens  to be minted
     * @param _uri the base uri for the token
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 _mintingMax,
        string memory _uri,
        address _owner,
        address imx) ERC721(name, symbol) Mintable(_owner, imx) {
            // set the minter and mintinx max
            mintingMax = _mintingMax;
            _baseUri = _uri;
            nextIndexValue = 1;
    }

    /**
     * @dev mint an NFT of the given id to the target address
     * @return totalSupply the total supply of the token
     */
    function _totalSupply() public view returns (uint256 totalSupply) {
        totalSupply = nextIndexValue - 1;
    }

    /**
     * @dev set the allowed minter
     */
    function setMinter(address minter_) public {
        require(minter == address(0), 'immutable');
        minter = minter_;
    }

    /**
     * @dev get the allowed minter
     */
    function getMinter() external view override returns (address) {
        return minter;
    }

    /**
     * @dev mint an NFT of the given id to the target address
     * @param receiver the address of the mintee
      * @param receiver the tokenHash to mint them
     */
    function mint(address receiver, uint256 tokenHash) external override onlyMinter {

        // require that less than mintingMax tokens have been minted
        require(_totalSupply() <= mintingMax, "Minting max reached");
        // set the initial royalty receiver to the receiver of the token
        royaltyReceiversByHash[tokenHash] = receiver;
        tokenHashes.push(tokenHash);
        nextIndexValue++;
        // mint the token
        _mint(receiver, tokenHash);
    }

    /**
     * @dev _mintFor - immutable x minting
     * @param to the address of the mintee
      * @param id the tokenHash to mint them
     */
    function _mintFor(
        address to,
        uint256 id,
        bytes memory
    ) internal override {
        _mint(to, id);
    }

    /// @notice ERC165 interface responder for this contract
    /// @param interfaceId - the interface id to check
    /// @return supportsIface - whether the interface is supported
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC2981, ERC721, IERC165) returns (bool supportsIface) {
        supportsIface = interfaceId == type(IERC2981).interfaceId
        || super.supportsInterface(interfaceId);
    }

    /**
     * Override isApprovedForAll to whitelist user's OpenSea proxy accounts
     * to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator)
        override(ERC721, IERC721)
        public
        view
        returns (bool)
    {
        if(_proxyRegistryAddress != address(0)) {
            // Whitelist OpenSea proxy contract for easy trading.
            ProxyRegistry proxyRegistry = ProxyRegistry(_proxyRegistryAddress);
            if (address(proxyRegistry.proxies(owner)) == operator) {
                return true;
            }
        }
        return super.isApprovedForAll(owner, operator);
    }

    /// @notice the base token URI
    /// @return baseUri - the base URI
    function baseTokenURI()
        external override
        view returns (string memory baseUri) {
        baseUri = _baseUri;
    }

    /// @notice the base token URI
    function setBaseTokenURI(string memory _baseU)
        external override onlyOwner {
        _baseUri = _baseU;
    }

    /// @notice the base token URI
    /// @return baseUri - the base URI
    function proxyRegistryAddress()
        external override
        view returns (address) {
        return _proxyRegistryAddress;
    }

    /// @notice the base token URI
    function setProxyRegistryAddress(address valu)
        external override onlyOwner {
        _proxyRegistryAddress = valu;
    }

    /// @notice the base token URI
    /// @param _tokenId - the interface id to check
    /// @return _tokenUri - the token  URI
    function tokenURI(uint256 _tokenId)
        override
        public
        view returns (string memory _tokenUri) {
        _tokenUri = string(
            abi.encodePacked(_baseUri, Strings.toString(_tokenId))
        );
    }

    // utility - checks if user owns the given tokens
    function owns(address owner, uint256[] memory tokenIds) external view override returns (bool[] memory _result) {
        _result = new bool[](tokenIds.length);
        for(uint256 i = 0; i < tokenIds.length; i++) {
            _result[i] = ownerOf(tokenIds[i]) == owner;
        }
    }

    // utility - return all token owners
    function allTokenHashes() external view override returns (uint256[] memory) {
        return tokenHashes;
    }
}