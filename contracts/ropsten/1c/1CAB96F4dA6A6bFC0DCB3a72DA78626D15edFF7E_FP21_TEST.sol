// SPDX-License-Identifier: MIT

/******************************************************************/
/******************************************************************/
/******************************************************************
                                                            
                                                            
                     %@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@    
                @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@    
             @@@@@@@@      @@@@@      %@@@@@@@@             
          @@@@@@@          @@@@@           @@@@@@           
        @@@@@@             @@@@@             %@@@@@         
       @@@@@               @@@@@               (@@@@@       
     %@@@@/                @@@@@                 @@@@@      
     @@@@                  @@@@@                  @@@@@     
    @@@@@                  @@@@@                   @@@@     
    @@@@                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@    
    @@@@                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@    
    @@@@                   @@@@@                   @@@@@    
    @@@@@                  @@@@@                   @@@@     
     @@@@%                 @@@@@                  @@@@@     
      @@@@@                @@@@@                 @@@@@      
       @@@@@               @@@@@               @@@@@@       
        &@@@@@             @@@@@             @@@@@@         
          #@@@@@@          @@@@@          @@@@@@@           
             @@@@@@@@@     @@@@@     &@@@@@@@@              
                 @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@    
                       @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@    
                                                            

                        sangil MMXXI


/******************************************************************/
/******************************************************************/
/******************************************************************/


// 6, 512   
// 4, 512
// 1, 512

// 0x6c7EbefDf6C6fBe86C1fed71d06Abc757aCc946A
// 0xADfB5cFECD9150F8Ca08ceCb22117C628328939e

/* RINKEBY
etherscan:
https://rinkeby.etherscan.io/address/0x363ca019f72C50B9a97752D46b2DeC9259D4a378#readContract
*/


pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./FP21Interface_TEST.sol";

