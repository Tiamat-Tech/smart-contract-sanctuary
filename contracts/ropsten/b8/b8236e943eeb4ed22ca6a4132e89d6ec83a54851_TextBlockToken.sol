// SPDX-License-Identifier: MIT
// contract deployed to: 0x99e3705742A141A00dD1D5E55972bDC97A38d109

// safeMintBlockText should prob not have recipient, or you can assign people pages they didn't write

// external is literally just for calling from outside this code; public is to be accessible to other code

// v1 Contract deployed to address: 0xD85198A76788F938E695f9562B4E71AC26D508F3
// v2 is identical but I verified using hardhat etherscan: Contract deployed to address: 0x17CC09020E7a52Bf122B6fC8F302e0651df1CE11

// maybe it's best to have a query by hash for the text in Q and return that in the contract?

// helpful: https://objectcomputing.com/resources/publications/sett/may-2021-non-fungible-tokens
// a wizard! https://docs.openzeppelin.com/contracts/4.x/wizard

// npm i base64-sol to add base64 support ?

// keep idea of an original creator (not just prv owner) - a mapping set at mint?

// good bit of inspiration: https://etherscan.io/address/0xf1b214702bed6ec64843f55e5d566d8ffb3034dd#code

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// import "base64-sol/base64.sol";

contract TextBlockToken is
    ERC721,
    ERC721Enumerable,
    ERC721URIStorage,
    ERC721Burnable,
    Ownable
{
    uint256 public price = 0.0001 ether;

    string public baseUri; // changeable in case website goes down or something
    event TextBlockCreated(uint256 indexed tokenId);

    constructor() ERC721("TextBlock", "TXT") {
        baseUri = "https://test.com/api/";
    }

    struct TextBlock {
        string title; // name of textblock
        string text; // content of textblock
        address author; // address of author
    }

    mapping(uint256 => TextBlock) private textBlocks;

    function getTextBlockTitle(uint256 _tokenId)
        public
        view
        returns (string memory)
    {
        require(_exists(_tokenId));
        return textBlocks[_tokenId].title;
    }

    function getTextBlockContent(uint256 _tokenId)
        public
        view
        returns (string memory)
    {
        require(_exists(_tokenId));
        return textBlocks[_tokenId].text;
    }

    function getTextBlockAuthor(uint256 _tokenId)
        public
        view
        returns (address)
    {
        require(_exists(_tokenId));
        return textBlocks[_tokenId].author;
    }

    //    mapping(uint256 => string) thisTextBlock; // set thisTextBlock as a state variable (write-only once)

    //    mapping(bytes32 => bool) public registeredHashes;

    /*
    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }
*/
    function safeMintBlockText(
        address recipient,
        string memory _title,
        string memory _text // onlyOwner ?
    ) external payable returns (uint256) {
        uint256 newBlockTextId = hashBlockText(_text);
        /* 
        // this is already performed in safeMint
        require(
            !_exists(newBlockTextId),
            "Someone has already written that message!"
        );*/

        require(msg.value >= price, "Not enough Ether sent."); // to take payments have this requirement
        _safeMint(recipient, newBlockTextId);
        //        _setTokenURI(newBlockTextId, newBlockTextId); // not needed as it's worked out from baseUri + token
        textBlocks[newBlockTextId].title = _title;
        textBlocks[newBlockTextId].text = _text;
        textBlocks[newBlockTextId].author = recipient;

        emit TextBlockCreated(newBlockTextId); // emit something ?

        /*        string memory _imageURI,
        string memory _name,
        string memory _description,
        string memory _properties */
        /*
        _setTokenURI(
            newBlockTextId,
            formatTokenURI(
                "Name",
                _text,
                "https://www.sagefruit.com/wp-content/uploads/2016/08/breeze2-300x300.png"
            )
        );
*/
        return newBlockTextId;
    }

    /* FUNCTION TO ADD A PRICE
    modifier tokenMintable(uint256 tokenId) {
        require(tokenId > 0 && tokenId <= _maxSupply, "Token ID invalid");
        require(price <= msg.value, "Ether value sent is not correct");
        _;
    }
*/

    /*
    function safeMint(address to, string memory blockText) public {
        bytes32 tokenId = hashBlockText(blockText);
        _safeMint(to, tokenId);
        _setTokenURI(
            tokenId,
            abi.encodePacked('data:application/json,{"name":"test"}')
        );
    }
*/
    function hashBlockText(string memory _text) public pure returns (uint256) {
        // pure doesn't read storage state; view reads but doesn't write
        //   nb how ENS do this: const labelHash = utils.keccak256(utils.toUtf8Bytes('vitalik'))
        //   const tokenId = BigNumber.from(labelHash).toString()

        return uint256(keccak256(abi.encodePacked(_text)));
    }

    /*
     * @notice set the baseUru in case of website change.
     * @dev Forms the first part of the `external_url` field in tokenURI.
     */
    function setBaseUri(string calldata _baseUri) external onlyOwner {
        baseUri = _baseUri;
    }

    // The following functions are overrides required by Solidity.
    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    // First of all, abi.encodePacked(_str) will convert the string _str to its UTF-8 bytes representation, and not to bytes32.
    // bytes is a dynamically-sized byte array, as is string. Since Solidity 0.8.5 it’s possible to cast bytes into bytes32, but you need to pay attention because anything beyond 32 bytes will be chopped off.

    // if your string’s UTF-8 bytes representation is 32 bytes or shorter, you can place it in a bytes32 via bytes32(abi.encodePacked(_str)),
    // whereas if your string is longer than 32 bytes, you can compress it into a bytes32 via keccak256(abi.encodePacked(_str)).
    function formatTokenURI(
        string memory _name,
        string memory _description,
        string memory _imageURI
    ) public pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json,",
                    abi.encodePacked(
                        '{"name":"',
                        _name,
                        '", "description": "',
                        _description,
                        '"',
                        ', "image":"',
                        _imageURI,
                        '"}'
                    )
                )
            );
    }

    /*
    function formatTokenURIBase64(
        string memory _imageURI,
        string memory _name,
        string memory _description,
        string memory _properties
    ) public pure returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(
                        bytes(
                            abi.encodePacked(
                                '{"name":"',
                                _name,
                                '", "description": "',
                                _description,
                                '"',
                                ', "attributes": ',
                                _properties,
                                ', "image":"',
                                _imageURI,
                                '"}'
                            )
                        )
                    )
                )
            );
    }*/

    // ??
    function ownerWithdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return baseUri;
    }
}