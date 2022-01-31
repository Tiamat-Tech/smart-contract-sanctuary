pragma solidity ^0.8.2;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
// Initializable,
contract FarmGame is
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable
{
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _tokenIdCounter;

    bool private marketOpen;
    string public uri;
    event SetURI(string _uri);
    mapping(uint256 => address) private sellerOwner;
    mapping(uint256 => uint256) private priceOf;
    event listedonMarket(uint256 nftID, address seller, uint256 price);
    event purchased(uint256 nftID, address seller, uint256 price);

   // constructor() initializer {}

    function __farmGameInit(
        string memory _name,
        string memory _symbol,
        string memory _uri
    ) public initializer {
        __ERC721_init(_name, _symbol);
        __ERC721Enumerable_init();
        __Ownable_init();
        _tokenIdCounter.increment(); //Because we want to starts with 1 nor with 0 nft id
        setURI(_uri);
        marketOpen = true;
    }
    function getPrice(uint256 _nftId)external view returns (uint256){

        return priceOf[_nftId];
    }

    function creditOwner()external payable onlyOwner returns (bool) {
        address payable receiver = payable (owner());
        receiver.transfer(address(this).balance);
        return true;
    }
function closeMarket()external onlyOwner returns (bool) {
            marketOpen = false;
            return true;
    }

    function sellInMarket(uint256 _nftId, uint256 _nftPrice)
        external
        returns (bool)
    {
        require(marketOpen == true,"Market is Closed");
        require(
            ownerOf(_nftId) == _msgSender(),
            "Only owner of the nft can perform this"
        );
        require(_nftPrice > 0, "Price should be greater then Zero");
        _transfer(_msgSender(), address(this), _nftId); //now Transfered to Contract
        sellerOwner[_nftId] = _msgSender();
        priceOf[_nftId] = _nftPrice;
        emit listedonMarket(_nftId, _msgSender(), _nftPrice);
        return true;
    }

    function BuyFromMarket(uint256 _nftId) external payable returns (bool) {
        require(
            ownerOf(_nftId) == address(this),
            "Item not listed for Sale or already Sold"
        );
        require(sellerOwner[_nftId] != _msgSender(),"Cannot Buy My Own Item");
        require(msg.value == priceOf[_nftId], "Amount should be exact");
        require(_msgSender() != address(0),"Cannot transfer to Zero");
        _transfer(address(this), _msgSender(), _nftId); //now Transfered to Contract
        address payable receiver = payable(sellerOwner[_nftId]);
        receiver.transfer(priceOf[_nftId]);
       delete  sellerOwner[_nftId];
         priceOf[_nftId] = 0;
        return true;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return uri;
    }

    function setURI(string memory _uri) public onlyOwner {
        uri = _uri;
        emit SetURI(_uri);
    }

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721Upgradeable, ERC721EnumerableUpgradeable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}