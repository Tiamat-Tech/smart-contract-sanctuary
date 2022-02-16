// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/[email protected]/token/ERC721/ERC721.sol";
import "@openzeppelin/[email protected]/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/[email protected]/security/Pausable.sol";
import "@openzeppelin/[email protected]/access/Ownable.sol";
import "@openzeppelin/[email protected]/utils/Counters.sol";
import "hardhat/console.sol";

/// @custom:security-contact [email protected]
interface PurgedCoinInterface 
{
    function mintFromPurge(address yourAddress, uint256 _amount) external;
    function burnToMint(address yourAddress, uint256 _amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract PurgeGameBeta is ERC721, ERC721Enumerable, Pausable, Ownable
{
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    mapping(uint16 => address) indexAddress;
    mapping(address => uint16) addressIndex;
    uint16 index = 0;

    mapping(uint16 => uint16) public MAPtokenAddress;

    mapping(uint16 => uint32) public tokenTraits;
    mapping(uint16 => uint16) public traitRemaining;
    mapping(uint16 => uint16[]) public traitPurgeAddress;

    //mapping(uint16 => address) public purgeAddress;
    //mapping(address => uint16[]) public tokensPurgedByAddress;

    uint8[] private newRarityMath = [4,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,5,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,4,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3,3];


    uint16 winningTrait;
    address exterminator;

    uint16 public MAPtokens = 40000;


    address private purgedCoinContract;
    uint256 public cost = .0000 ether; 
    uint256 public PrizePool = 0 ether;  
    uint256 public MAPJackpot = 0 ether;
    bool public coinMintStatus = true;
    bool public publicSaleStatus = true;
    bool public REVEAL = true;
    bool public gameOver = false;
    string public baseTokenURI;

    constructor() ERC721("Purge Game Draft", "PURGEGAMEs1") 
    {
        baseTokenURI = "https://ipfs.io/ipfs/QmWeVprCfxX2JaUQsbh82vJdFAsdNDyY63ZsQtcSQ85TsG/";
    }
/*
function randomtest(uint16 _tokenId) view public returns(uint8,uint8,uint8,uint8)
{
    uint256 randomHash = uint256(keccak256(abi.encodePacked(_tokenId)));

    return(rarity(uint8(randomHash % 100), true) * 10 + rarity(uint8((randomHash / 100) % 100), false), rarity(uint8(randomHash/10000 % 100), true) * 10 + rarity(uint8((randomHash / 1000000) % 100), false),rarity(uint8(randomHash / 100000000 % 100), true) * 10 + rarity(uint8((randomHash / 10000000000) % 100), false), rarity(uint8(randomHash/ 100000000000 % 100), true) * 10 + rarity(uint8((randomHash / 10000000000000) % 100), false));
}
*/
    function initAddress() private
    {
        if (addressIndex[msg.sender] == 0)
        {
            index +=1;
            addressIndex[msg.sender] = index;
            indexAddress[index] = msg.sender;
        }
    }

    function rarity(uint16 _tokenId) private view returns(uint8)
    {
        uint8 count = 0;
        uint8 i = 4;
        uint8 ti;
        uint8 traits;
        uint16 randomHash = uint16(uint(keccak256(abi.encodePacked(_tokenId))));
        for(uint8 t = 0; t < 4; t++)
            count = 0;
            i = 4;
            while ((randomHash >> ti * 8) & (0xff >> ti * 8) > i)
            {
                i += newRarityMath[count];
                count++;
            }
            traits += count >> (ti*8);
            ti++;
        return(traits);
    }


    function setTraits(uint16 _tokenId) private
    {
        tokenTraits[_tokenId] = rarity(_tokenId);

        if (_tokenId < 40000)
        {
            addTraitRemaining(uint8(tokenTraits[_tokenId] & 0xff));
            addTraitRemaining(uint8(tokenTraits[_tokenId] & 0xff00));
            addTraitRemaining(uint8(tokenTraits[_tokenId] & 0xff0000));
            addTraitRemaining(uint8(tokenTraits[_tokenId] & 0xff000000));
        }
    }

    function traitsRemaining(uint8 _trait) view public returns(uint16)
    {
        return(traitRemaining[_trait]);
    }

    function addTraitRemaining(uint8 trait) private 
    {
        traitRemaining[trait] += 1;
    }

    function removeTraitRemaining(uint8 trait) private 
    {
       // traitPurgeAddress[trait].push(msg.sender);
        traitRemaining[trait] -=1;
        if (traitRemaining[trait] == 0)
        {
            gameOver = true;
            payout(trait, msg.sender);
            /*
            winningTrait = trait; 
            exterminator = msg.sender; 
            */  
        }
    }

    function payout(uint8 trait, address winner) private
    {
        uint16 totalPurges = uint16(traitPurgeAddress[trait].length - 1);
        uint256 normalPayout = PrizePool / totalPurges;

         payable(winner).transfer((PrizePool - (MAPtokens * cost)) / 10);
        
         for (uint16 i = 0; i < totalPurges; i++)
         { 
             payable(indexAddress[traitPurgeAddress[trait][i]]).transfer(normalPayout);
         }
    }
/*
    function mapRemoveTraitRemaining(uint256 trait) private 
    {
        //uint test = traitPurgeAddress[trait].length;
        traitPurgeAddress[trait].push(msg.sender);
    }
*/

    function newrarity(uint16 entropy) private view returns(uint8)
    {
        uint16 i = 0;
        uint8 count = 0;

            while (entropy > i)
            {
                i += newRarityMath[count];
                count++;
            }

        return(count);
    }



    function setPurgedCoinAddress(address _purgedCoinContract) public onlyOwner
    {
        purgedCoinContract = _purgedCoinContract;
    }


    function purge(uint16[] calldata _tokenIds) public  
    {
        require(gameOver == false, "Game Over");
        require(REVEAL, "No purging before reveal");
        initAddress();
        uint16 _tokenId;
        for(uint16 i = 0; i < _tokenIds.length; i++) 
        {
            _tokenId = _tokenIds[i];
            require(ownerOf(_tokenId) == msg.sender, "You do not own that token");
            require(_tokenId < 65000, "You cannot purge bombs");
            _burn(_tokenId);
            removeTraitRemaining(uint8(tokenTraits[_tokenId] & 0xff));
            removeTraitRemaining(uint8(tokenTraits[_tokenId] & 0xff00));
            removeTraitRemaining(uint8(tokenTraits[_tokenId] & 0xff0000));
            removeTraitRemaining(uint8(tokenTraits[_tokenId] & 0xff000000));
            traitPurgeAddress[uint8(tokenTraits[_tokenId] & 0xff)].push(addressIndex[msg.sender]);
            traitPurgeAddress[uint8(tokenTraits[_tokenId] & 0xff00)].push(addressIndex[msg.sender]);
            traitPurgeAddress[uint8(tokenTraits[_tokenId] & 0xff0000)].push(addressIndex[msg.sender]);
            traitPurgeAddress[uint8(tokenTraits[_tokenId] & 0xff000000)].push(addressIndex[msg.sender]);
            //tokensPurgedByAddress[msg.sender].push(_tokenId);
            emit Purge("Purged",_tokenId, msg.sender);
        }        
        //PurgedCoinInterface(purgedCoinContract).mintFromPurge(msg.sender, _tokenIds.length * cost * 1000);
    }

    function RequireSale(uint16 _number) view private
    {
        require(publicSaleStatus == true, "Not yet");
        require(_number > 0, "You are trying to mint 0");
    }

    function RequireTenMax(uint16 _number) pure private
    {
        require(_number <= 10, "Maximum of 10 mints allowed per transaction");
    }

    function RequireCorrectFunds(uint16 _number) view private
    {
        require(msg.value == _number * cost, "Incorrect funds supplied");
    }

    function RequireCoinFunds(uint16 _number) view private
    {
        require (PurgedCoinInterface(purgedCoinContract).balanceOf(msg.sender) >= _number * cost * 10000, "Not enough $PURGED");
    }

    function addToPrizePool(uint16 _number) private
    {
        PrizePool += cost * _number / 2;
    }

    function newmintAndPurge(uint16 _number) external payable 
    {
        RequireCorrectFunds(_number);
        RequireSale(_number);
        initAddress();
        //PurgedCoinInterface(purgedCoinContract).mintFromPurge(msg.sender, _number * cost * 1000);
        addToPrizePool(_number);
        MAPtokenAddress[MAPtokens] = addressIndex[msg.sender];
        uint16 mapTokenNumber = 40000;
        mapTokenNumber += MAPtokens;
        for(uint16 i= 0; i < _number; i++)
        {
            setTraits(mapTokenNumber); 

            traitPurgeAddress[uint8(tokenTraits[mapTokenNumber] & 0xff)].push(addressIndex[msg.sender]);
            traitPurgeAddress[uint8(tokenTraits[mapTokenNumber] & 0xff00)].push(addressIndex[msg.sender]);
            traitPurgeAddress[uint8(tokenTraits[mapTokenNumber] & 0xff0000)].push(addressIndex[msg.sender]);
            traitPurgeAddress[uint8(tokenTraits[mapTokenNumber] & 0xff000000)].push(addressIndex[msg.sender]);
            MAPtokens ++;
            mapTokenNumber++;
        }
        emit MintAndPurge("mintandpurge",_number,msg.sender);
    }
/*
    function mintAndPurge(uint16 _number) external payable 
    {
        
        RequireCorrectFunds(_number);
        RequireSale(_number);
        initAddress();
        //PurgedCoinInterface(purgedCoinContract).mintFromPurge(msg.sender, _number * cost * 1000);
        addToPrizePoolMAP(_number);
       // addToMapJackpot(_number);
        //_mapTokens();
        uint16 mapTokenNumber = 40000;
       mapTokenNumber += MAPtokens;
        for(uint16 i= 0; i < _number; i++)
        {
            setTraits(mapTokenNumber); 

            traitPurgeAddress[tokenTraits[mapTokenNumber][0] * 10 + tokenTraits[mapTokenNumber][1] + 100].push(addressIndex[msg.sender]);
            traitPurgeAddress[uint16(tokenTraits[mapTokenNumber][2]) * 10 + tokenTraits[mapTokenNumber][3] + 200].push(addressIndex[msg.sender]);
            traitPurgeAddress[tokenTraits[mapTokenNumber][4] * 10 + tokenTraits[mapTokenNumber][5] + 300].push(addressIndex[msg.sender]);
            traitPurgeAddress[tokenTraits[mapTokenNumber][6] * 10 + tokenTraits[mapTokenNumber][7] + 400].push(addressIndex[msg.sender]);
            MAPtokens ++;
            mapTokenNumber++;
        }
        emit MintAndPurge("mintandpurge",_number,msg.sender);
    }
*/


    function coinMintAndPurge(uint16 _number) external 
    {
        RequireSale(_number);
        RequireCoinFunds(_number);
        PurgedCoinInterface(purgedCoinContract).burnToMint(msg.sender, _number * cost * 9000);
        //addToPrizePoolMAP(_number);
       // addToMapJackpot(_number);
        emit MintAndPurge("mintandpurge",_number,msg.sender);
    }

     function mint(uint16 _number) external payable 
     {
        RequireCorrectFunds(_number);
        RequireSale(_number);
        RequireTenMax(_number);
        _mintToken(_number);
        addToPrizePool(_number);
    }


    function coinMint(uint16 _number) external
    {
        require(coinMintStatus == true, "Coin mints not yet available");
        RequireSale(_number);
        RequireTenMax(_number);
        RequireCoinFunds(_number);
        PurgedCoinInterface(purgedCoinContract).burnToMint(msg.sender, _number * cost * 10000);
        _mintToken(_number);
        addToPrizePool(_number);
    }
    
    function _mintToken(uint16 _number) internal
    {
        for (uint16 i = 0; i < _number; i++) 
        {
            uint16 tokenId = uint16(totalSupply() + 1);
            _mint(msg.sender, tokenId);
            setTraits(tokenId);
            emit TokenMinted(tokenId);
        }
    }

    event MintAndPurge(string readme,uint32 indexed number, address indexed _from);
    event TokenMinted(uint256 tokenId);
    event Purge(string readme, uint256 indexed tokenId, address indexed _from);

    function endGame(bool _status) external onlyOwner
    {
        gameOver = _status;
    }

    function setCost(uint _newCost) external onlyOwner 
    {
        cost = _newCost;
    }

    function setCoinMintStatus(bool _status) external onlyOwner
    {
        coinMintStatus = _status;
    }

    function setPublicSaleStatus(bool _status) external onlyOwner 
    {
        publicSaleStatus = _status;
    }

    function reveal(bool _REVEAL, string memory updatedURI) public onlyOwner 
    {
        REVEAL = _REVEAL;
        baseTokenURI = updatedURI;
    }

    function withdrawMyFunds(address payable _to) external onlyOwner 
    {
        require(
            address(this).balance > PrizePool, 
            "No funds to withdraw"
        );
        _to.transfer(address(this).balance - PrizePool);    
    }

    function increasePrizePool() external payable onlyOwner
    {
        require(msg.value > 0);
        PrizePool += msg.value;
    }

     function preparePayouts(address payable _to) external onlyOwner 
     {
        require(address(this).balance > 0);
        require(gameOver);
        _to.transfer(address(this).balance);   
    }

    function payMAPjackpot(uint256 entropy) external onlyOwner
    {
        uint256 randomHash = uint256(keccak256(abi.encodePacked(entropy)));
        uint16 winner = uint16((randomHash % MAPtokens));
        while (MAPtokenAddress[winner] == 0)
        {
            winner -=1;
        }
        address payable winnerAddress = payable(indexAddress[MAPtokenAddress[winner]]);
        PrizePool -= ((MAPtokens - 40000) * cost / 20);
        winnerAddress.transfer((MAPtokens - 40000) * cost / 20);
        //MAPJackpot = 0;
    }

    function pause() public onlyOwner 
    {
        _pause();
    }

    function unpause() public onlyOwner 
    {
        _unpause();
    }


    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) 
    {
        if (_i == 0) 
        {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) 
        {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) 
        {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
/*
    function mapJackpot(uint256 entropy) public pure returns(uint256)
    {
        uint randomHash = uint(keccak256(abi.encodePacked(entropy)));
        return (randomHash % _mapTokens);
    }
*/
    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721) 
    {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721)
        returns (string memory)
    {
            return string(abi.encodePacked(baseTokenURI, uint2str(tokenId)));
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}