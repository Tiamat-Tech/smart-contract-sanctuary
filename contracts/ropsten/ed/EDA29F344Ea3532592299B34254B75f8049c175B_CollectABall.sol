pragma solidity ^0.8.0;

                                                                                                                                                                                                                                              
                                                                                                                                                                                                                                              
        // CCCCCCCCCCCCC                 lllllll lllllll                                                  tttt                                          AAA                                BBBBBBBBBBBBBBBBB                     lllllll lllllll 
    //  CCC::::::::::::C                 l:::::l l:::::l                                               ttt:::t                                         A:::A                               B::::::::::::::::B                    l:::::l l:::::l 
//    CC:::::::::::::::C                 l:::::l l:::::l                                               t:::::t                                        A:::::A                              B::::::BBBBBB:::::B                   l:::::l l:::::l 
//   C:::::CCCCCCCC::::C                 l:::::l l:::::l                                               t:::::t                                       A:::::::A                             BB:::::B     B:::::B                  l:::::l l:::::l 
//  C:::::C       CCCCCC   ooooooooooo    l::::l  l::::l     eeeeeeeeeeee        ccccccccccccccccttttttt:::::ttttttt                                A:::::::::A                              B::::B     B:::::B  aaaaaaaaaaaaa    l::::l  l::::l 
// C:::::C               oo:::::::::::oo  l::::l  l::::l   ee::::::::::::ee    cc:::::::::::::::ct:::::::::::::::::t                               A:::::A:::::A                             B::::B     B:::::B  a::::::::::::a   l::::l  l::::l 
// C:::::C              o:::::::::::::::o l::::l  l::::l  e::::::eeeee:::::ee c:::::::::::::::::ct:::::::::::::::::t                              A:::::A A:::::A                            B::::BBBBBB:::::B   aaaaaaaaa:::::a  l::::l  l::::l 
// C:::::C              o:::::ooooo:::::o l::::l  l::::l e::::::e     e:::::ec:::::::cccccc:::::ctttttt:::::::tttttt     ---------------         A:::::A   A:::::A         ---------------   B:::::::::::::BB             a::::a  l::::l  l::::l 
// C:::::C              o::::o     o::::o l::::l  l::::l e:::::::eeeee::::::ec::::::c     ccccccc      t:::::t           -:::::::::::::-        A:::::A     A:::::A        -:::::::::::::-   B::::BBBBBB:::::B     aaaaaaa:::::a  l::::l  l::::l 
// C:::::C              o::::o     o::::o l::::l  l::::l e:::::::::::::::::e c:::::c                   t:::::t           ---------------       A:::::AAAAAAAAA:::::A       ---------------   B::::B     B:::::B  aa::::::::::::a  l::::l  l::::l 
// C:::::C              o::::o     o::::o l::::l  l::::l e::::::eeeeeeeeeee  c:::::c                   t:::::t                                A:::::::::::::::::::::A                        B::::B     B:::::B a::::aaaa::::::a  l::::l  l::::l 
//  C:::::C       CCCCCCo::::o     o::::o l::::l  l::::l e:::::::e           c::::::c     ccccccc      t:::::t    tttttt                     A:::::AAAAAAAAAAAAA:::::A                       B::::B     B:::::Ba::::a    a:::::a  l::::l  l::::l 
//   C:::::CCCCCCCC::::Co:::::ooooo:::::ol::::::ll::::::le::::::::e          c:::::::cccccc:::::c      t::::::tttt:::::t                    A:::::A             A:::::A                    BB:::::BBBBBB::::::Ba::::a    a:::::a l::::::ll::::::l
//    CC:::::::::::::::Co:::::::::::::::ol::::::ll::::::l e::::::::eeeeeeee   c:::::::::::::::::c      tt::::::::::::::t                   A:::::A               A:::::A                   B:::::::::::::::::B a:::::aaaa::::::a l::::::ll::::::l
    //  CCC::::::::::::C oo:::::::::::oo l::::::ll::::::l  ee:::::::::::::e    cc:::::::::::::::c        tt:::::::::::tt                  A:::::A                 A:::::A                  B::::::::::::::::B   a::::::::::aa:::al::::::ll::::::l
        // CCCCCCCCCCCCC   ooooooooooo   llllllllllllllll    eeeeeeeeeeeeee      cccccccccccccccc          ttttttttttt                   AAAAAAA                   AAAAAAA                 BBBBBBBBBBBBBBBBB     aaaaaaaaaa  aaaallllllllllllllll
                                                                                                                                                                                                                                              
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract CollectABall is ERC721, ERC721Enumerable, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;

    // Constants
    uint256 public constant MAX_COLLECTION_SIZE = 10000;
    uint256 public constant MINT_PRICE = 0.08 ether;
    uint256 public constant MAX_MINT_QUANTITY = 5;
    address private constant ARTIST_WALLET = 0xCeaA722c627dC44d3E1032BB17adAb829A8986c7;
    address private constant DEV_WALLET = 0x291f158F42794Db959867528403cdb382DbECfA3;
    address private constant FOUNDER_WALLET = 0xCF4164BDc781f8E2BEEF0c5aae48F5Ac113823Eb;
    
    // string public baseURI;
    bool public publicSaleStarted = false;
    bool public presaleStarted = false;
    uint256 public reservedBalls = 30;
    
    // Private
    mapping(address => bool) private _presaleWhiteList;
    mapping(address => uint) private _presaleMintedCount;
    Counters.Counter private _tokenIdCounter;
    Counters.Counter private _reservedBallsClaimed;
    string private baseURI;
    
    event BaseURIChanged(string baseURI);

    constructor() ERC721("Collect-A-Ball NFT", "CAB") { }

    // Modifiers

    modifier publicSaleIsLive() {
        require(publicSaleStarted, "Public sale has not started");
        _;
    }

    modifier presaleIsLive() {
        require(presaleStarted, "Presale has not started or Presale is over");
        _;
    }

    function isOwner() public view returns(bool) {
        return owner() == msg.sender;
    }

    // Mint

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function mint(address _to, uint256 _quantity) public payable publicSaleIsLive {
        uint256 supply = totalSupply();
        require(supply < MAX_COLLECTION_SIZE, "Sold Out");
        require(_quantity > 0, "Need to mint at least one!");
        require(_quantity <= MAX_MINT_QUANTITY, "More than the max allowed in one transaction");
        require(supply + _quantity <= MAX_COLLECTION_SIZE, "Minting would exceed max supply");
        require(msg.value == MINT_PRICE * _quantity, "Incorrect amount of ETH sent");

        for (uint256 i = 0; i < _quantity; i++) {
            _tokenIdCounter.increment();
            _safeMint(_to, _tokenIdCounter.current());
        }
    }

    // MARK: Presale

    function mintPreSale(uint256 _quantity) public payable presaleIsLive {
        require(_presaleWhiteList[msg.sender], "You're are not eligible for Presale");
        require(_presaleMintedCount[msg.sender] <= MAX_MINT_QUANTITY, "Exceeded max mint limit for presale");
        require(_presaleMintedCount[msg.sender]+_quantity <= MAX_MINT_QUANTITY, "Minting would exceed presale mint limit. Please decrease quantity");
        require(totalSupply() <= MAX_COLLECTION_SIZE, "Collection Sold Out");
        require(_quantity > 0, "Need to mint at least one!");
        require(_quantity <= MAX_MINT_QUANTITY, "Cannot mint more than max");
        require(totalSupply() + _quantity <= MAX_COLLECTION_SIZE, "Minting would exceed max supply, please decrease quantity");
        require(_quantity*MINT_PRICE == msg.value, "Incorrect amount of ETH sent");
        
        uint count = _presaleMintedCount[msg.sender];
        _presaleMintedCount[msg.sender] = _quantity + count;
        for (uint256 i = 0; i < _quantity; i++) {
            _tokenIdCounter.increment();
            _safeMint(msg.sender, _tokenIdCounter.current());
        }
    }

    function checkPresaleEligibility(address addr) public view returns (bool) {
        return _presaleWhiteList[addr];
    }
   

    // MARK: onlyOwner

    // function setBaseURI(string memory _uri) public onlyOwner {
    //     baseURI = _uri;
    //     emit BaseURIChanged(baseURI);
    // }

    function setBaseURI(string memory _uri) public onlyOwner {
        baseURI = _uri;
    }

    function addToPresaleWhitelist(address[] memory addresses) public onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0));
            _presaleWhiteList[addresses[i]] = true;
        }
    }

    function removeFromWhitelist(address[] memory addresses) public onlyOwner {
        for(uint256 i = 0; i < addresses.length; i++) {
            _presaleWhiteList[addresses[i]] = false;
        }
    }

    function claimReserved(address addr, uint256 _quantity) public onlyOwner {
        require(_tokenIdCounter.current() < MAX_COLLECTION_SIZE, "Collection has sold out");
        require(_quantity + _tokenIdCounter.current() < MAX_COLLECTION_SIZE, "Minting would exceed 10,000, please decrease your quantity");
        require(_reservedBallsClaimed.current() < reservedBalls, "Already minted all of the reserved balls");
        require(_quantity + _reservedBallsClaimed.current() <= reservedBalls, "Minting would exceed the limit of reserved balls. Please decrease quantity.");

        for(uint256 i = 0; i < _quantity; i++) {
            _tokenIdCounter.increment();
            _mint(addr, _tokenIdCounter.current());
            _reservedBallsClaimed.increment();
        }
    }

    function togglePresaleStarted() public onlyOwner {
        presaleStarted = !presaleStarted;
    }

    function togglePublicSaleStarted() public onlyOwner {
        publicSaleStarted = !publicSaleStarted;
    }

    function contractBalance() public view onlyOwner returns(uint256) {
        return address(this).balance;
    }

    function withdrawAll() public onlyOwner {
        uint256 balance = contractBalance();
        require(balance > 0, "The balance is 0");
        _withdraw(DEV_WALLET, (balance * 15)/100);
        _withdraw(ARTIST_WALLET, (balance * 10)/100);
        _withdraw(FOUNDER_WALLET, contractBalance());
    }

    function _withdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call { value: _amount}("");
        require(success, "failed with withdraw");
    }
    
 // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
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