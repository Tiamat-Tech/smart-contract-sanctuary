pragma solidity ^0.8.0;	
import  "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import  "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
// import  "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "base64-sol/base64.sol";

contract Color is ERC721, Ownable {
    string[] public colors;
    mapping(string => bool) _colorExist;
    uint256 mintPrice = 0.03 ether;

    using Strings for uint256;
        
    // Optional mapping for token URIs
    mapping (uint256 => string) private _tokenURIs;

    // Base URI
    string private _baseURIextended;
    

    constructor() ERC721("Color", 'HEX') public{
    }
    
    function mint(string memory _color, string memory uri) public payable{
        require(msg.value >= mintPrice, "Not Enough Ether");
        require(!_colorExist[_color]);
        colors.push(_color);
        uint _id = colors.length -1;
        _safeMint(msg.sender, _id);
        _colorExist[_color] = true;
        
        _setTokenURI(_id, uri);
    }

    function totalSupply() public view returns (uint) {
        return colors.length;
    }

    function withdraw() public onlyOwner {
        require(address(this).balance > 0, 'No Ether to withdraw');
        payable(owner()).transfer(address(this).balance);
    }

    function svgToImageURI(string memory colorOfSvg ) public pure returns(string memory){
    // String concatenation
    string memory svgString_1 = "<svg width='302' height='302' viewBox='0 0 302 302' fill='none' xmlns='http://www.w3.org/2000/svg'> <rect width='302' height='302' rx='16' fill='";
    string memory svgString_2 = colorOfSvg;
    string memory svgString_3 = "'/></svg>";
    string memory finalString =  string(abi.encodePacked(svgString_1, svgString_2, svgString_3));


    string memory baseURL = "data:image/svg+xml;base64,";
    string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(finalString))));
    string memory imageURI = string(abi.encodePacked(baseURL,svgBase64Encoded));

    return imageURI;
    }

    function formatTokenURI(string memory imageURI) public pure returns(string memory){
        string memory baseURL = "data:application/json;base64,";
        return string (abi.encodePacked(baseURL,
                    Base64.encode(bytes(abi.encodePacked('{"name": "Hex NFT", description:"Own your unique color","attributes": "", "image": "',imageURI,'"}')))));
    }
    
    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
    }
    
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }
    
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }
    
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();
        
        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(base, tokenId.toString()));
    }

}