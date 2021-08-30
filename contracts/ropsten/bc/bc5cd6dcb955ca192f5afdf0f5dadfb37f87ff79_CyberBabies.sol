// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @dev CyberBabies NFT Token, with some nifty features included in the contract directly !
 *  - random token ID generation
 *  - instant reveal after minting
 *  - key babies that will give you access to something very special...
 *  - DAO voting system that will let the community decide which features should be added next
 *  - limited amount to be minted per wallet.
 */
contract CyberBabies is
    ERC721,
    ERC721Enumerable,
    ERC721Burnable,
    Ownable
{
    using SafeMath for uint256;

    // splitting the minting into multiple Series
    // Price will start low for the early birds, and go up as we unlock series 2 and 3 !
    uint256 public constant maxS1Supply = 10;
    uint256 public constant maxS2Supply = 20;
    uint256 public constant maxS3Supply = 30;

    // array of all tokens already minted
    // facilitates the randomization, not used for ownership or enumeration
    uint256[maxS3Supply] private indices;

    // array to be used internally for max supplies
    uint256[4] private maxSupply;
    // index of that array
    uint256 public currentSeries = 1;

    // dev address, if anyone wants to donate to get on my good side
    address public dev = 0x41C8fE8A8e7A6A695890449BC7b153b067fB0986;
    // manager address, no need to donate
    address private _manager;

    // only 4 mints allowed per txn. If you are a parent, you'll understand that this is way too high already
    uint256 public maxMintCountPerTxn = 5;

    //starting off with a nice friendly price
    uint256 public mintPrice = 0.04 ether;

    // some of these babies hold the key to a bright future...
    mapping(uint256 => bool) private keyBabies;

    string public baseUri = "";
    
    bool public saleIsActive = false;

    event ItsYourBirthday(uint256 tokenId, address minter);
    
    event PayOurBills(address to, uint256 amount);

    constructor () ERC721("Cyber Babies", "CYBB") {
        maxSupply[0] = 0;
        maxSupply[1] = maxS1Supply;
        maxSupply[2] = maxS2Supply;
        maxSupply[3] = maxS3Supply;
    }

    // just making sure to take advantage of anyone accidentaly sending to this address.
    receive() external payable {}

    modifier saleIsLive {
        require(saleIsActive == true, "Sale not live");
        _;
    }

    modifier onlyOwnerOrManager() {
        require(owner() == _msgSender() || _manager == _msgSender(), "Caller not the owner or manager");
        _;
    }

    function flipSaleState() public onlyOwnerOrManager {
        saleIsActive = !saleIsActive;
    }

    function setSeries(uint256 newSeries) external onlyOwnerOrManager {
        currentSeries = newSeries;
    }

    function setManager(address manager) external onlyOwnerOrManager {
        _manager = manager;
    }

    // we're going to raise mint price for series 2 and 3.
    function setMintPrice(uint256 newPrice) external onlyOwnerOrManager {
        mintPrice = newPrice;
    }

    // we don't intent on changing the max mint per txn, but better be safe than sorry
    function setMaxMintCountPerTxn(uint256 newMaxMintCount) external onlyOwnerOrManager {
        maxMintCountPerTxn = newMaxMintCount;
    }

    // here so we can update the ipfs link if/when it expires
    function setBaseURI(string memory _URI) external onlyOwnerOrManager {
        baseUri = _URI;
    }

    function setSpecialBabies(uint256[] calldata specialBabies, bool specialStatus ) external onlyOwnerOrManager {
        for (uint i; i < specialBabies.length; i++) {
            keyBabies[specialBabies[i]] = specialStatus;
        }
    }

    function setSpecialBaby(uint256 specialBabyToken, bool specialStatus) external onlyOwnerOrManager {
        keyBabies[specialBabyToken] = specialStatus;
    }


    // let's make sure that the minting process is fair and square.
    // minting will not be in ascending order, so you never know what tokenId you'll get (within a series)
    // but we still have to keep track of all minted tokens and their owners for future airdrops
    
    // select a random number less than the upper bound
    function uniform(uint256 _entropy, uint256 _upperBound) internal pure returns (uint256) {
        require(_upperBound > 0, "UpperBound needs to be >0");
        uint256 negation = _upperBound & (~_upperBound + 1);
        uint256 min = negation % _upperBound;
        uint256 randomNr = _entropy;
        while (true) {
            if (randomNr >= min) {
                break;
            }
            randomNr = uint256(keccak256(abi.encodePacked(randomNr)));
        }
        return randomNr % _upperBound;
    }

     // Generates a pseudo random number based on the transaction params
    function random(uint256 max) internal view returns (uint256 _randomNumber) {
        uint256 randomness = uint256(
            keccak256(
                abi.encode(
                    msg.sender,
                    tx.gasprice,
                    block.number,
                    block.timestamp,
                    blockhash(block.number - 1),
                    block.difficulty
                )
            )
        );
        _randomNumber = uniform(randomness, max);
        return _randomNumber;
    }

    // generates a random index based on what series we're currently on
    // keep track of randomized indexes so that we don't repeat this function in case of collision
    function randomIndex() internal returns (uint256) {
        uint256 tokenId = 0;
        uint256 totalSize = maxSupply[currentSeries] - totalSupply();
        uint256 index = maxSupply[currentSeries - 1] + random(totalSize);

        // if we haven't handed out a token with nr index we that now
        uint256 tokenAtPlace = indices[index];

        // if we havent stored a replacement token...
        if (tokenAtPlace == 0) {
            //... we just return the current index
            tokenId = index;
        } else {
            // else we take the replace we stored with logic below
            tokenId = tokenAtPlace;
        }

        // get the highest token id we havent handed out
        uint256 lastTokenAvailable = indices[totalSize + maxSupply[currentSeries -1] - 1];
        // we need to store a replacement token for the next time we roll the same index
        // if the last token is still unused...
        if (lastTokenAvailable == 0) {
            // ... we store the last token as index
            indices[index] = totalSize + maxSupply[currentSeries -1] - 1;
        } else {
            // ... we store the token that was stored for the last token
            indices[index] = lastTokenAvailable;
        }
        return tokenId + 1;
    }


    // no protection needed, you just have to be ready to take care of these kids !
    function makeBabies(uint256 familySize) external payable saleIsLive {
        require(familySize <= maxMintCountPerTxn, "You're gonna need more than a minivan !");
        require(totalSupply() + familySize <= maxS3Supply, "All babies have been adopted !");
        require(totalSupply() + familySize <= maxSupply[currentSeries], "This series is done, come back soon !");
        require(mintPrice * familySize <= msg.value, "This isn't a charity !");
        require(balanceOf(msg.sender) <= (maxMintCountPerTxn * currentSeries)-familySize, "Leave some for the others!");

        for (uint256 i =0; i < familySize; i++) {
            uint256 tokenId = randomIndex();
            _safeMint(msg.sender, tokenId);
            emit ItsYourBirthday(tokenId, msg.sender);
        }
        
        if (totalSupply() == maxSupply[currentSeries]) {
            currentSeries += 1;
            saleIsActive = !saleIsActive;
        }
    }
    // will be use to gift some babies in our airdrops/raffles
    function reserveBaby(uint tokenId, address receiverAddress) external onlyOwnerOrManager {
        _safeMint(receiverAddress, tokenId);
        emit ItsYourBirthday(tokenId, receiverAddress);
    }

    // some babies are special...
    function amISpecial(uint256 tokenId) external view returns (bool){
        return keyBabies[tokenId];
    }
    
    function whichBabyIsMine(address parent) public view returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(parent);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(parent, i);
        }
        return tokensId;
    }
    
    function withdraw(uint256 amount, address to) public onlyOwnerOrManager {
        require(address(this).balance >= amount, "Insufficient balance");
        Address.sendValue(payable(to), amount);
        emit PayOurBills(to, amount);
    }
    
    

    // Housekeeping the ERC721 functions
    function _baseURI() internal view override(ERC721) returns (string memory) {
        return baseUri;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Storing info on the chain
    function uploadBabiesImage(bytes calldata s) external onlyOwner {}

    function uploadBabiesAttributes(bytes calldata s) external onlyOwner {}
}