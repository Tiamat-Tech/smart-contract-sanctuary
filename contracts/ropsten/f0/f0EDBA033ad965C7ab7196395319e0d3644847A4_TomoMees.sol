// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721Burnable.sol";
import "base64-sol/base64.sol";

/**
 * @dev {ERC721} token, including:
 *  - Ability for holders to burn (destroy) their tokens
 *  - Token ID and on-chain data storage
 */
contract TomoMees is Context, Ownable, ERC721Burnable {

    using Strings for uint256;

    using Counters for Counters.Counter;

    // Optional mapping for token URIs
    mapping(uint256 => string) private _tokenURIs;

    // Maps the token ID to a base64 string of the TomoMees
    mapping(uint256 => string) private punkImages;

    // Maps the token ID to a string containing the NFTs attributes
    // Refer to OpenSea Metadata Standards: https://docs.opensea.io/docs/metadata-standards
    mapping(uint256 => string) private punkAttributes;

    // Maps addresses to the number of TomoMees they have minted
    mapping(address => uint) private minted;

    // Maximum number of tokens that can be minted
    // uint32 public constant MAX_MINT = 20000;
    uint32 public constant MAX_MINT = 10;

    // Required value to transfer to mint a TomoMees 
    // uint256 public constant PUNK_PRICE = 2 ether;
    uint256 public price = 0.001 ether;

    // Boolean for used to lock metadata, call lockMetadata() to lock the metadata
    bool public lockedMetadata = false;

    // Counter for tracking the token ID
    Counters.Counter private _tokenIdTracker;

    constructor() public ERC721("TomoMees", "TMM") {
        // for(uint i = 0; i < 20; i++) {
        //     mint(msg.sender);
        // }
    }

    /**
     * @return return current counter
     */
    function getCurrentCounter() public view returns (uint256) {
        return _tokenIdTracker.current();
    }

    /**
     * @param tokenId the ID of the token to look up
     * @return the image data as a string for the token specified
     */
    function getPunkImage(uint tokenId) public view returns (string memory) {
        return punkImages[tokenId];
    }
    
    /**
     * @param tokenId the ID of the token to look up
     * @return the attributes as a string for the token specified
     */
    function getPunkAttributes(uint tokenId) public view returns (string memory) {
        return punkAttributes[tokenId];
    }
    
    // /**
    //  * @param tokenId the ID of the token to look up
    //  * @return the tokenURI as a string for the token specified
    //  */
    // function tokenURI(uint256 tokenId) override public view returns (string memory) {
    //     string memory json = Base64.encode(bytes(string(abi.encodePacked('{ "name": "TomoMees #', Strings.toString(tokenId), '", "image": "', bytes(getPunkImage(tokenId)), '", "attributes": [', getPunkAttributes(tokenId), '] }'))));
    //     return string(abi.encodePacked('data:application/json;base64,', json));
    // }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal pure virtual returns (string memory) {
        return "";
    }

    /**
     * @param id the ID of the token
     * @param data the data to be stored in the mapping
     * @dev Maps the data to the id in punkImages
     */
    function setPunkImage(uint id, string memory data) public virtual onlyOwner {
        require(!lockedMetadata, "Error: The Metadata can no longer be changed!");
        punkImages[id] = data;
    }
    
    /**
     * @param id an array of id's
     * @param data an array of data to map to the corresponding id's
     * @dev Takes in an array of ID's and an array of image data and maps them in punkImages
     */
    function setPunkImages(uint[] memory id, string[] memory data) public virtual onlyOwner {
        require(!lockedMetadata, "Error: The Metadata can no longer be changed!");
        require(id.length == data.length, "Error: Length of ID and Data arrays is not equal!");

        for(uint i = 0; i < id.length; i++) {
            setPunkImage(id[i], data[i]);
        }
    }
    
    /**
     * @param id an array of id's
     * @param data an array of data to map to the corresponding id's
     * @dev Takes in an array of ID's and an array of image data and maps them in punkImages
     */
    function setPunkAttribute(uint id, string[] memory data) public virtual onlyOwner {
        require(!lockedMetadata, "Error: The Metadata can no longer be changed!");
        
        string memory attributes = string(abi.encodePacked('{"trait_type": "Type","value": "', data[0], '"}'));
        for(uint i = 1; i < data.length; i++) {
            attributes = string(abi.encodePacked(attributes, ',{"trait_type": "Accessory", "value": "', data[i], '"}'));
        }
        
        punkAttributes[id] = attributes;
    }
    
    /**
     * @param id an array of id's
     * @param data an array of data arrays to map to the corresponding id's
     * @dev Takes in an array of ID's and an array of attribute arrays and maps them in punkImages
     */
    function setPunkAttributes(uint[] memory id, string[][] memory data) public virtual onlyOwner {
        require(!lockedMetadata, "Error: The Metadata can no longer be changed!");
        require(id.length == data.length, "Error: Length of ID and Data arrays is not equal!");

        for(uint i = 0; i < id.length; i++) {
            setPunkAttribute(id[i], data[i]);
        }
    }
    
    /**
     * @param id the ID of the token
     * @param img the image data to be stored
     * @param attributes an array of attributes to be stored
     * @dev Maps the image data to the id in punkImages and the attributes to the id in punkAttributes
     */
    function setPunkImageAndAttribute(uint id, string memory img, string[] memory attributes) public virtual {
        require(!lockedMetadata, "Error: The Metadata can no longer be changed!");

        setPunkImage(id, img);
        setPunkAttribute(id, attributes);   
    }
    
    /**
     * @param id an array of id's
     * @param img an array of image data to be stored
     * @param attributes an array of attribute arrays to be stored
     * @dev Maps the image data to the id's in punkImages and the attributes to the id's in punkAttributes
     */
    function setPunkImagesAndAttributes(uint[] memory id, string[] memory img, string[][] memory attributes) public virtual {
        require(!lockedMetadata, "Error: The Metadata can no longer be changed!");
        require(id.length == img.length && id.length == attributes.length, "Error: Length of ID, Image and Attributes arrays are not equal!");

        for(uint i = 0; i < id.length; i++) {
            setPunkImage(id[i], img[i]);
            setPunkAttribute(id[i], attributes[i]);
        }
    }
    
    /**
     * @dev Locks the metadata in its current state, setPunk... functions will no longer work.
     */
    function lockMetadata() public virtual onlyOwner {
        require(!lockedMetadata, "Error: The Metadata is already locked!");
        lockedMetadata = true;
    }

    /**
     * @dev set price
     */
    function setPrice(uint256 p) public virtual onlyOwner {
        price = p;
    }

    /**
     * @param to the address to mint the token to
     * @dev Creates a new token for `to`. Its token ID will be automatically
     *      assigned (and available on the emitted {IERC721-Transfer} event), and the token
     *      URI autogenerated based on the on-chain data.
     */
    function mint(address to) public virtual payable {
        require(_tokenIdTracker.current() < MAX_MINT, "Error: There are no more tokens left to be minted!");
        require(msg.value >= price || msg.sender == owner(), "Not enough tokens to minting!");

        // We cannot just use balanceOf to create the new tokenId because tokens
        // can be burned (destroyed), so we need a separate counter.
        _mint(to, _tokenIdTracker.current());
        _tokenIdTracker.increment();

        // Increment the number of mints that msg.sender has
        minted[msg.sender] += 1;
    }

    /**
     * @param addr the address to look up
     * @return uint for the amount of tokens an address has minted
     */
    function getAmountMintedByAddress(address addr) public virtual view returns(uint) {
        return minted[addr];
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721URIStorage: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    /**
     * @dev Sets `_tokenURI` as the tokenURI of `tokenId`.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal override virtual {
        // require(_exists(tokenId), "ERC721URIStorage: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function setTokenURI(
        uint256 tokenId, 
        string memory _tokenURI
    ) external virtual onlyOwner {
        require(!lockedMetadata, "Error: The Metadata can no longer be changed!");

        _setTokenURI(tokenId, _tokenURI);
    }
    
    function setTokensURI(
        string[] memory tokensURI
    ) external virtual onlyOwner {
        require(!lockedMetadata, "Error: The Metadata can no longer be changed!");

        for(uint256 i = 0; i < tokensURI.length; i++) {
            _setTokenURI(i, tokensURI[i]);
        }
    }

    /**
     * @dev Destroys `tokenId`.
     * The approval is cleared when the token is burned.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     *
     * Emits a {Transfer} event.
     */
    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }

    /**
     * @dev Withdraws the balance of the contract to the senders address
     */
    function withdraw() public virtual onlyOwner {
        uint256 amount = address(this).balance;
        payable(msg.sender).transfer(amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
}