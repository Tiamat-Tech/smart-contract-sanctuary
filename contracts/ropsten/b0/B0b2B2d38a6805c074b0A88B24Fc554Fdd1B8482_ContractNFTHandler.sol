// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ContractNFTHandler is ERC721 {
    uint256 public tokenCount;
    mapping (uint256 => address) public tokenIdtoAdderss;
    mapping (uint256 => uint256) public tokenPrices;
    mapping (uint256 => bool) public forSale;
    
    struct NFT {
        uint256 id;
        uint256 price;
        bool onSale;
        address contractAddress;
    }
    
    constructor (string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        tokenCount = 1;
    }

    modifier isForSale(uint256 tokenId) {
        require(forSale[tokenId], "Contract is not currently for sale");
        _;
    }

    modifier isOwner(uint256 tokenId) {
        require(msg.sender==ownerOf(tokenId), "ERC721: caller is not owner");
        _;
    }

    function _updateOwnershipInNFT(uint256 tokenId, address to) private {
        tokenIdtoAdderss[tokenId] = to;
    }

    function _burn(uint256 tokenId) internal virtual override {
        _updateOwnershipInNFT(tokenId, address(0));
        delete tokenPrices[tokenId];
        delete forSale[tokenId];
        delete tokenIdtoAdderss[tokenId];
        super._burn(tokenId);
    }
    
    /**
     *  Mint the NFT
     */
    function mint(uint256 price) external {
        require(price > 0, "The price should be greater than 0");
        tokenIdtoAdderss[tokenCount] = msg.sender;
        tokenPrices[tokenCount] = price;
        forSale[tokenCount] = true;
        _safeMint(msg.sender, tokenCount);
        tokenCount++;
    }

    function setPrice(uint256 tokenId, uint256 price) external isOwner(tokenId) {
        tokenPrices[tokenId] = price;
    }

    // Change the sale status of an NFT if the sale status of an NFT is false, it can no longer be pruchased using the purchaseNFT function
    function setSaleStatus(uint256 tokenId, bool saleStatus) external isOwner(tokenId) {
        forSale[tokenId] = saleStatus;
    }

    // Change ownership of an NFT currently on sale
    function purchaseNFT(uint256 tokenId, address to) external payable isForSale(tokenId) {
        uint256 price = tokenPrices[tokenId];
        require(msg.value>=price*(1 wei), "Not enough money");

        // Transfer record of ownership
        address currentOwner = ownerOf(tokenId);
        _transfer(currentOwner, to, tokenId);
        _updateOwnershipInNFT(tokenId, to);

        // Pay the original owner and refund the excess money to the buyer
        address payable owner = payable(ownerOf(tokenId));
        address payable buyer = payable(msg.sender);
        owner.transfer(price);
        buyer.transfer(msg.value-price);

        // Set sale status to false
        forSale[tokenId] = false;
    }

    // Overriding base transfer functions to include _updateOwnershipNFT
    function transferFrom(address from, address to, uint256 tokenId) public virtual override isOwner(tokenId) {
        _transfer(from, to, tokenId);
        _updateOwnershipInNFT(tokenId, to);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override isOwner(tokenId) {
        safeTransferFrom(from, to, tokenId, "");
        _updateOwnershipInNFT(tokenId, to);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override isOwner(tokenId) {
        _safeTransfer(from, to, tokenId, _data);
        _updateOwnershipInNFT(tokenId, to);
    }

    function getAllNFTDetails() public view returns(NFT[] memory) {
        NFT[] memory nftDetails = new NFT[](tokenCount-1);
        for (uint i = 1; i < tokenCount; i++) {
            nftDetails[i-1] = NFT(i, tokenPrices[i], forSale[i], tokenIdtoAdderss[i]);
        }
        return nftDetails;
    }

    function getNFTDetails(uint256 tokenId) public view returns(NFT memory) {
        NFT memory nftDetails = NFT(tokenId, tokenPrices[tokenId], forSale[tokenId], tokenIdtoAdderss[tokenId]);
        return nftDetails;
    }

    function tradeNFT(address from, address to, uint256 tokenId) internal {
        require(from == tokenIdtoAdderss[tokenId], "This is not owner");
        _safeTransfer(from, to, tokenId, "");
        _updateOwnershipInNFT(tokenId, to);
    }

    function tradeNFTs(uint256[] memory _trader1, uint256[] memory _trader2) external {
        uint256 trader1Length = _trader1.length;
        uint256 trader2Length = _trader2.length;
        address trader1Address = tokenIdtoAdderss[_trader1[0]];
        address trader2Address = tokenIdtoAdderss[_trader2[0]];

        for (uint256 i = 0; i < trader1Length; i ++) {
            tradeNFT(trader1Address, trader2Address, _trader1[i]);
        }
       
        for (uint256 j = 0; j < trader2Length; j ++) {
            tradeNFT(trader2Address, trader1Address, _trader2[j]);
        }
    }
}