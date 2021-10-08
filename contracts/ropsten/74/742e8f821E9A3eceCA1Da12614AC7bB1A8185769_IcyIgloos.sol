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
    using SafeMath for int256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdTracker;

    uint256 public constant MAX_ELEMENTS = 880;       // igloos to sell at first minting
    uint256 public constant SALES_FREQUENCY_TARGET = 20 * 10**18; // sell ~35 igloos/hr
    uint256 public constant PRICE_FLOOR = 10**18;     // reservation price = 1 ETH
    uint256 public constant PRICE_HIGH = 10**19;      // soft ceiling price = 10 ETH
    uint256 public constant PRICE_UPDATE_FREQ = 3600; // update price at least once every 5 minutes

    uint256 public salesFreqAve = SALES_FREQUENCY_TARGET;
    uint256 public lastSoldPrice;
    uint256 public lastSaleTime;

    uint256 public mu = 10;    // moving average weight, divide by MU == multiply * 0.1
    uint256 public alpha = 10; // price += price/alpha == 10% increase
    uint256 public beta = 33;  // price += price/beta == 3% delta increase increase

    // uint256 public constant reveal_timestamp = 1627588800; // Thu Jul 29 2021 20:00:00 GMT+0000
    // address public constant creatorAddress = 0x3b234DcfF92e3D67ae7615B1ab56c320C1D8DeFE;

    address public creatorAddress; // set in constructor
    string public baseTokenURI;

    event CreateIgloo(uint256 indexed id);

    constructor(string memory baseURI) ERC721("IcyIgloos", "IIG") {
        setBaseURI(baseURI);
        pause(true);
        lastSoldPrice = PRICE_FLOOR;
        lastSaleTime = block.timestamp - 1;
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
        console.log("Entered mint function");
        
        uint256 total = _totalSupply(); 
        require(total + 1 <= MAX_ELEMENTS, "Max limit"); 
        require(total <= MAX_ELEMENTS, "Sale end"); 
        require(msg.value >= viewPrice(), "Value below price"); 

        uint256 secondsSinceSale = (block.timestamp - lastSaleTime) * (10**18); 
        uint256 hoursSinceSale = secondsSinceSale/3600; 
        uint256 timeTol = 10**10; // Tolerance for numerical stability in division
        uint256 currentSalesFrequency = (10**36) / (hoursSinceSale + timeTol);

        salesFreqAve -= salesFreqAve / mu;
        salesFreqAve += currentSalesFrequency / mu;

        console.log(salesFreqAve / (10**18));
        console.log("Updated salesFreqAve");

        lastSaleTime = block.timestamp; 
        lastSoldPrice = msg.value;

        _mintAnElement(_to);
        console.log("Completed mint function");
    }
    function _mintAnElement(address _to) private {
        uint id = _totalSupply();
        _tokenIdTracker.increment();
        _safeMint(_to, id);
        emit CreateIgloo(id);
    }


    function viewPrice() public view returns (uint256) {
        // purpose: Output current price
        // 
        // output: priceToReturn - Current price of igloo,
        //                         updated by price tick(s)
        //                         up or down, depending on
        //                         how quickly igloos sell
        //
        // notes: viewPrice does not update any state variables. 
        //
        //        Times and frequencies are normalized so 
        //        1 hour == 10 ** 18 and 1 / hour = 10 ** 18
        //
        //        Frequencies are stored as exp moving averages and
        //        most recent estimate is salesFreqCurr.
        //
        //        When igloos sell quickly, aggressive/conservative
        //        price upticks happen if price is low/high. Interpolation
        //        of percentage uptick occurs for medium prices
        //
        //        During prices of no igloo sales, price will continue to 
        //        update according to "numUpdates", which is set to update
        //        ~1 time per ethereum block update, and number of updates
        //        will always be at least one to handle the case when igloos
        //        are minted at high frequency.

        uint256 secondsSinceSale = (block.timestamp - lastSaleTime) * 10**18;
        console.log("Seconds since sale below");
        console.log(block.timestamp);
        uint256 hoursSinceSale = secondsSinceSale / 3600;

        bool noTimeSinceSale = hoursSinceSale < 1;
        if (noTimeSinceSale) {             
            return lastSoldPrice;
        }        
        
        uint256 numUpdates = 1 + (PRICE_UPDATE_FREQ * hoursSinceSale) / (10**18);                
        uint256 currentPrice = lastSoldPrice;
        uint256 salesFreqCurr = 10**36 / hoursSinceSale;               
        uint256 salesFreqAveCopy = salesFreqAve;

        // Loop to update price periodically (in addition to whenever mint occurs)
        for (uint256 i = 0; i < numUpdates; i++) {            
            
            salesFreqAveCopy -= (salesFreqAve/mu);
            salesFreqAveCopy += (salesFreqCurr/mu);

            // Check if selling faster than baseline target
            if (salesFreqAveCopy > SALES_FREQUENCY_TARGET) {                
                if (lastSoldPrice > PRICE_HIGH) {
                    currentPrice = currentPrice + (currentPrice/beta);                   
                } else {
                    // Low/Medium Price + Fast Sales --> Aggressive/Conservative Uptick
                    uint256 gamma = alpha;
                    gamma += ((beta - alpha) * (currentPrice - PRICE_FLOOR)) / (PRICE_HIGH - PRICE_FLOOR); 
                    currentPrice += currentPrice / gamma;            
                }
            } else {
                // add 1 for numerical stability (divide by zero erros)
                uint256 freqDiff = 1 + (SALES_FREQUENCY_TARGET - salesFreqAveCopy);
                uint256 gamma = beta * (SALES_FREQUENCY_TARGET / freqDiff);
                currentPrice -= currentPrice / gamma;
            }
        }

        // Ensure price always complies with reservation price
        if (currentPrice < PRICE_FLOOR){
            return PRICE_FLOOR;
        } else {
            return currentPrice;
        }
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