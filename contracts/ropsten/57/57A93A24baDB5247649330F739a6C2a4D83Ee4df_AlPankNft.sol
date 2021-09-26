// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "@openzeppelin/contracts/utils/Counters.sol";
//import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
//import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
//import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract AlPankNft is Ownable, ERC721
{
    
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    
    string private _currentNftURI;
    string private _currentBaseURI;
    
    struct Metadata {
        string imgId;
        uint256 tokenIdToPrice;
        address tokenIdToTokenAddress;
        string title;
        string url;
    }

    mapping(uint256 => Metadata) id_to_date;

    constructor() ERC721("APN", "AL-PANK-NFT") {
        setNftURI("http://localhost:3000/");
        setBaseURI("http://localhost:3000/token/");
        string memory mintUriNft = string(abi.encodePacked(_currentNftURI, "images/panks/01.jpg"));
        mint("01", 0.005 ether, msg.sender, "ORIGIN", mintUriNft);
    }
    
    function mint(string memory imgId, uint256 tokenIdToPrice, address tokenIdToTokenAddress, string memory title, string memory url) internal {
        _tokenIds.increment();
        
        uint256 newTokenId = _tokenIds.current();
        id_to_date[newTokenId] = Metadata(imgId, tokenIdToPrice, tokenIdToTokenAddress, title, url);
        _safeMint(msg.sender, newTokenId);
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        _currentBaseURI = baseURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _currentBaseURI;
    }
    
    function setNftURI(string memory nftURI) public onlyOwner {
        _currentNftURI = nftURI;
    }

    /*function _nftURI() internal view virtual override returns (string memory) {
        return _currentNftURI;
    }*/

    function buyNftAlPank(string memory imgId, string memory title, string memory url) external payable {
        require(msg.value == 0.005 ether, "claiming a date costs 10 finney");
        bool _isImgId = isImgId(imgId);
        require(_isImgId != true, "Al-Pank NFT Token busy");

        mint(imgId, 0.005 ether, msg.sender, title, url);
        payable(owner()).transfer(0.005 ether);
    }

    /*    
    function ownerOf(string memory title) public view returns(address) {
        return ownerOf(id(year, month, day));
    }
    
    function ownerOf(string memory url) public view returns(address) {
        return ownerOf(id(year, month, day));
    }
    */

    /*function id(uint16 year, uint8 month, uint8 day) pure internal returns(uint256) {
        require(1 <= day && day <= numDaysInMonth(month, year));
        return (uint256(year)-1)*372 + (uint256(month)-1)*31 + uint256(day)-1;
    }*/
    
    /*function transfer(address _to, uint256 _tokenId) public {

        require(msg.sender == id_to_date[_tokenId].tokenIdToTokenAddress);
        id_to_date[_tokenId].tokenIdToTokenAddress = _to;
        emit Transfer(msg.sender, _to, _tokenId);
    }*/

    function get(uint256 tokenId) external view returns (string memory imgId, uint256 tokenIdToPrice, address tokenIdToTokenAddress, string memory title, string memory url) {
        require(_exists(tokenId), "token not minted");
        Metadata memory date = id_to_date[tokenId];
        imgId = date.imgId;
        tokenIdToPrice = date.tokenIdToPrice;
        tokenIdToTokenAddress = date.tokenIdToTokenAddress;
        title = date.title;
        url = date.url;
    }
    
    function isImgId(string memory imgId) internal view returns (bool) {
        bool _isImgId = false;
        uint256 count_nft = getCounterLast();
        for (uint256 i=1; i <=count_nft; i++) {

            if (id_to_date[i].tokenIdToTokenAddress != address(0)) {
                Metadata memory nft_data = id_to_date[i];
                
                bool isId = (keccak256(abi.encodePacked((nft_data.imgId))) == keccak256(abi.encodePacked((imgId))));
                if (isId) {
                    _isImgId = true;
                }
            }
        }
        
        return _isImgId;
    }
    
    function getCounterLast() internal view returns (uint256) {
        return _tokenIds.current();
    }

    function titleOf(uint256 tokenId) external view returns (string memory) {
        require(_exists(tokenId), "token not minted");
        Metadata memory date = id_to_date[tokenId];
        return date.title;
    }
    
    function urlImgOf(uint256 tokenId) external view returns (string memory) {
        require(_exists(tokenId), "token not minted");
        Metadata memory date = id_to_date[tokenId];
        return date.url;
    }

    function changeTitleOf(uint256 tokenId, string memory title) public {
        require(_exists(tokenId), "token not minted");
        require(ownerOf(tokenId) == msg.sender, "only the owner of this date can change its title");
        id_to_date[tokenId].title = title;
    }

    function timestampToDate(uint timestamp) public pure returns (uint16 year, uint8 month, uint8 day) {
        uint z = timestamp / 86400 + 719468;
        uint era = (z >= 0 ? z : z - 146096) / 146097;
        uint doe = z - era * 146097;
        uint yoe = (doe - doe/1460 + doe/36524 - doe/146096) / 365;
        uint doy = doe - (365*yoe + yoe/4 - yoe/100);
        uint mp = (5*doy + 2)/153;

        day = uint8(doy - (153*mp+2)/5 + 1);
        month = mp < 10 ? uint8(mp + 3) : uint8(mp - 9);
        year = uint16(yoe + era * 400 + (month <= 2 ? 1 : 0));
    }

    function pseudoRNG(uint16 year, uint8 month, uint8 day, string memory title) internal view returns (uint256) {
        return uint256(keccak256(abi.encode(block.timestamp, block.difficulty, year, month, day, title)));
    }
}