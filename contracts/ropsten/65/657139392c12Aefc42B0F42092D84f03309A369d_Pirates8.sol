// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IBooty {
    function updateReward(address _from, address _to) external;
} 

contract Pirates8 is ERC721, ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    string public PROVENANCE;
    
    //Sale States
    bool public isLegendaryMintActive = false;
    bool public isChestMintActive = false;
    bool public isAllowListActive = false;
    bool public isPublicSaleActive = false;
    
    //Chests
    address public chests;
    mapping(uint256 => bool) public isLegendaryChest;
    
    //Booty
    IBooty public Booty;
    
    //Privates
    string private _baseURIextended;
    mapping(address => uint8) public allowList;
    
    //Constants
    uint256 public constant MAX_SUPPLY = 8;
    uint256 public constant MAX_PUBLIC_MINT = 5;
    uint256 public constant PRICE_PER_TOKEN = 0.09 ether;
    
    constructor() ERC721("Pirates8", "PIRATES8") {
    }
    
    function setProvenance(string memory provenance) public onlyOwner {
        PROVENANCE = provenance;
    }

    //Chest Minting
    function setChests(address chestsAddress) external onlyOwner {
        chests = chestsAddress;
    }
    
    function setLegendaryChests(uint256[] calldata legendaries, bool legendary) external onlyOwner {
        for (uint256 i = 0; i < legendaries.length; i++) {
            isLegendaryChest[legendaries[i]] = legendary;
        }
    }
    
    function setChestMintActive(bool _isChestMintActive) external onlyOwner {
        isChestMintActive = _isChestMintActive;
    }

    function mintWithChest(uint256 chestId, address chestOwner) external {
        uint256 ts = totalSupply();
        require(msg.sender == chests, "Address does not have permission to mint");
        require(isChestMintActive || (isLegendaryMintActive && isLegendaryChest[chestId]), "Chest minting is not active");
        require(ts + 1 <= MAX_SUPPLY, "Purchase would exceed max tokens");

        _safeMint(chestOwner, ts);
    }
    //

    //Allowed Minting
    function setIsAllowListActive(bool _isAllowListActive) external onlyOwner {
        isAllowListActive = _isAllowListActive;
    }

    function setAllowList(address[] calldata addresses, uint8 numAllowedToMint) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            allowList[addresses[i]] = numAllowedToMint;
        }
    }

    function mintAllowList(uint8 numberOfTokens) external payable {
        uint256 ts = totalSupply();
        require(isAllowListActive, "Allow list is not active");
        require(numberOfTokens <= allowList[msg.sender], "Exceeded max available to purchase");
        require(ts + numberOfTokens <= MAX_SUPPLY, "Purchase would exceed max tokens");
        require(PRICE_PER_TOKEN * numberOfTokens <= msg.value, "Ether value sent is not correct");

        allowList[msg.sender] -= numberOfTokens;
        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, ts + i);
        }
    }
    //
    
    //Public Minting
    function setPublicSaleState(bool newState) public onlyOwner {
        isPublicSaleActive = newState;
    }

    function mintNFT(uint numberOfTokens) public payable {
        uint256 ts = totalSupply();
        require(isPublicSaleActive, "Sale must be active to mint tokens");
        require(numberOfTokens <= MAX_PUBLIC_MINT, "Exceeded max token purchase");
        require(PRICE_PER_TOKEN * numberOfTokens <= msg.value, "Ether value sent is not correct");

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _safeMint(msg.sender, ts + i);
        }
    }
    //
    
    //Booty
    function setBooty(address bootyAddress) external onlyOwner {
        Booty = IBooty(bootyAddress);
    }
    
    function transferFrom(address from, address to, uint256 tokenId) public override {
        Booty.updateReward(from, to);
        ERC721.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public override {
        Booty.updateReward(from, to);
        ERC721.safeTransferFrom(from, to, tokenId, data);
    }
    //
    
    function walletOfOwner(address owner) external view returns(uint256[] memory) {
        uint256 tokenCount = balanceOf(owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for(uint256 i; i < tokenCount; i++){
            tokensId[i] = tokenOfOwnerByIndex(owner, i);
        }
        return tokensId;
    }

    //Overrides
    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function setBaseURI(string memory baseURI_) external onlyOwner() {
        _baseURIextended = baseURI_;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }
    //
    
    //Withdraw balance
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
    //
}