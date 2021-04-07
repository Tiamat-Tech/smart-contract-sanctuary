pragma solidity ^0.7.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
// TODO: it should be removed
// import "hardhat/console.sol";
// import "./NFT.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract NFToken is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    bool isIssued = false;
    address private _saleAgent = address(0);
    uint256 public totalCap;
    uint256 public endTime;
    uint256 public startTime;

    constructor(string memory _name, string memory _symbol, uint256 _totalCap, uint256 _startTime, uint256 _endTime)
        ERC721(_name, _symbol) {
        totalCap = _totalCap;
        endTime = _endTime;
        startTime = _startTime;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwnerOrSaleAgent() {
        require(msg.sender == _saleAgent || msg.sender == owner(), "Ownable: caller is not the owner or the sale agent");
        _;
    }

    function wasIssued() public view returns (bool){
        return isIssued;
    }

    function getEndTime() public view returns (uint256){
        return endTime;
    }

    function getStartTime() public view returns (uint256){
        return startTime;
    }

    function issueTokens(address holder, uint256 cap) public onlyOwnerOrSaleAgent
    {   
        require(isIssued == false, "NFT: You can't issue more tokens.");
        require(cap <= totalCap, "NFT: You can't issue more then totalCap tokens.");
        uint256 newItemId;

        for(uint i = 0; i < cap; i++){
            _tokenIds.increment();
            newItemId = _tokenIds.current();
            _safeMint(holder, newItemId);

            if (ERC721.totalSupply() == totalCap)
                isIssued = true;
        }
    }

    function setTokenURI(uint256 tokenId, string memory _tokenURI) external onlyOwnerOrSaleAgent {
        _setTokenURI(tokenId, _tokenURI);
    }

    function setBaseURI(string memory baseURI) external onlyOwnerOrSaleAgent {
        _setBaseURI(baseURI);
    }

    function burn(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "NFT: burn of token that is not own");
        _burn(tokenId);
    }

    function setSaleAgent(address newSaleAgnet) external {
        require(msg.sender == _saleAgent || msg.sender == owner(), "NFT: you must be an owner or a sale agent");
        _saleAgent = newSaleAgnet;
    }

    function saleAgent() public view virtual returns (address) {
        return _saleAgent;
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal override {
        // except minting and burning functions
        if (block.timestamp <= endTime && from != address(0) && to != address(0)) {
            require(from == _saleAgent || from == owner(), "NFT: only owners can transfer tokens during the sale");
        }
    }
}


contract TokenSale is Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    // Reference to contract tracking NFT ownership
    NFToken public nonFungibleContract;
    // address nftTokenAddress;
    /// @dev The ERC-165 interface signature for ERC-721.
    ///  Ref: https://github.com/ethereum/EIPs/issues/165
    ///  Ref: https://github.com/ethereum/EIPs/issues/721
    bytes4 constant InterfaceSignature_ERC721 = bytes4(0x9a20483d);
    Counters.Counter private _tokenIdTracker;
    // Equals to `bytes4(keccak256("onERC721Received(address,uint256,bytes)"))`
    // which can be also obtained as `ERC721Receiver(0).onERC721Received.selector`
    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    // start and end timestamps while token sale are allowed
    // TODO: transfer these variables to the token contract
    uint256 public startTime;
    uint256 public endTime;
    bool hasEnded = false;
    // 1e18 == 1 ETh
    // TODO: after all functionality we should check memory for all values
    uint256 private price1 = 3 * 1e16; // 0.03 ETH
    uint256 private price2 = 1e17; // 0.1 ETH
    uint256 private price3 = 3 * 1e17; // 0.3 ETH
    uint256 private price4 = 5 * 1e17; // 0.5 ETH
    uint256 private price5 = 9 * 1e17; // 0.9 ETH

    // supply that is limit + 1 is the set supply here
    // uint256 private supply1 = 6;
    // uint256 private supply2 = supply1.add(14); // 20
    // uint256 private supply3 = supply2.add(20); // 41
    // uint256 private supply4 = supply3.add(20); // 62
    // uint256 private supply5 = supply4.add(4); // 67

    uint256 private supply1 = 2;
    uint256 private supply2 = supply1.add(1); // 20
    uint256 private supply3 = supply2.add(1); // 41
    uint256 private supply4 = supply3.add(1); // 62
    // uncomment after the demo
    uint256 private supply5 = supply4.add(4); // 67

    constructor(address _nftAddress) {
        // nftTokenAddress = _nftAddress;
        NFToken candidateContract = NFToken(_nftAddress);
        // TODO: check this interface for the token
        // require(candidateContract.supportsInterface(InterfaceSignature_ERC721));
        nonFungibleContract = candidateContract;
    }

    modifier saleIsOn() {
        require(block.timestamp > nonFungibleContract.getStartTime() && block.timestamp < nonFungibleContract.getEndTime(),
            "TokenSale: It is not allowed to buy tokens for now"
        );
        require(!isEnded(), "TokenSale: Sale is over by reaching the total supply");
        _;
    }

    function getPrice() public view returns(uint256) {
        uint256 total = _tokenIdTracker.current();
        if (total < supply1)
            return price1;
        else if (total >= supply1 && total < supply2)
            return price2;
        else if (total >= supply2 && total < supply3)
            return price3;
        else if (total >= supply3 && total < supply4)
            return price4;
        else if (total >= supply4 && total < supply5)
            return price5;
        else return price5; // TODO: What price is for other tokens?
    }

    // remove after the demo
    // function getPrice() public view returns(uint256) {
    //     uint256 total = _tokenIdTracker.current();
    //     if (total < supply1)
    //         return price1;
    //     else if (total >= supply1 && total < supply2)
    //         return price2;
    //     else if (total >= supply2 && total < supply3)
    //         return price3;
    //     else return price4; // TODO: What price is for other tokens?
    // }

    /*
        To support safeTransfers it has to be implemented IERC721Receiver Interface
    */
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data) public returns(bytes4) {
        return _ERC721_RECEIVED;
    }
    // it should be view?
    function getNumberOfMintedNFT() public returns (uint256) {
        return _tokenIdTracker.current();
    }

    // it should be view
    function getTotalSupply() public returns (uint256) {
        return nonFungibleContract.totalSupply();
    }

    function isEnded() public view returns (bool) {
        return hasEnded;
    }

    receive () saleIsOn external payable {
        uint256 currentPrice = getPrice();
        uint256 value = msg.value;
        // TODO: test if the user will try to buy more then stage limit;

        require(value >= currentPrice, "TokenSale: ETH value is not enough for token buying");
        // TODO: Should check that amount is no more then 50 or for example, check limit of gas for tx)
        uint256 amount = (value).div(currentPrice);
        // console.log(_tokenIdTracker.current() + amount, getTotalSupply());
        require(_tokenIdTracker.current() + amount <= getTotalSupply(), "TokenSale: There is a limit amount of tokens.");
        // TODO: Should check that price is changing after getting limit for a stage
        for(uint i = 0; i < amount; i++){
            _tokenIdTracker.increment();
            // TODO: it might need to have a state of Sale over
            if (_tokenIdTracker.current() == getTotalSupply()) {
            //     setHasEnded();
                hasEnded = true;
            }
            nonFungibleContract.safeTransferFrom(address(this), msg.sender, _tokenIdTracker.current());
            // TODO: Tests for Ownership and transfer and change url
        }
    }

}