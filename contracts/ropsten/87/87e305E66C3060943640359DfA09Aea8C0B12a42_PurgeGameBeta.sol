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

    mapping(uint16 => address) tokenPurgeAddress;
    mapping(uint16 => uint64) tokenMetadata;

    mapping(uint256 => address) public MAPtokenAddress;
    
    uint256 public MAPtokens;

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

    function setPurgedCoinAddress(address _purgedCoinContract) public onlyOwner
    {
        purgedCoinContract = _purgedCoinContract;
    }


    function encodeTokenId(uint16 _tokenId) private
    {
                // DO SOME SHIT TO ENCODE METADATA
        uint64 randomHash = uint64(uint(keccak256(abi.encodePacked(_tokenId))));
        tokenMetadata[_tokenId] = (randomHash % 84) + (randomHash / 100 % 84) * 100 + (randomHash / 10000 % 84) * 10000 + (randomHash / 100000 % 84) * 100000;
    }

    function readMetadata(uint16 _tokenId) public view returns(uint64)
    {
        return(tokenMetadata[_tokenId]);
    }
/*
    function decodeTokenId(uint64 _tokenId) private view returns(uint8, uint8, uint8, uint8)
    {
        uint8 traitOne = _tokenId % 100000000
        uint8 traitTwo = _tokenId % 100000000000
        uint8 traitThree = _tokenId % 100000000000000
        uint8 traitFour = _tokenId % 100000000000000000
        return(traitOne,traitTwo,traitThree,traitFour)
    }
*/
    function checkForWinner() public view returns(uint16)
{
     uint8[332] memory bigAssArray;
    for(uint16 i=1; i<= totalSupply() + MAPtokens; i++)
    {
        if (isTokenPurged(i) == false)
        {
            uint16 traitOne = uint16(tokenMetadata[i] % 84);
            uint16 traitTwo =  uint16(tokenMetadata[i] / 100 % 84) + 84;
            uint16 traitThree =  uint16(tokenMetadata[i] / 10000 % 84) + 168;
            uint16 traitFour =  uint16(tokenMetadata[i] / 1000000% 84) + 252;
            console.log(traitOne);
            console.log(traitTwo);
            console.log(traitThree);
            console.log(traitFour);
            bigAssArray[traitOne] += 1;
            bigAssArray[traitTwo] += 1;
            bigAssArray[traitThree] += 1;
            bigAssArray[traitFour] += 1;
        }
    }
    for(uint16 i=0 ; i < 332 ; i++)
    {
        if (bigAssArray[i] == 0)
        {
            return(i);
        }
    }
    return(0);
}

    function checkGas() public
    {
        if(checkForWinner() !=0)
        {
            gameOver = true;
        }
    }


    function isTokenPurged(uint16 _tokenId) private pure returns(bool)
    {
        if (_tokenId % 1000000000000000000 == 1)
        {
            return(true);
        }
        else
        {
            return(false);
        }
    }

    function purge(uint16[] calldata _tokenIds) public  
    {
        require(gameOver == false, "Game Over");
        require(REVEAL, "No purging before reveal");
        for(uint16 i = 0; i < _tokenIds.length; i++) 
        {
            uint16 _tokenId = _tokenIds[i];
            require(ownerOf(_tokenId) == msg.sender, "You do not own that token");
            tokenPurgeAddress[_tokenId] = msg.sender;
            tokenMetadata[_tokenId] += 1000000000000000000;
            super._burn(_tokenId);
            emit Purge("Purged",_tokenId, msg.sender);
        }        
        PurgedCoinInterface(purgedCoinContract).mintFromPurge(msg.sender, _tokenIds.length * cost * 1000);
    }

    function devPurge() public onlyOwner 
    {
        uint256 _randomToken = randomtoken();
        address tokenowner = ownerOf(_randomToken);
        PurgedCoinInterface(purgedCoinContract).mintFromPurge(tokenowner, cost * 1000);
        _burn(_randomToken);
        emit Purge("Purged",_randomToken,tokenowner);
    }
    
    function randomtoken() private view returns (uint256) 
    {
        uint randomHash = uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
        return tokenByIndex(randomHash % totalSupply());
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

    function addToPrizePoolMAP(uint16 _number) private
    {
        PrizePool += cost * 9 * _number / 20;
        MAPJackpot += cost * _number / 20;
    }

/*
    function addToMapJackpot(uint16 _number) private
    {
        MAPJackpot += cost * _number / 20;
    }
*/
    function _mapTokens(uint16 _number) private
    {
        MAPtokenAddress[MAPtokens] = msg.sender;
        MAPtokens += _number;
    }

    function mintAndPurge(uint16 _number) external payable 
    {
        RequireCorrectFunds(_number);
        RequireSale(_number);
        PurgedCoinInterface(purgedCoinContract).mintFromPurge(msg.sender, _number * cost * 1000);
        addToPrizePoolMAP(_number);
       // addToMapJackpot(_number);
        emit MintAndPurge("mintandpurge",_number,msg.sender);
    }

    function newmintAndPurge(uint16 _number) external payable 
    {
        RequireCorrectFunds(_number);
        RequireSale(_number);
        PurgedCoinInterface(purgedCoinContract).mintFromPurge(msg.sender, _number * cost * 1000);
        addToPrizePoolMAP(_number);
       // addToMapJackpot(_number);
        _mapTokens(_number);
        emit MintAndPurge("mintandpurge",_number,msg.sender);
    }

    function coinMintAndPurge(uint16 _number) external 
    {
        RequireSale(_number);
        RequireCoinFunds(_number);
        PurgedCoinInterface(purgedCoinContract).burnToMint(msg.sender, _number * cost * 9000);
        addToPrizePoolMAP(_number);
       // addToMapJackpot(_number);
        emit MintAndPurge("mintandpurge",_number,msg.sender);
    }

     function mint(uint16 _number) external payable 
     {
        RequireCorrectFunds(_number);
        RequireSale(_number);
        //RequireTenMax(_number);
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
            encodeTokenId(tokenId);
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
        require(MAPJackpot > 0);
        uint256 randomHash = uint256(keccak256(abi.encodePacked(entropy)));
        uint256 winner = (randomHash % MAPtokens);
        while (MAPtokenAddress[winner] == address(0x0000000000000000000000000000000000000000))
        {
            winner -=1;
        }
        address payable winnerAddress = payable(MAPtokenAddress[winner]);
        winnerAddress.transfer(MAPJackpot);
        MAPJackpot = 0;
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