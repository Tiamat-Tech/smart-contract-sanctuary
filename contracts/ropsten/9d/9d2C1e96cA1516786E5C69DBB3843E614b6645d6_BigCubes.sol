// Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity >=0.7.0;



import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";


contract BigCubes is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Address for address;


    // project set up
    uint256 public constant MAX_TOKENS = 1000;
    uint256 private price = 0; 
    string private base_url;
    bool public sale_active;
    uint256 public constant MAX_TOKENS_PER_PURCHASE = 20;
    uint public maxNFTPerWallet;


    mapping(address => uint) public mintedNFTs;

    function setSaleState(bool _sale_active) public onlyOwner {
        sale_active = _sale_active;
    }

    function setBaseURI(string memory newUri) public onlyOwner {
        base_url = newUri;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return base_url;
    }


    function startSale(uint _maxNFTPerWallet) external onlyOwner {
        maxNFTPerWallet = _maxNFTPerWallet;
        setSaleState(true);
    }

    function flipSaleStatus() public onlyOwner {
        setSaleState(!sale_active);
    }

    function mint(uint256 _count) external payable {
        uint256 totalSupply = totalSupply();

        require(sale_active, "Sale is not active" );
        require(mintedNFTs[msg.sender] + _count <= maxNFTPerWallet, "maxNFTPerWallet constraint violation");
        require(_count > 0 && _count < MAX_TOKENS_PER_PURCHASE + 1, "Exceeds maximum tokens you can purchase in a single transaction");
        require(totalSupply + _count < MAX_TOKENS + 1, "Exceeds maximum tokens available for purchase");
        require(msg.value >= price.mul(_count), "Ether value sent is not correct");
        require(!_msgSender().isContract(), "Contracts are not allowed");
        
        mintedNFTs[msg.sender] += _count;

        for(uint256 i = 0; i < _count; i++){
            _safeMint(msg.sender, totalSupply + i);
        }
    }
    
        
    function reserveTokens(address _to, uint256 _reserveAmount) public onlyOwner {        
        uint supply = totalSupply();
        for (uint i = 0; i < _reserveAmount; i++) {
            _safeMint(_to, supply + i);
        }
    }
    

    function setPrice(uint256 _newPrice) public onlyOwner() {
        price = _newPrice;
    }

    function getPrice() public view returns (uint256){
        return price;
    }


    
    function tokensByOwner(address _owner) external view returns(uint256[] memory ) {
        uint256 tokenCount = balanceOf(_owner);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 index;
            for (index = 0; index < tokenCount; index++) {
                result[index] = tokenOfOwnerByIndex(_owner, index);
            }
            return result;
        }
    }

    // function withdraw() external onlyOwner {
    //     uint balance = address(this).balance;
    //     uint share1 = balance * 100 / 14 * 3 / 100;
    //     // payable().transfer(share1);
    //     // payable().transfer(balance - share1);
    // }

    // function withdraw() public onlyOwner {
    //     uint256 balance = address(this).balance;
    //     msg.sender.transfer(balance);
    // }


    // function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    //     require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

    //     string memory _tokenURI = _tokenURIs[tokenId];
    //     string memory base = baseURI();

    //     // If there is no base URI, return the token URI.
    //     if (bytes(base).length == 0) {
    //         return _tokenURI;
    //     }
    //     // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
    //     if (bytes(_tokenURI).length > 0) {
    //         return string(abi.encodePacked(base, _tokenURI));
    //     }
    //     // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
    //     return string(abi.encodePacked(base, tokenId.toString()));
    // }


    constructor() ERC721("BigCubes", "CUBES") {}
}