contract FP21_TEST is ReentrancyGuard, ERC721Enumerable, FP21Interface_TEST {
    using Strings for uint256;

    //uint256 constant MAX_NUM_SERIES = 10;
    uint256 constant SERIES_SHIFT   = 10;
    //uint256 constant MAX_ATTRIBUTE_VALUE = 1026;
    string  constant KEY_SEP = "-";
    
    address public admin;
    address public test;

    // mapping (uint256 => string)    private _tokenURIs;
    mapping (uint256 => uint256)   private _variation;
    

    // set actual base URI here
    string private _baseTokenURI = "https://young-sierra-45454.herokuapp.com/"; 

    // number of base images
    //uint256 private _numSeries;

    // number of copies per series (same base image, different attribute values)
    uint256 private _copiesPerSeries;

    // the max value each attribute can have
    uint256 private _maxVariationValue;
    
    // array of all the tokenIds, to map between index and id
    uint256[] private _tokenIdArray;

    uint8[] private _series;
    uint8 private _lastModifiedSeries = 0;

    uint256 private _nonce;
    
    event Created(address indexed to, uint256 tokenId);
    event Modified(address indexed owner, uint256 tokenId);
    event Transfered(address indexed owner, address indexed to, uint256 tokenId);

    /*****************************************************************************/
    /******************************** constructor ********************************/
    /*****************************************************************************/
    constructor(
        //uint256 numSeries,
        uint256 copiesPerSeries,
        uint256 maxVariationValue   
    ) ERC721("fp21_test", "FP21_TEST") {
        require(copiesPerSeries > 0   && copiesPerSeries < SERIES_SHIFT,     "copiesPerSeries must be between 1 and 10");
        require(maxVariationValue > 0);// && maxVariationValue <= MAX_ATTRIBUTE_VALUE,   "maxAttributeValue must be between 1 and 10");

        admin = msg.sender;

        _copiesPerSeries    = copiesPerSeries;        
        _maxVariationValue  = maxVariationValue;
        _nonce              = 0;
        
        // Joker series
        _series.push(1);
    }


    /*****************************************************************************/
    /***************************** external methods ******************************/
    /*****************************************************************************/
     /*
     * calldata is a non-modifiable, non-persistent area where function arguments 
     * are stored, and behaves mostly like memory.
     */
    function setBaseURI(string calldata baseURI) external nonReentrant {
        require(_isValidAddr(msg.sender), 'only admin');

        _baseTokenURI = baseURI;
    }

    function getBaseURI() external view
    returns (string memory) {        
        return _baseTokenURI;
    }

    /*****************************************************************************/
    /*********************** overridden inherited methods ************************/
    /*****************************************************************************/
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721Enumerable) returns (bool) {
        return interfaceId == type(FP21Interface_TEST).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /*
    * format: baseURI/series-variation
    * the overridden base function returns the string (baseURI + tokenId)
    */
    function tokenURI(uint256 tokenId) public view virtual override 
    returns (string memory) {
        require(_exists(tokenId), "Nonexistent token");      

        //return string(abi.encodePacked(_baseURI(), _tokenURIs[tokenId]));
        
        return string(abi.encodePacked(
            _baseURI(),
            _getSeriesByTokenId(tokenId).toString(),
            KEY_SEP,
            _variation[tokenId].toString()
        ));
    }

    function transferFrom(address from, address to, uint256 tokenId) 
    public virtual override(ERC721, IERC721) {
        require(from == ownerOf(tokenId));

        super.transferFrom(from, to, tokenId);

        emit Transfered(from, to, tokenId);
        _modifyAll();
    } 

    function safeTransferFrom(address from, address to, uint256 tokenId) 
    public virtual override(ERC721, IERC721) {
        require(from == ownerOf(tokenId));

        super.safeTransferFrom(from, to, tokenId);

        emit Transfered(from, to, tokenId);
        _modifyAll();
    }

    function transfer(address from, address to, uint256 tokenId) public override nonReentrant {
        safeTransferFrom(from, to, tokenId);
    }

    /*****************************************************************************/
    /**************************** public API methods *****************************/
    /*****************************************************************************/
    function mintSeries(uint8 num_copies) public override {
         require(_isValidAddr(msg.sender), 'only admin');
         require(num_copies > 0, "0 copies");
         require(num_copies <= _copiesPerSeries, "invalid number of copies");
         
         uint256 s_index = _series.length;
         
         _series.push(num_copies);
         
         for (uint j = 1; j <= num_copies; j++) {
            uint256 tokenId = _getTokenId(s_index, j);
     
            /* mint a new token */
            create(tokenId);   
         }
    }
    
    function create(uint256 tokenId) public override {
        require(_isValidAddr(msg.sender), 'only admin');
        require(!_exists(tokenId), "tokenId already exists");

        _tokenIdArray.push(tokenId);

        /* _safeMint() makes sure if a contract is called, it must support onERC721Received  */
        _safeMint(admin, tokenId);   

        emit Created(admin, tokenId);
    }

// 6, 512   
// 4, 512
// 1, 512
/* GE REMOVE - TEST */
    /*****************************************************************************/
    
    
            
    event TestAddrSet(address indexed test);
    
    function mintSeries() public {
        mintSeries(uint8(_copiesPerSeries));
    }
    
    function modifyAll() public {
        require(_isValidAddr(msg.sender), 'only admin');
        
        _modifyAll();
    }
    
    function getAllTokenIds() public view 
    returns (uint256[] memory) {
        require(_isValidAddr(msg.sender), 'only admin');

        return _tokenIdArray;
    }

    function getVariationByTokenId(uint256 tokenId) public view 
    returns (uint256) {
        require(_exists(tokenId), "no token associated with this tokenId");

        return _variation[tokenId];
    }

    function getNonce() public view     
    returns (uint256) {
        return _nonce;
    }
    
    function incrementNonce() public  {
        require(_isValidAddr(msg.sender), 'only admin');
        _nonce++;
    }

    function setTestAddr(address testAddr) public  {
        require(_isValidAddr(msg.sender), 'only admin');

        test = testAddr;

        emit TestAddrSet(test);
    }

    function getTestAddr() public view  
    returns (address) {
        return test;
    }
    
    function getRandomSeries() public view
    returns (uint8) {
        return Util.randomNumber(_nonce, _series.length);
    }
    
    function getRandomNumber() public view
    returns (uint8) {
        return Util.randomNumber(_nonce);
    }
    
    function getRandomNumber(uint256 max) public view
    returns (uint8) {
        return Util.randomNumber(_nonce, max);
    }
    
    function allVariations() public view
    returns(uint256[20] memory) {
        uint256 numTokens = _tokenIdArray.length;
        
        uint256[20] memory variations;
        
        for (uint i = 0; i < numTokens; i++) {
            uint256 tokenId = _tokenIdArray[i];
            uint256 v = _variation[tokenId];
            
            variations[i] = v;
        }
        
        return variations;
    }
    
// 6, 512   
// 4, 512
// 1, 512
    
    /*****************************************************************************/
    /************************* internal/private methods **************************/
    /*****************************************************************************/
    function _baseURI() internal view override 
    returns (string memory) {
        return _baseTokenURI;
    }

    function _getTokenId(uint256 seriesIndex, uint256 copyIndex) internal pure
    returns (uint256) {

        return ((seriesIndex) * SERIES_SHIFT) + copyIndex;
    }

    function _getSeriesByTokenId(uint256 tokenId) internal pure
    returns (uint256) {
        uint256 copyIndex = (tokenId % SERIES_SHIFT);

        return (tokenId - copyIndex) / SERIES_SHIFT;
    }

    function _modify(uint256 tokenId) internal {
        // require(_isValidAddr(msg.sender), 'only admin');
        require(_exists(tokenId), "no token associated with this tokenId");

        /* randomly generate new variation */
        _variation[tokenId] = Util.randomNumber(_nonce, _maxVariationValue);
        _nonce++;                  

        emit Modified(admin, tokenId);
    }

    function _modifyAll() internal {        
        for (uint i = 0; i < _tokenIdArray.length; i++) {
            uint256 tokenId = _tokenIdArray[i];

            _modify(tokenId);
        }
    }

    function _isValidAddr(address addr) internal view 
    returns(bool) {
        return addr == admin || addr == test;        
    }
    
    function _isValidSeries(uint256 s_index) internal view
    returns(bool) {
        return _series.length < s_index;
    }
}

// 6, 512   
// 4, 512
// 1, 512

/************************************************************/
/************************************************************/
/************************************************************/
library Util {
    function randomNumber(uint256 nonce, uint256 maxValue) internal view
    returns (uint8) {
        return uint8(randomNumber(nonce) % (maxValue));
    }
    
    function randomNumber(uint256 nonce) internal view
    returns (uint8) {
        return uint8(
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp, 
                        block.difficulty, 
                        block.number, 
                        nonce
                    )
                )
            ) 
        ); 
    }
}