pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyNFT is ERC721Enumerable, Ownable {
    bool public hasSaleStarted = false;
    uint256 public constant MAX_NFTS = 111;

    string private _baseTokenURI;

    constructor() ERC721("MyNFT", "MNFT") {}

    function setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        return
            string(abi.encodePacked(_baseTokenURI, Strings.toString(_tokenId)));
    }

    function mint() public returns (uint256) {
        require(totalSupply() < MAX_NFTS, "SOLD OUT");

        uint256 mintIndex = totalSupply();

        _safeMint(msg.sender, mintIndex);

        return mintIndex;
    }

    function startSale() public onlyOwner {
        hasSaleStarted = true;
    }

    function pauseSale() public onlyOwner {
        hasSaleStarted = false;
    }
}