// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./ERC721Pausable.sol";
import "hardhat/console.sol";

contract IcyIgloos is ERC721Enumerable, Ownable, ERC721Burnable, ERC721Pausable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;

    uint256 public constant MAX_ELEMENTS = 888;
    uint256 public constant PRICE = 3 * 10**16;
    uint256 public constant MAX_BY_MINT = 2;
    uint256 public constant SALES_FREQUENCY_TARGET = 8;
    uint256 public constant PRICE_FLOOR = 1 * 10**18;
    uint256 public constant PRICE_CEILING = 10 * 10**18;

    uint256 public averageSalesFrequency;
    uint256 public lastSoldPrice;
    uint256 public lastSaleTime;

    uint256 public mu = 1 * 10**17; // might need to multiply this by 10**X
    uint256 public alpha = 1 * 10**17; // aggressive price increase
    uint256 public beta = 1 * 10**16; // conservative delta increase


    // uint256 public constant reveal_timestamp = 1627588800; // Thu Jul 29 2021 20:00:00 GMT+0000
    // address public constant creatorAddress = 0x3b234DcfF92e3D67ae7615B1ab56c320C1D8DeFE;

    address public creatorAddress; // set in constructor
    string public baseTokenURI;

    event CreateIgloo(uint256 indexed id);

    constructor(string memory baseURI) ERC721("IcyIgloos", "IIG") {
        setBaseURI(baseURI);
        pause(true);
        lastSoldPrice = PRICE_FLOOR;
        creatorAddress = msg.sender;
    }

    modifier saleIsOpen {
        require(_totalSupply() <= MAX_ELEMENTS, "Sale end");
        if (_msgSender() != owner()) {
            require(!paused(), "Pausable: paused");
        }
        _;
    }
    function _totalSupply() internal view returns (uint) {
        return _tokenIdTracker.current();
    }
    function totalMint() public view returns (uint256) {
        return _totalSupply();
    }
    function mint(address _to, uint256 _count) public payable saleIsOpen {
        uint256 total = _totalSupply();
        require(total + _count <= MAX_ELEMENTS, "Max limit");
        require(total <= MAX_ELEMENTS, "Sale end");
        require(_count <= MAX_BY_MINT, "Exceeds number");
        require(msg.value >= viewPrice(_count), "Value below price");


        lastSaleTime = block.timestamp;
        lastSoldPrice = msg.value;

        for (uint256 i = 0; i < _count; i++) {
            _mintAnElement(_to);
        }
    }
    function _mintAnElement(address _to) private {
        uint id = _totalSupply();
        _tokenIdTracker.increment();
        _safeMint(_to, id);
        emit CreateIgloo(id);
    }

    // Simply views the price, doesn't update any state variables. 
    function viewPrice(uint256 _count) public view returns (uint256) {
        uint256 timeSinceSale = block.timestamp - lastSaleTime;
        uint256 timeSol = 1 * 10**6; // 10**18 = 1, so 10**6 = 1**-12 as per time.sol ... this related to eclipse around the sun?
        uint256 currentSalesFrequency = _count/(timeSinceSale + timeSol); // TODO calculate frequency _count = current num sales, time.sol = 1^-12 for some reason... multiply everything by count?

        if (currentSalesFrequency > SALES_FREQUENCY_TARGET) {
            // gamma = alpha if low price, beta if high, linear interp in between
            uint256 uptickSlope = (beta-alpha)/(PRICE_CEILING-PRICE_FLOOR);
            uint256 priceDiff = lastSoldPrice - PRICE_FLOOR;
            
            
            if (lastSoldPrice > PRICE_CEILING) {
                return _count * (lastSoldPrice + (1+beta)*lastSoldPrice);
            } else {
                uint256 gamma = alpha + (uptickSlope * priceDiff);
                return _count * lastSoldPrice + ((1+gamma)*lastSoldPrice);
            }
        } else {
            // uint256 randomNumber = RandomNumberConsumer(oracleAddress).randomResult(); // figure out how to populate this on the fly
            // uint256 probabilityIncrease = ((averageSalesFrequency/SALES_FREQUENCY_TARGET)/2) * 10**18; // divide to a small number, then multiply by 10^18 to ensure it's on the same scale as randon number from chainlink.
            uint256 downtickSlope = beta * (1 - (averageSalesFrequency/SALES_FREQUENCY_TARGET));

            if (PRICE_FLOOR > ((1-downtickSlope)*lastSoldPrice)) {
                return _count * PRICE_FLOOR;
            } else {
                return _count * ((1-beta)*lastSoldPrice);
            }
        }
    }

    // // TODO implement mechanism to update moving average + currentPrice. Also, where does suggested price come from? This is less an auction that an automatically priced asset.
    // function updatePrice(uint256 timeOfSale, uint256 soldPrice) internal returns (uint256) {
    //     uint256 timeSinceSale = timeOfSale - lastSaleTime;

    //     uint256 timeSol = 1 * 10**6; // 10**18 = 1, so 10**6 = 1**-12 as per time.sol ... this related to eclipse around the sun?
    //     uint256 currentSalesFrequency = _count/(timeSinceSale + timeSol); // _count = current num sales, time.sol = 1^-12 for some reason...
    //     averageSalesFrequency *= (1 - mu);
    //     averageSalesFrequency += (mu * currentSalesFrequency);

    //     if (averageSalesFrequency > SALES_FREQUENCY_TARGET) {
    //         // gamma = alpha if low price, beta if high, linear interp in between
    //         uint256 uptickSlope = (beta-alpha)/(PRICE_CEILING-PRICE_FLOOR);
    //         uint256 priceDiff = currentPrice - PRICE_FLOOR;
            
            
    //         if (currentPrice > PRICE_CEILING) {
    //             currentPrice += (1+beta)*currentPrice;
    //         } else {
    //             uint256 gamma = alpha + (uptickSlope * priceDiff);
    //             currentPrice += (1+gamma)*currentPrice;
    //         }
    //     } else {
    //         // uint256 randomNumber = RandomNumberConsumer(oracleAddress).randomResult(); // figure out how to populate this on the fly
    //         // uint256 probabilityIncrease = ((averageSalesFrequency/SALES_FREQUENCY_TARGET)/2) * 10**18; // divide to a small number, then multiply by 10^18 to ensure it's on the same scale as randon number from chainlink.
    //         uint256 downtickSlope = beta * (1 - (averageSalesFrequency/SALES_FREQUENCY_TARGET));

    //         if (PRICE_FLOOR > ((1-downtickSlope)*currentPrice)) {
    //             currentPrice = PRICE_FLOOR;
    //         } else {
    //             currentPrice = ((1-beta)*currentPrice);
    //         }

    //     }

    //     return currentPrice;
    // }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function walletOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokensId;
    }

    function pause(bool val) public onlyOwner {
        if (val == true) {
            _pause();
            return;
        }
        _unpause();
    }

    function withdrawAll() public payable onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0);
        _widthdraw(creatorAddress, balance);
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Transfer failed.");
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

}