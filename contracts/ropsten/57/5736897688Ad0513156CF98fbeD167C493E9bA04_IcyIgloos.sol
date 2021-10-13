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

    mapping (uint256 => uint256) iglooPenguinPairings;

    uint256 public constant MAX_ELEMENTS = 8888;
    uint256 public constant PRICE = 5 * (10**15);
    uint256 public constant PRICE_FLOOR = (10**10);
    uint256 public constant MAX_BY_MINT = 1;
    uint256 public constant reveal_timestamp = 1627588800; // Thu Jul 29 2021 20:00:00 GMT+0000

    uint256 public lastSoldPrice = PRICE;
    uint256 public lastSaleTime = block.timestamp;    

    // TODO Update Creator Address
    address public constant creatorAddress = 0x88C58C64647611c52Ec31A803A5fB297A43a00B4;
    address public constant devAddress = 0x88C58C64647611c52Ec31A803A5fB297A43a00B4;
    string public baseTokenURI;

    event CreateIgloo(uint256 indexed id);
    event IglooPaired(uint256 iglooId, uint256 penguinId);
    event IglooUnpaired(uint256 iglooId);

    constructor(string memory baseURI) ERC721("IcyIgloos", "PPG") {
        setBaseURI(baseURI);  
        pause(true);
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
        require(msg.value >= price(), "Value below price");

        lastSoldPrice = msg.value;
        console.log(msg.value);
        console.log("lastSoldPrice");
        lastSaleTime = block.timestamp;
        console.log(lastSaleTime);
        console.log("lastSaleTime");

        _mintAnElement(_to);
    }

    // Monitored and creates a blank igloo on server side
    function _mintAnElement(address _to) private {
        uint id = _totalSupply();
        _tokenIdTracker.increment();
        _safeMint(_to, id);
        emit CreateIgloo(id);
    }

    // TODO: Make eeverything 1000X smaller
    function price() public view returns (uint256) {
        // price does not update any state variables. 
        uint256 secondsSinceSale = block.timestamp - lastSaleTime;
        
        console.log(secondsSinceSale);
        console.log("secondsSinceSale");

        uint256 numUpdates = secondsSinceSale / 2;  // update price every 4 minutes
        uint256 currentPrice = lastSoldPrice + lastSoldPrice/10;
        uint256 priceDropAmount = numUpdates * (5 ** 10); 
        
        console.log(priceDropAmount);
        console.log("priceDropAmount");
        
        if (priceDropAmount + PRICE_FLOOR >= currentPrice) {
            return PRICE_FLOOR;
        } else {
            //console.log(currentPrice - priceDropAmount);
            //console.log("returnedPrice");
            return currentPrice - priceDropAmount;
        } 
        // Compute the base-2 logarithm of current price        
        // x = currentPrice;
        // logPrice = 0;
        // if (x >= 2**128) { x >>= 128; logPrice += 128; }
        // if (x >= 2**64)  { x >>= 64; logPrice += 64; }
        // if (x >= 2**32)  { x >>= 32; logPrice += 32; }
        // if (x >= 2**16)  { x >>= 16; logPrice += 16; }
        // if (x >= 2**8)   { x >>= 8; logPrice += 8; }
        // if (x >= 2**4)   { x >>= 4; logPrice += 4; }
        // if (x >= 2**2)   { x >>= 2; logPrice += 2; }
        // if (x >= 2**1)   { logPrice += 1; }

        // currentPrice = 2 ** ((numUpdates * 95 * logPrice) / 100)
        // currentPrice *= (95 ** numUpdates);
        // currentPrice /= (100 ** numUpdates);

        // currentPrice *= (0.95 ** numUpdates);
    }


    function pair(uint256 iglooId, uint256 penguinId) public {
        // require valid igloo ID (0 to 888)

        // require valid penguin ID (0 to 8888)
        
        // require pair doesn't already exist
        
        // require igloo is owned by msg sender
        // require penguin is owned by msg sender

        // pair mapping 

        // if penguin ID is 0, set to special value 8889, because we're using 0 to signify unpaired. TODO probably better way to do this
        if (penguinId == 0) {
            iglooPenguinPairings[iglooId] = 8889;
        } else {
            iglooPenguinPairings[iglooId] = penguinId;
        }
        

        // emit event
        emit IglooPaired(iglooId, penguinId);

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
        _widthdraw(devAddress, balance.mul(35).div(100));
        _widthdraw(creatorAddress, address(this).balance);
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Transfer failed.");
    }

    // Unpair and broadcast event
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable, ERC721Pausable) {
        super._beforeTokenTransfer(from, to, tokenId);

        // if pairing exists, unpair. only complication is if penguin ID 0 is paired... need to figure out that (default mapping value = 0)
        if (iglooPenguinPairings[tokenId] != 0) {
            // unpair by setting pairing to 0. 0 means unpaired, so if penguin ID 0 exists we'll need to give it a special number.
            iglooPenguinPairings[tokenId] = 0;

            // emit event
            emit IglooUnpaired(tokenId);
        }
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
    
}