// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "base64-sol/base64.sol";

contract FroggyFarm is ERC721, Pausable, AccessControl, ERC721Burnable {
    using Counters for Counters.Counter;

    
    string internal constant splitThisString =  '123456';

    event Mint(
        address indexed _to,
        uint256 indexed _tokenId
    );


    
    

    bytes32 public keyHash;
    string public storedScripts;
    string public storedSVG;
    // string public scriptHEAD;
    // string public scriptTAIL;
    //bytes32 public tokenHash;
    mapping(uint256 => bytes32) public tokenIdToHash;
    mapping(bytes32 => uint256) public hashToTokenId;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;

    

    constructor() ERC721("Froggy Farm", "FF1") {
        //_grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        //_grantRole(PAUSER_ROLE, msg.sender);
        //_grantRole(MINTER_ROLE, msg.sender);

        bytes32 hash = keccak256(abi.encodePacked(block.number, blockhash(block.number - 1), msg.sender));
        keyHash = hash;
    }

    //function pause() public onlyRole(PAUSER_ROLE) {
    //    _pause();
    //}

    //function unpause() public onlyRole(PAUSER_ROLE) {
    //    _unpause();
    //}

    /* function safeMint(address to, string memory uri) public onlyRole(MINTER_ROLE) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    } */

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
       require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
       return formatSVG(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }





    // Custom Functions
//Minting
function forward(uint256 tokenId) public view returns (bytes32) {
        bytes32 theHash = bytes16 (tokenIdToHash[tokenId]) << 128;
        
        return theHash;
        
       
    }


function startMint(address to) public {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        bytes32 hash = keccak256(abi.encodePacked(keyHash, msg.sender, block.number));
        tokenIdToHash[tokenId]=hash;
        hashToTokenId[hash] = tokenId;
        _safeMint(to, tokenId);
        emit Mint(to, tokenId);
    }



//Stores NFT javascript
    function addScript (string memory nftScript) public {
        storedScripts = nftScript;
        
    }
//Stores script heading and tail tags like <html> and <script>, may not be needed
    // function addScriptTopTail (string memory scriptTop, string memory scriptBot) public {
    //     scriptHEAD = scriptTop;
    //     scriptTAIL = scriptBot;

    // }

    function addSVG (string memory SVGstring) public {
        storedSVG = SVGstring;
    }
//Should take in token id like this: formatScript (uint256 tokenId) and vew associated token hash, temporarily will just use keyHash in script
//    function _baseURI() internal view override returns (string memory) {
//        
//        return formatScript();
//    }

   


    

    function formatSVG (uint256 tokenId) public view returns (string memory){

        string memory hashyString = string(abi.encodePacked("<svg id='mySvg' onload='loadUp()' xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' shape-rendering='crispEdges'><script><![CDATA[let tokenData={'hash':'",toHexA(tokenId),"'};"));
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory uriScript = string(abi.encodePacked(hashyString,storedScripts));
        string memory scriptBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(uriScript))));
        string memory fullString = string(abi.encodePacked(baseURL,scriptBase64Encoded));
        return formatTokenURI(fullString);
        //return uriScript;
    }

    
//returns a string version of the entire token hash as is.
    function toHexA (uint256 tokenId) public view returns (string memory) {
        return string (abi.encodePacked ("0x", toHex16 (bytes16 (tokenIdToHash[tokenId])), toHex16 (bytes16 (tokenIdToHash[tokenId] << 128))));
    }

//slices a string up begin being the starting character in the string, end being the stop point string 'abcdef' w start of 1 and end of 3 would return 'abc' start of 2 end of 6 would return bcdef
    function getSlice(uint256 begin, uint256 end) public pure returns (string memory) {

        bytes memory a = new bytes(end-begin+1);
        for(uint i=0;i<=end-begin;i++){
            a[i] = bytes(splitThisString)[i+begin-1];
        }
        return string(a);    
    }

    function toHex16 (bytes16 data) public pure returns (bytes32 result) {
    result = bytes32 (data) & 0xFFFFFFFFFFFFFFFF000000000000000000000000000000000000000000000000 |
          (bytes32 (data) & 0x0000000000000000FFFFFFFFFFFFFFFF00000000000000000000000000000000) >> 64;
    result = result & 0xFFFFFFFF000000000000000000000000FFFFFFFF000000000000000000000000 |
          (result & 0x00000000FFFFFFFF000000000000000000000000FFFFFFFF0000000000000000) >> 32;
    result = result & 0xFFFF000000000000FFFF000000000000FFFF000000000000FFFF000000000000 |
          (result & 0x0000FFFF000000000000FFFF000000000000FFFF000000000000FFFF00000000) >> 16;
    result = result & 0xFF000000FF000000FF000000FF000000FF000000FF000000FF000000FF000000 |
          (result & 0x00FF000000FF000000FF000000FF000000FF000000FF000000FF000000FF0000) >> 8;
    result = (result & 0xF000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000) >> 4 |
          (result & 0x0F000F000F000F000F000F000F000F000F000F000F000F000F000F000F000F00) >> 8;
    result = bytes32 (0x3030303030303030303030303030303030303030303030303030303030303030 +
           uint256 (result) +
           (uint256 (result) + 0x0606060606060606060606060606060606060606060606060606060606060606 >> 4 &
           0x0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F0F) * 7);
    }


    

    function formatTokenURI(string memory fullString) public pure returns (string memory) {
        return string(abi.encodePacked("data:application/json;base64,",Base64.encode(bytes(abi.encodePacked('{"name":"sweet green baby boy", "description":"love this little guy", "attributes":[], "image":"',fullString,'"}')))));
    }

    


    
}