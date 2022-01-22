// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";


import './FixedPriceMarketPlace.sol';
import './AuctionMarketPlace.sol';


contract NFTation is Initializable,
                     ERC721Upgradeable,
                     ERC721EnumerableUpgradeable,
                     ERC721URIStorageUpgradeable,
                     OwnableUpgradeable,
                     ERC721BurnableUpgradeable,
                     UUPSUpgradeable {

    using CountersUpgradeable for CountersUpgradeable.Counter;

    //mapp tokenId to Royaty struct
    mapping(uint256 => Royalty) private royalties;

    struct Royalty {
        address receiver;
        uint256 percentage;
    }

    CountersUpgradeable.Counter private _tokenIdCounter;

    mapping(string => bool) private tokenURIsMapping;

    FixedPriceMarketPlace private fixedPriceMarketPlaceContract;
    AuctionMarketPlace private auctionMarketPlaceContract;

    //Upgrade 
    mapping(uint256 => bool) public tokenFirstSaleMapping;


    // +EVENTS --------------------------------------------------
    event TokenBurnt(address owner, uint256 tokenId);
    event TokenCreated(
        address owner,
        uint256 tokenId,
        string tokenURI,
        uint256 royalty
    );
    // -EVENTS --------------------------------------------------

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {}

    function initialize() initializer public {
        __ERC721_init("NFTation", "NFTAT");
        __ERC721Enumerable_init();
        __ERC721URIStorage_init();
        __Ownable_init();
        __ERC721Burnable_init();
        __UUPSUpgradeable_init();
    }

    function initMarketPlaces(address _fixedPriceMarketPlaceContract, address _auctionMarketPlaceContract) public onlyOwner {
        auctionMarketPlaceContract = AuctionMarketPlace(_auctionMarketPlaceContract);
        fixedPriceMarketPlaceContract = FixedPriceMarketPlace(_fixedPriceMarketPlaceContract);
    }

    function isMArketPlacesActiveForAccount() public view returns(bool) {
        return (isApprovedForAll(msg.sender, address(fixedPriceMarketPlaceContract)) &&
                isApprovedForAll(msg.sender, address(auctionMarketPlaceContract)));
    }

    function aprovalMarketPlacesForAccount() public {
        setApprovalForAll(address(fixedPriceMarketPlaceContract), true);
        setApprovalForAll(address(auctionMarketPlaceContract), true);
        //TODO emit event
    }


    function mint(string memory uri, uint256 royaltyPercentage) public {
        require(royaltyPercentage <= 50 && royaltyPercentage >= 0, 'NFTation: invalid royalty');

        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();

        _safeMint(_msgSender(), tokenId);
        _setTokenURI(tokenId, uri);
        _setRoyalty(tokenId, _msgSender(), royaltyPercentage);

        emit TokenCreated(_msgSender(), tokenId, uri, royaltyPercentage);
    }

    // function verifyMint(uint256 _tokenId) public view returns(uint256 royaltyPercentage, string memory tokenURIString){
    //     (,uint256 royaltyPercentage) = royaltyInfo(_tokenId, 100);
    //     tokenURIString = tokenURI(_tokenId);
    //     // return (royaltyPercentage, tokenURIString);
    // }

    function burn(uint256 _tokenId) public override {
        super.burn(_tokenId);

        emit TokenBurnt(_msgSender(), _tokenId);
    }

    function _setTokenURI(uint256 tokenId, string memory tokenURI) internal override {
        require(!tokenURIsMapping[tokenURI], 'NFTation: duplicate URI');
        tokenURIsMapping[tokenURI] = true;

        super._setTokenURI(tokenId, tokenURI);
    }


    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyOwner
        override
    {}

    // The following functions are overrides required by Solidity.
    function _burn(uint256 tokenId)
        internal
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
    {
        _deleteRoyalty(tokenId);
        super._burn(tokenId);
    }

    function _baseURI() internal view override(ERC721Upgradeable) returns (string memory) {
        return "ipfs://";
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable, ERC721URIStorageUpgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    // Set to be internal function _setRoyalty
    // _setRoyalty(uint256,address,uint256) => 0xa70bfbd9
    function _setRoyalty(uint256 _tokenId, address _receiver, uint256 _percentage) internal {
        royalties[_tokenId] = Royalty(_receiver, _percentage);
    }

    function _deleteRoyalty(uint256 _tokenId) internal {
        delete(royalties[_tokenId]);
    }

    // Override for royaltyInfo(uint256, uint256)
    // royaltyInfo(uint256,uint256) => 0x2a55205a
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) public view returns (address receiver, uint256 royaltyAmount) {
        receiver = royalties[_tokenId].receiver;

        // This sets percentages by price * percentage / 100
        royaltyAmount = _salePrice * royalties[_tokenId].percentage / 100;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function test() public {

    }
}