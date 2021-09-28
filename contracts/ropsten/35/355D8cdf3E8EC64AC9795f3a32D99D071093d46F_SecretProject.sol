pragma solidity ^0.8.7;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract SecretProject is ERC721Enumerable, Ownable, ReentrancyGuard{
    uint256 public constant mintPrice = 0.01 ether;
    uint256 public constant maxSupply = 100;
    uint256 public constant mintLimit = 10;
    uint256 public constant presaleMintLimit = 5;
    uint256 public constant ownerReserveLimit = 20;

    bool public PresaleStarted;
    bool public PublicSaleStarted;

    mapping(address => uint256) public TotalMinted;
    mapping(address => bool) public PresaleWhitelist;
    uint256 public NrOfAddressesInWhitelist;

    string public BaseURI;

    constructor (string memory baseUri) public ERC721("SecretProject", "SP"){
        BaseURI = baseUri;
    }

    function _baseURI() internal view override returns (string memory) {
        return BaseURI;
    }

    function Reserve(uint nr) onlyOwner external{
        require(TotalMinted[_msgSender()] + nr <= ownerReserveLimit, "Cannot reserve more than allowed");
        _mint(nr);
    }

    function PublicMint(uint nr) nonReentrant external payable{
        require(PublicSaleStarted, "Public minting is not active");
        require(nr <= mintLimit, "Cannot mint more than allowed");
        require(TotalMinted[_msgSender()] + nr <= mintLimit, "Mint exceeds max allowed per address");
        require(msg.value >= mintPrice * nr, "Not enough eth send");
        _mint(nr);
    }

    function PresaleMint(uint nr) nonReentrant external payable{
        require(PresaleStarted, "Presale minting is not active");
        require(PresaleWhitelist[_msgSender()], "You are not whitelisted!");
        require(nr <= presaleMintLimit, "Cannot mint more than allowed");
        require(TotalMinted[_msgSender()] + nr <= presaleMintLimit, "Mint exceeds max allowed per address");
        require(msg.value >= mintPrice * nr, "Not enough eth send");
        _mint(nr);
    }

    function _mint(uint nr) private{
        require(totalSupply() < maxSupply, "All tokens have been minted");
        require((totalSupply() + nr) <= maxSupply, "You cannot exceed max supply");
        for(uint256 i = 0; i < nr; i++)
        {
            TotalMinted[_msgSender()] += 1;
            _safeMint(_msgSender(), totalSupply() + 1);
        }
    }

    function TransferEth() onlyOwner external{
        require(address(this).balance > 0, "No eth present");
        (bool onwerTransfer, ) = owner().call{value: address(this).balance}('');
        require(onwerTransfer, "Transfer to owner address failed.");
    }

    function TogglePresaleStarted() onlyOwner external{
        PresaleStarted = !PresaleStarted;
    }

    function TogglePublicSaleStarted() onlyOwner external{
        PublicSaleStarted = !PublicSaleStarted;
    }

    function SetBaseUri(string memory baseUri) onlyOwner external{
        BaseURI = baseUri;
    }

    function AddToWhitelist(address[] memory addresses) onlyOwner external{
        for(uint256 i = 0; i < addresses.length; i++) {
            PresaleWhitelist[addresses[i]] = true;
            NrOfAddressesInWhitelist += 1;
        }
    }

    function RemoveFromWhitelist(address[] memory addresses) onlyOwner external{
        for(uint256 i = 0; i < addresses.length; i++) {
            PresaleWhitelist[addresses[i]] = false;
            NrOfAddressesInWhitelist -= 1;
        }
    }

    function IsOnWhitelist(address account) public view returns(bool){
        return PresaleWhitelist[account];
    }
}