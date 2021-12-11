// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "./RandomlyAssigned.sol";
import "./WithSaleStart.sol";
import "./WithContractMetaData.sol";
import "./WithUnreveal.sol";
import "./WithRecover.sol";

contract NFTTest is ERC721Burnable, ERC721Pausable, RandomlyAssigned, WithSaleStart, WithContractMetaData, WithUnreveal, WithRecover {
    using SafeMath for uint256;

    bool public allowMarketplaceListing = false; // during mint
    uint256 public constant PRICE = 0.05 ether;
    uint256 public constant MAX_MINT_IN_PUBLIC = 3;
    uint256 public constant MAX_MINT_IN_PRIVATE = 3;
    address[] public projectOwners;

    mapping(address => uint8) public whitelist; // to restrict wallets with multiple tickets to mint more than x NFTs

    mapping(address => uint256) public amountMintedInPrivateSale; // to restrict wallets with multiple tickets to mint more than x NFTs
    mapping(address => uint256) public amountMintedInPublicSale; // to restrict wallets with multiple tickets to mint more than x NFTs

    event MintedNFT(uint256 indexed id);
    event ListingAllowed();

    constructor(string memory name_, string memory symbol_, uint256 maxNFTs_, uint256 publicSaleStartDateTime_, string memory contractUri_, string memory cid_,
        address[] memory creatorAddresses_)
    ERC721(name_, symbol_)
    WithSaleStart(publicSaleStartDateTime_)
    WithContractMetaData(contractUri_)
    WithUnreveal(cid_)
    RandomlyAssigned(maxNFTs_, 0)
    {
        pause(true);
        projectOwners = creatorAddresses_;
    }

    modifier saleIsOpen {
        require(tokenCount() <= totalSupply(), "Sale end");
        if (_msgSender() != owner()) {
            require(!paused(), "Pausable: paused");
        }
        _;
    }

    function setAllowListing() external onlyOwner {
        allowMarketplaceListing = true; // one-way toggle
        emit ListingAllowed();
    }

    function setApprovalForAll(address operator, bool approved) public override {
        require(allowMarketplaceListing || tokenCount() == totalSupply(), "Not all minted yet"); // tradeable after minting has finished
        super.setApprovalForAll(operator, approved);
    }

    /**
    * For DApp UX to determine how many NFTs can be minted.
    */
    function allowedMintAmount(address account_) view external returns(uint256) {
        bool isPublicSale = saleStarted();
        if (isPublicSale) {
            return MAX_MINT_IN_PUBLIC.sub(amountMintedInPublicSale[account_]);
        } else {
            uint256 amountMintablePrivate = MAX_MINT_IN_PRIVATE.sub(amountMintedInPrivateSale[account_]);
            uint256 whitelistSpots = whitelist[account_];
            return amountMintablePrivate > whitelistSpots ? whitelistSpots : amountMintablePrivate;
        }
    }

    function mint(uint256 _count) external payable saleIsOpen {
        uint256 total = tokenCount();
        require(_count > 0, "Mint more than 0");
        require(total + _count <= totalSupply(), "Max limit");
        require(msg.value >= price(_count), "Value below price");

        bool isPublicSale = saleStarted();
        if (isPublicSale) {
            amountMintedInPublicSale[_msgSender()] = amountMintedInPublicSale[_msgSender()].add(_count);
            require(amountMintedInPublicSale[_msgSender()] <= MAX_MINT_IN_PUBLIC);
        } else {
            amountMintedInPrivateSale[_msgSender()] = amountMintedInPrivateSale[_msgSender()].add(_count);
            require(amountMintedInPrivateSale[_msgSender()] <= MAX_MINT_IN_PRIVATE);
            // e.g. 3 to mint, 3 mintables per ticket
            require(whitelist[_msgSender()] >= _count, "Not enough tickets");
            whitelist[_msgSender()] = whitelist[_msgSender()] - uint8(_count);
        }

        for (uint256 i = 0; i < _count; i++) {
            _mintSingle(_msgSender());
        }
    }

    function _mintSingle(address _to) private {
        uint id = nextToken();
        _safeMint(_to, id);
        emit MintedNFT(id);
    }

    function price(uint256 _count) public pure returns (uint256) {
        return PRICE.mul(_count);
    }

    function pause(bool val) public onlyOwner {
        if (val == true) {
            _pause();
            return;
        }
        _unpause();
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0);

        uint creatorCount = projectOwners.length;
        for (uint i = 0; i < projectOwners.length; i++) {
            _widthdraw(projectOwners[i], balance.div(creatorCount));
        }
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success,) = _address.call{value : _amount}("");
        require(success, "Transfer failed.");
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721, WithUnreveal) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function _baseURI() internal view virtual override(ERC721, WithUnreveal) returns (string memory) {
        return super._baseURI();
    }
}