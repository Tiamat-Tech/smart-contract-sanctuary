// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract Beanz is Ownable, ReentrancyGuard, ERC721Enumerable, PaymentSplitter {
    using SafeMath for uint8;
    using SafeMath for uint256;
    using Strings for uint256;

    // Public variables
    uint256 public constant MAX_NFT_SUPPLY = 10000;
    uint256 public MINT_PRICE;
    bool public isPaused = true;
    string public _baseTokenURI;

    // Team
    uint256 public teamSize;

    // Events
    event Mint(address minter, uint256 quantity);

    /**
     * @dev Initialize
     */
    constructor(string memory baseURI, address[] memory team, uint256[] memory shares) 
        PaymentSplitter(team, shares)
        ERC721("Beanz", "BEANZ"){
        _setBaseURI(baseURI);
        teamSize = team.length;
        _setMintPrice(5*10**16);
    }

    /**
     * @dev Gets base url
     */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Sets base url. Set it public in case of any error
     */
    function _setBaseURI(string memory baseURI) public onlyOwner {
        _baseTokenURI = baseURI;
    }

    /**
     * @dev Sets mint price. In case of emergency
     */
    function _setMintPrice(uint256 newPrice) public onlyOwner {
        MINT_PRICE = newPrice;
    }

   /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        return string(abi.encodePacked(_baseURI(), tokenId.toString()));
    }

    /**
    * @dev List NFTs owned by address
    */
    function listNFTs(address _owner) public view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    /**
    * @dev Mints from 1 to 20 NFTs
    */
    function mint(uint256 quantity) external nonReentrant payable {
        if(_msgSender() != owner()){
            require(!isPaused, "Sale is paused");
        }
        require(quantity>= 1 && quantity<= 20, "Amount of minted Beanz at once should be in [1,20] interval");
        require(msg.value >= MINT_PRICE.mul(quantity), "Wrong ETH amount");

        _mintBase(_msgSender(), quantity);
    }

    /**
    * @dev Mints for airdrops
    */
    function mintAirdrop(uint256 quantity, address reciever) external onlyOwner {
        require(quantity>= 1 && quantity<= 20, "Amount of minted Beanz at once should be in [1,20] interval");
        _mintBase(reciever, quantity);
    }

    /**
    * @dev base mint
    */
    function _mintBase(address to, uint256 quantity) private {
        for (uint i=0; i<quantity; i++){
            // no reentrancy
            require(totalSupply() < MAX_NFT_SUPPLY, "Sale has already ended");

            // mint
            uint256 mintIndex = totalSupply();
            _safeMint(to, mintIndex);

        }
        // event
        emit Mint(to, quantity);
    }

    /**
    * @dev Pause
    */
    function setPause(bool val) external onlyOwner {
       isPaused = val;
    }

    /**
     * @dev Withdraw ether from this contract to each team mmeber
    */
   function withdraw() external onlyOwner {
        for (uint256 i = 0; i < teamSize; i++) {
            release(payable(payee(i)));
        }
    }

    fallback() external payable { }
    
    receive() external override payable {}
}