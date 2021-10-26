// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


//ProCoreNFT Contract

contract ProCoreNFT is ERC721, ERC721Enumerable, ERC721Burnable, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    uint256 public MINT_PRICE = 1e16 gwei; // 0.01 eth
    uint256 public maxTokenSupply = 10000;
    uint256 public MAX_MINTS_PER_TXN = 10;
    bool public SALE_IS_ACTIVE = false;
    uint256 public OWNER_SHARE = 3;
    string public baseURI;

    address[3] private _shareholders;

    event PaymentReleased(address to, uint256 amount);
    event SharesUpdated(uint256 oShares);

    constructor() public ERC721("ProCoreNFT", "PCNFT") {
        _shareholders[0] = 0x73C93932aDD9863B12B56d2A734674f19d14D514; // Owner
        _shareholders[1] = 0xc816E96873fCa8f5586699CbBe06f8312Bd7eF39; // ProCoreNFT
    }

    function mintNFT(address recipient, string memory tokenURI, uint256 numberOfTokens)
        public payable
    {
        require(SALE_IS_ACTIVE, "Sale not active.");
        require(numberOfTokens <= MAX_MINTS_PER_TXN, "Only 10 at a time.");
        //require(_totalSupply() + numberOfTokens <= maxTokenSupply, "Purchase would exceed max available planets");
        require(MINT_PRICE * numberOfTokens <= msg.value, "Ether value sent is not correct");

        //Mint the requested NFT's
        _tokenIds.increment();
        for(uint256 i; i < numberOfTokens; i++){
            uint256 newItemId = _tokenIds.current();
            _safeMint(recipient, newItemId);
            //setTokenURI(newItemId, tokenURI);
            _tokenIds.increment();
        }

        //Forward funds
        forwardFunds(msg.value);
    }

    function forwardFunds(uint256 funds) internal {
        uint256 ownerShare = funds.div(OWNER_SHARE);
        uint256 projectShare = funds.sub(ownerShare);

        (bool successOwnerShare, ) = _shareholders[0].call{value: ownerShare}("");
        require(successOwnerShare, "Funds Error Owner.");

        (bool successProjectShare, ) = _shareholders[1].call{value: projectShare}("");
        require(successProjectShare, "Funds Error Project.");

        emit PaymentReleased(_shareholders[0], ownerShare);
        emit PaymentReleased(_shareholders[1], projectShare);
    }

    function setShares(uint256 oShares) public onlyOwner {
        OWNER_SHARE = oShares;
        emit SharesUpdated(oShares);
    }

    /*
    * Withdraw funds.
    */
    function withdraw(uint256 amount) public onlyOwner {
        require(address(this).balance >= amount, "Insufficient balance");

        Address.sendValue(payable(_shareholders[0]), amount);
        emit PaymentReleased(_shareholders[0], amount);
    }

    /*
    * Set total NFT supply.
    */
    function setTotalSupply(uint256 supply) public onlyOwner {
        maxTokenSupply = supply;
    }

    /*
    * Set Mint price.
    */
    function setMintPrice(uint256 newPrice) public onlyOwner {
        MINT_PRICE = newPrice;
    }

    /*
    * Pause sale if active, make active if paused.
    */
    function flipSaleState() public onlyOwner {
        SALE_IS_ACTIVE = !SALE_IS_ACTIVE;
    }

    //function setTokenURI(uint256 tokenId, string memory tokenURI) external onlyRole(DEFAULT_ADMIN_ROLE){
    //    _setTokenURI(tokenId, tokenURI);
    //}
    
    function setBaseURI(string memory baseURI_) external onlyOwner{
        baseURI = baseURI_;
    }
    
    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    //function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
    //    super._burn(tokenId);
    //}
}