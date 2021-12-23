// SPDX-License-Identifier: MIT

pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "./ERC721Enumerable.sol";

contract WatImages is Ownable, ERC721Enumerable, ReentrancyGuard {
    using Strings for uint256;
    using SignatureChecker for address;
    using ECDSA for bytes32;

    struct Image {
        uint256 id;
        string name;
        string description;
        string image;
        uint256 imageHash;
    }

    uint256 public price;
    uint256 public platformFee;

    string public baseTokenURI;

    Image[] public images;

    event SetBaseURI(string baseTokenURI);
    event SetPrice(uint256 price);
    event SetTokenURL(address indexed owner, uint256 tokenId, string url);
    event SetPlatformFee(uint256 platformFee);

    event Mint(address receiver, uint256 tokenId);
    event Withdraw(address receiver, uint256 amount);

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseTokenURI,
        uint256 _price,
        uint256 _platformFee
    ) ERC721(_name, _symbol) {
        price = _price;
        platformFee = _platformFee;
        baseTokenURI = _baseTokenURI;
    }

    // ** PUBLIC VIEW functions **

    /**
     * @dev Returns encoded message hash for mint() function.
     */
    function getMessageHash(
        address _to,
        uint256 _tokenId,
        string memory _tokenName,
        string memory _description,
        string memory _tokenURL,
        uint256 _imageHash
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(
                keccak256(abi.encodePacked(_tokenId, _to)),
                keccak256(abi.encodePacked(_tokenName)),
                keccak256(abi.encodePacked(_description)),
                keccak256(abi.encodePacked(_tokenURL)),
                keccak256(abi.encodePacked(_imageHash))
            ));
    }

    /**
     * @dev Returns encoded message hash for mintBatch() function.
     */

    function getBatchMessageHash(
        address _to,
        uint256[] memory _tokenId,
        string[] memory _tokenName,
        string[] memory _description,
        string[] memory _tokenURL,
        uint256[] memory _imageHash
    ) public pure returns (bytes32) {
        bytes memory sumMessage;

        for (uint256 i = 0; i < _tokenId.length; i++) {
            sumMessage = abi.encodePacked(
                sumMessage,
                keccak256(abi.encodePacked(_tokenId[i])),
                keccak256(abi.encodePacked(_tokenName[i])),
                keccak256(abi.encodePacked(_description[i])),
                keccak256(abi.encodePacked(_tokenURL[i])),
                keccak256(abi.encodePacked(_imageHash[i]))
            );
        }

        return keccak256(
            abi.encodePacked(
                keccak256(abi.encodePacked(_to)),
                keccak256(sumMessage)
            )
        );
    }

    // ** EXTERNAL functions **

    /**
     * @dev Mints one token with defined tokenId.
     */
    function mint(
        bytes calldata _signature,
        address _to,
        uint256 _tokenId,
        string memory _tokenName,
        string memory _description,
        string memory _tokenURL,
        uint256 _imageHash
    ) external payable nonReentrant {
        require(!_exists(_tokenId), "mint: Token already exists");

        require(_verify(getMessageHash(
                _to,
                _tokenId,
                _tokenName,
                _description,
                _tokenURL,
                _imageHash
            ),
            _signature
            ), "mint: Invalid Signature");
        require(msg.value >= price + platformFee, "mint: msg.value too low");
        if (msg.value > price + platformFee) {
            payable(_msgSender()).transfer(msg.value - (price + platformFee));
        }

        _mintToken(_to, _tokenId, _tokenName, _description, _tokenURL, _imageHash);
    }

    /**
     * @dev Mints batch of tokens with defined tokenId.
     */
    function mintBatch(
        bytes calldata _signature,
        address _to,
        uint256[] memory _tokenId,
        string[] memory _tokenName,
        string[] memory _description,
        string[] memory _tokenURL,
        uint256[] memory _imageHash
    ) external payable nonReentrant {
        uint256 length = _tokenId.length;
        // safe gas

        for (uint256 i = 0; i < length; i++) {
            require(!_exists(_tokenId[i]), "mintBatch: Token already exists");
        }

        require(
            length == _tokenName.length &&
            length == _imageHash.length &&
            length == _description.length &&
            length == _tokenURL.length,
            "mintBatch: Unequal lists length"
        );

        require(_verify(getBatchMessageHash(
                _to,
                _tokenId,
                _tokenName,
                _description,
                _tokenURL,
                _imageHash
            ),
            _signature
            ), "mintBatch: Invalid Signature");

        uint256 cost = price * length + platformFee;
        require(msg.value >= cost, "mintBatch: msg.value too low");

        if (msg.value > cost) {
            payable(_msgSender()).transfer(msg.value - cost);
        }

        for (uint256 i = 0; i < length; i++) {
            _mintToken(_to, _tokenId[i], _tokenName[i], _description[i], _tokenURL[i], _imageHash[i]);
        }
    }

    /**
     * @dev Returns array of image by owner.
     */
    function getOwnerImages(address _owner) external view returns (Image[] memory) {
        uint256 balance = balanceOf(_owner);
        // safe gas
        require(balance > 0, "getOwnerImages: invalid balance");

        Image[] memory ownerImages = new Image[](balance);

        for (uint i = 0; i < balance; i++) {
            uint256 tokenIndex = allTokensIndex(tokenOfOwnerByIndex(_owner, i));
            ownerImages[i] = Image(images[tokenIndex].id, images[tokenIndex].name, images[tokenIndex].description, images[tokenIndex].image, images[tokenIndex].imageHash);
        }

        return ownerImages;
    }

    /**
     * @dev Returns info of target tokenId.
     */
    function getTokenData(uint256 _tokenId) external view returns (Image memory) {
        require(_exists(_tokenId), "getTokenData: Nonexistent token");

        uint256 tokenIndex = allTokensIndex(_tokenId);

        return images[tokenIndex];
    }

    /**
     * @dev Set URL to target tokenId.
     */
    function setTokenURL(uint256 _tokenId, string memory _url) external nonReentrant {
        require(_exists(_tokenId), "setTokenURL: nonexistent token");
        require(_msgSender() == ownerOf(_tokenId), "setTokenURL: you are not owner");

        uint256 tokenIndex = allTokensIndex(_tokenId);
        images[tokenIndex].image = _url;

        emit SetTokenURL(_msgSender(), _tokenId, _url);
    }

    // ** ONLY OWNER functions **

    /**
     * @dev Set baseTokenURI.
     */
    function setBaseURI(string memory _uri) external onlyOwner {
        baseTokenURI = _uri;

        emit SetBaseURI(_uri);
    }

    /**
     * @dev Set the price.
     */
    function setPrice(uint256 _price) external onlyOwner {
        price = _price;

        emit SetPrice(_price);
    }

    /**
     * @dev Set platform fee by admin
     */
    function setPlatformFee(uint256 _platformFee) external onlyOwner {
        platformFee = _platformFee;

        emit SetPlatformFee(_platformFee);
    }

    /**
     * @dev Withdraws all ETH to caller's address.
     */
    function withdrawAll() external payable onlyOwner {
        payable(_msgSender()).transfer(address(this).balance);

        emit Withdraw(_msgSender(), address(this).balance);
    }

    // ** INTERNAL functions **

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function _mintToken(address _to, uint256 _tokenId, string memory _tokenName, string memory _description, string memory _tokenURL, uint256 _imageHash) internal {
        _safeMint(_to, _tokenId);
        images.push(Image(_tokenId, _tokenName, _description, _tokenURL, _imageHash));

        emit Mint(_to, _tokenId);
    }

    function _verify(bytes32 hash, bytes calldata signature) internal view returns (bool) {
        return owner().isValidSignatureNow(hash.toEthSignedMessageHash(), signature);
    }
}