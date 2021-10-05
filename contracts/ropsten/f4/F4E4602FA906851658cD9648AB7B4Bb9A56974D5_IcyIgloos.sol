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

    // 10 ** 18 = 1 for scaling...

    uint256 public constant MAX_ELEMENTS = 888;
    uint256 public constant SALES_FREQUENCY_TARGET = 20 * 10**18; // 20/hr scaled up by factor of 1000
    uint256 public constant PRICE_FLOOR = 1 * 10**18;
    uint256 public constant PRICE_CEILING = 10 * 10**18;

    uint256 public averageSalesFrequency;

    uint256 public lastSoldPrice;
    uint256 public lastSaleTime;

    uint256 public mu = 10; // divide by MU == multiply * 0.1
    uint256 public alpha = 10; // price += price/alpha == 10% increase
    uint256 public beta = 33; // price += price/beta == 3.0% delta increase increase


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
    function mint(address _to) public payable saleIsOpen {
        uint256 total = _totalSupply();
        require(total + 1 <= MAX_ELEMENTS, "Max limit");
        require(total <= MAX_ELEMENTS, "Sale end");
        require(msg.value >= viewPrice(), "Value below price");


        uint256 secondsSinceSale = (block.timestamp - lastSaleTime) * 1000;
        uint256 hoursSinceSale = secondsSinceSale/3600;
        uint256 timeSol = 1 * 10**6; // avoids divide by 0

        uint256 currentSalesFrequency = 1000/(hoursSinceSale + timeSol); // scaled by 1000

        averageSalesFrequency *= (1-mu);
        averageSalesFrequency += (mu * currentSalesFrequency);

        lastSaleTime = block.timestamp;
        lastSoldPrice = msg.value;

        _mintAnElement(_to);
    }
    function _mintAnElement(address _to) private {
        uint id = _totalSupply();
        _tokenIdTracker.increment();
        _safeMint(_to, id);
        emit CreateIgloo(id);
    }

    // Simply views the price, doesn't update any state variables. 
    function viewPrice() public view returns (uint256) {
        
        uint256 secondsSinceSale = (block.timestamp - lastSaleTime) * 10**18;
        uint256 hoursSinceSale = secondsSinceSale/3600;
        uint256 numUpdates = 1 + secondsSinceSale/(60 * 10**18); // happens every minute and scaled

        uint256 priceToReturn = lastSoldPrice;

        for (uint256 i = 0; i < numUpdates; i++) {
            
            uint256 currentSalesFrequency = 10**36/(hoursSinceSale); // add 18 additional digits for precision

            // multiply by 0.9
            uint256 copyAverageSalesFrequency = averageSalesFrequency - (averageSalesFrequency/mu);

            // add .1 * current
            copyAverageSalesFrequency += (currentSalesFrequency/mu);
            



            if (currentSalesFrequency > SALES_FREQUENCY_TARGET) {
                // gamma = alpha if low price, beta if high, linear interp in between

                if (lastSoldPrice > PRICE_CEILING) {
                    priceToReturn = lastSoldPrice + (lastSoldPrice/beta);
                } else {

                    // uint256 gamma = alpha + (7 * priceDiff/900); // 10 + 7
                    uint256 gamma = 20;
                    priceToReturn = lastSoldPrice + (lastSoldPrice/gamma); // used to be multiplied by gamma
                }
            } else {

                uint256 updatedPrice = lastSoldPrice - ((lastSoldPrice/beta) * (SALES_FREQUENCY_TARGET - averageSalesFrequency)/SALES_FREQUENCY_TARGET);

                if (PRICE_FLOOR > updatedPrice) {
                    priceToReturn = PRICE_FLOOR;
                } else {
                    priceToReturn = updatedPrice;
                }
            }
        }

        return priceToReturn;
        
    }

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