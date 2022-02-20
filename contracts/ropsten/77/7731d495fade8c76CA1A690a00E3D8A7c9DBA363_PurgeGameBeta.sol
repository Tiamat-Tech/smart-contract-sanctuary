// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/[email protected]/token/ERC721/ERC721.sol";
import "@openzeppelin/[email protected]/access/Ownable.sol";
//import "hardhat/console.sol";

/// @custom:security-contact [email protected]
interface PurgedCoinInterface 
{
    function mintFromPurge(address yourAddress, uint256 _amount) external;
    function burnToMint(address yourAddress, uint256 _amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract PurgeGameBeta is ERC721, Ownable
{
    
    bool paidJackpot;
    bool public coinMintStatus = true;
    bool public publicSaleStatus = true;
    bool public REVEAL = false;
    bool public gameOver;

    uint16 offset;
    uint16 bombNumber = 65001;
    uint16 nuke = 65535;
    uint16 totalMinted;
    uint16 index;
    uint16 public MAPtokens;
    
    uint32 revealTime;

    address private purgedCoinContract;
    
    uint16[256] traitRemaining;

    mapping(uint16 => uint16) MAPtokenAddress;
    mapping(uint16 => uint24) tokenTraits;
    mapping(uint16 => uint16[]) traitPurgeAddress;
    mapping(uint16 => address) indexAddress;
    mapping(address => uint16) addressIndex;


    string public baseTokenURI;
    uint256 public cost = .0001 ether; 
    uint256 public PrizePool = 0 ether;

    constructor() ERC721("Purge Game Draft", "PURGEGAMEs1") 
    {
        baseTokenURI = "https://ipfs.io/ipfs/QmWeVprCfxX2JaUQsbh82vJdFAsdNDyY63ZsQtcSQ85TsG/";
    }


    function initAddress() private
    {
        if (addressIndex[msg.sender] == 0)
        {
            index +=1;
            addressIndex[msg.sender] = index;
            indexAddress[index] = msg.sender;
        }
    }
/*
    function rarity(uint16 _tokenId) private view returns(uint24)
    {
        uint8 count;
        uint8 i;
        uint24 traits;
        uint randomHash;
        for(uint8 t = 0; t < 4; t++)
        {
            randomHash = uint32(uint(keccak256(abi.encodePacked(_tokenId))));
            count = 0;
            i = 4;
            while ((randomHash >> (t * 8)) & 0x1f > i)
            {
                i += RarityMath[count];
                count++;
            }
            count += uint8(((randomHash >> (t * 8 + 5)) & 0x7) << 3);
            traits += uint24(count) << t * 6;
        }
        return(traits);
    }
*/

    function rarity(uint16 _tokenId) private pure returns(uint24)
    {
        uint24 result;
        uint32 randomHash = uint32(uint(keccak256(abi.encodePacked(_tokenId))));
        result = getTraitFromUint8(uint8(randomHash));
        result += getTraitFromUint8(uint8(randomHash >> 8)) << 6;
        result += getTraitFromUint8(uint8(randomHash >> 16)) << 12;
        result += getTraitFromUint8(uint8(randomHash >> 24)) << 18;
        return result;
    }

    function getTraitFromUint8(uint8 _input) private pure returns(uint24) 
    {
        if(_input < 120) return _input / 5;
        if(_input < 192) return 24 + (_input - 120) / 3;
        return 48 + (_input - 192) / 4;
    } 

    function setTraits(uint16 _tokenId) private
    {
        tokenTraits[_tokenId] = rarity(_tokenId);

        if (_tokenId < 40000)
        {
            addTraitRemaining(uint8(tokenTraits[_tokenId] & 0x3f));
            addTraitRemaining(uint8((tokenTraits[_tokenId] & 0xfc0) >> 6) + 64);
            addTraitRemaining(uint8((tokenTraits[_tokenId] & 0x3f000) >> 12) + 128);
            addTraitRemaining(uint8((tokenTraits[_tokenId] & 0xfc0000) >> 18) + 192);      
        }
    }
/*
    function returnTraits(uint16 _tokenId) public view returns(uint24,uint24)
    {
        return(tokenTraits[_tokenId], tokenTraits[realTokenId(_tokenId)]);
    }

    function traitsRemaining(uint8 _trait) view public returns(uint16)
    {
        return(traitRemaining[_trait]);
    }
*/
    function addTraitRemaining(uint8 trait) private 
    {
        traitRemaining[trait] += 1;
    }

    function removeTraitRemaining(uint8 trait) private 
    {
      
        traitRemaining[trait] -=1;

        if (traitRemaining[trait] == 0)
        {
            if (gameOver = false)
            {/*
                gameOver = true;
                if (nuke != 65535) {payout(trait,indexAddress[nuke]);}
                else {payout(trait, msg.sender);}   
                */ 
            }
        }

    }

    function payout(uint8 trait, address winner) private
    {
        require(PrizePool > 0);
        uint16 totalPurges = uint16(traitPurgeAddress[trait].length - 1);
        uint256 normalPayout = PrizePool / totalPurges;

         payable(winner).transfer((PrizePool - (MAPtokens * cost / 20)) / 10);
        
         for (uint16 i = 0; i < totalPurges; i++)
         { 
             payable(indexAddress[traitPurgeAddress[trait][i]]).transfer(normalPayout);
         }
         PrizePool = 0;
    }


    function setPurgedCoinAddress(address _purgedCoinContract) public onlyOwner
    {
        purgedCoinContract = _purgedCoinContract;
    }


    function purge(uint16[] calldata _tokenIds) public  
    {
        
        require(gameOver == false, "Game Over");
        //require(REVEAL, "No purging before reveal");
        initAddress();
        uint16 _tokenId;
        for(uint16 i = 0; i < _tokenIds.length; i++) 
        {
            _tokenId = realTokenId(_tokenIds[i]);
            require(ownerOf(_tokenId) == msg.sender, "You do not own that token");
            require(_tokenId < 65000, "You cannot purge bombs");
            _burn(_tokenId);
            purgeWrite(_tokenId);
            removeTraitRemaining(uint8(tokenTraits[_tokenId] & 0x3f));
            removeTraitRemaining(uint8((tokenTraits[_tokenId] & 0xfc0) >> 6) + 64);
            removeTraitRemaining(uint8((tokenTraits[_tokenId] & 0x3f000) >> 12) + 128);
            removeTraitRemaining(uint8((tokenTraits[_tokenId] & 0xfc0000) >> 18) + 192); 
           
            emit Purge(_tokenId, msg.sender);
        }        
        PurgedCoinInterface(purgedCoinContract).mintFromPurge(msg.sender, _tokenIds.length * cost * 1000);
    }

    function bombAirdrop(uint32 entropy) public onlyOwner
    {
        /*
        if (bombNumber == 50001) {require(block.timestamp > revealTime + 1209600);}
        else {require(block.timestamp > revealTime + 86400);}
        */
        uint16 randomHash = uint16(uint(keccak256(abi.encodePacked(entropy))));
        uint16 winner = randomHash % index;
        _mint(indexAddress[winner],bombNumber);
        bombNumber +=1;
        revealTime = uint32(block.timestamp);
    }

    function nukeToken(uint16 bombTokenId, uint16 targetTokenId) public
    {
        bombTokenId = realTokenId(bombTokenId);
        targetTokenId = realTokenId(targetTokenId);
        require(bombTokenId > 65000);
        require(targetTokenId <= 39420);
        require(ownerOf(bombTokenId) == msg.sender);
        _burn(bombTokenId);
        if (addressIndex[ownerOf(targetTokenId)] == 0)
        {
            index +=1;
            addressIndex[ownerOf(targetTokenId)] = index;
            indexAddress[index] = ownerOf(targetTokenId);
        }
        nuke = addressIndex[ownerOf(targetTokenId)];
        traitPurgeAddress[uint8(tokenTraits[targetTokenId] & 0x3f)].push(nuke);
        traitPurgeAddress[uint8(tokenTraits[targetTokenId] & 0xfc0)].push(nuke);
        traitPurgeAddress[uint8(tokenTraits[targetTokenId] & 0x3f000)].push(nuke);
        traitPurgeAddress[uint8(tokenTraits[targetTokenId] & 0xfc0000)].push(nuke);
        _burn(targetTokenId); 
        removeTraitRemaining(uint8(tokenTraits[targetTokenId] & 0x3f));
        removeTraitRemaining(uint8((tokenTraits[targetTokenId] & 0xfc0) >> 6) + 64);
        removeTraitRemaining(uint8((tokenTraits[targetTokenId] & 0x3f000) >> 12) + 128);
        removeTraitRemaining(uint8((tokenTraits[targetTokenId] & 0xfc0000) >> 18) + 192);
        PurgedCoinInterface(purgedCoinContract).mintFromPurge(indexAddress[nuke], cost * 1000);
        emit Purge(targetTokenId, indexAddress[nuke]);
        nuke = 65535;
    }

    function RequireSale(uint16 _number) view private
    {
        require(publicSaleStatus == true, "Not yet");
        //require(REVEAL == false);
        require(_number > 0, "You are trying to mint 0");
    }

    function RequireTenMax(uint16 _number) view private
    {
        require(_number <= 10, "Maximum of 10 mints allowed per transaction");
        require(totalMinted + _number < 39421, "Max 39420 tokens");
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

    function mintAndPurge(uint16 _number) external payable 
    {
        RequireCorrectFunds(_number);
        codeMintAndPurge(_number);
        PurgedCoinInterface(purgedCoinContract).mintFromPurge(msg.sender, _number * cost * 1000);

    }

    function codeMintAndPurge(uint16 _number) private
    {
        RequireSale(_number);
        require(MAPtokens + _number < 24421, "24420 max Mint and Purges");
        initAddress();
        addToPrizePool(_number);
        MAPtokenAddress[MAPtokens] = addressIndex[msg.sender];
        uint16 mapTokenNumber = 40000;
        mapTokenNumber += MAPtokens;
        for(uint16 i= 0; i < _number; i++)
        {
            setTraits(mapTokenNumber); 
            purgeWrite(mapTokenNumber);
            emit MintAndPurge(mapTokenNumber, tokenTraits[mapTokenNumber], msg.sender);
            mapTokenNumber++;
        }
        MAPtokens += _number;
       
    }

    function purgeWrite(uint16 _tokenId) private
    {
            traitPurgeAddress[uint8(tokenTraits[_tokenId] & 0x3f)].push(addressIndex[msg.sender]);
            traitPurgeAddress[uint8(tokenTraits[_tokenId] & 0xfc0)].push(addressIndex[msg.sender]);
            traitPurgeAddress[uint8(tokenTraits[_tokenId] & 0x3f000)].push(addressIndex[msg.sender]);
            traitPurgeAddress[uint8(tokenTraits[_tokenId] & 0xfc0000)].push(addressIndex[msg.sender]);
    }


    function coinMintAndPurge(uint16 _number) external 
    {
        RequireCoinFunds(_number);
        PurgedCoinInterface(purgedCoinContract).burnToMint(msg.sender, _number * cost * 9000);
        codeMintAndPurge(_number);
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
        for (uint16 i = 1; i <= _number; i++) 
        {
            uint16 tokenId = totalMinted + i;
            _mint(msg.sender, tokenId);
            setTraits(tokenId);
            emit TokenMinted(tokenId, tokenTraits[tokenId]);
        }
        totalMinted += _number;
    }

    function offsetRandomizer(uint32 entropy) public onlyOwner
    {
        require(offset == 0);
        offset = uint16(uint(keccak256(abi.encodePacked(entropy))) % (totalMinted - 100) + 50);     
    }

    function returnOffset() public view onlyOwner returns(uint16)
    {
        return(offset);
    }

    function realTokenId(uint16 _tokenId) private view returns(uint16)
    {
        if (offset != 0)
        {
            if (_tokenId < 40000)
            {
                if (_tokenId + offset < totalMinted) return(_tokenId + offset);
                else return(offset);
            }
            /*
            if (_tokenId < 65000)
            {
                if (_tokenId + offset < MAPtokens) return(_tokenId + offset);
                else return(offset + 40000);
            }
            */
        }
        return(_tokenId);
    }

    event MintAndPurge(uint16 tokenId, uint24 indexed tokenTraits, address indexed _from);
    event TokenMinted(uint16 tokenId, uint24 indexed tokenTraits);
    event Purge(uint256 tokenId, address indexed _from);
/*
    function endGame(bool _status) external onlyOwner
    {
        gameOver = _status;
    }
*/
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
        require(REVEAL == false);
        REVEAL = _REVEAL;
        baseTokenURI = updatedURI;
        revealTime = uint32(block.timestamp);
    }

    function withdrawMyFunds(address payable _to) external onlyOwner 
    {
        require(address(this).balance > PrizePool, "No funds to withdraw");
        _to.transfer(address(this).balance - PrizePool);    
    }

    function payMAPjackpot(uint256 entropy) external onlyOwner
    {
        require(paidJackpot == false);
        uint256 randomHash = uint256(keccak256(abi.encodePacked(entropy)));
        uint16 winner = uint16((randomHash % MAPtokens));
        while (MAPtokenAddress[winner] == 0)
        {
            winner -=1;
        }
        address payable winnerAddress = payable(indexAddress[MAPtokenAddress[winner]]);
        PrizePool -= MAPtokens * cost / 20;
        winnerAddress.transfer(MAPtokens * cost / 20);
        paidJackpot == true;
    }


    function _beforeTokenTransfer(address from, address to, uint16 tokenId)
        internal
       // override(ERC721)
    {
        super._beforeTokenTransfer(from, to, realTokenId(tokenId));
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

    function totalSupply() public view returns(uint16)
    {
        return(totalMinted + MAPtokens);
    }
    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721) 
    {
        super._burn(tokenId);
    }

    function tokenURI(uint16 tokenId)
        public
        view
       // override(ERC721)
        returns (string memory)
    {
            return string(abi.encodePacked(baseTokenURI, uint2str(realTokenId(tokenId))));
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}