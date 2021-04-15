// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract NFToken is ERC721, Ownable {
    using SafeMath for uint256;

    using Counters for Counters.Counter;
    Counters.Counter public tokenIdTracker;

    address private _saleAgent = address(0);
    uint256 public totalCap;
    uint256 public endTime;
    uint256 public startTime;
    uint256 public iterationLimit = 50; // it prevents an error 'out of gas' due to tough transaction

    constructor(
        string memory _name, string memory _symbol, uint256 _totalCap, uint256 _startTime, uint256 _endTime)
        ERC721(_name, _symbol) {
        totalCap = _totalCap;
        endTime = _endTime;
        startTime = _startTime;
    }
    string [] public urls;
    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwnerOrSaleAgent() {
        require(msg.sender == _saleAgent || msg.sender == owner(), "Ownable: caller is not the owner or the sale agent");
        _;
    }

    function _beforeTokenTransfer(address from, address to, uint256) internal view override {
        if (msg.sender != _saleAgent && msg.sender != owner())
            require(!isContract(to), "NFT: You can not to transfer tokens to the contract address");
        if (block.timestamp <= endTime && from != address(0) && to != address(0)) {
            require(from == _saleAgent || from == owner(), "NFT: only owners can transfer tokens during the sale");
        }
    }
    
    function issueTokens(address holder, uint256 cap) public onlyOwnerOrSaleAgent
    {   
        require (cap <= iterationLimit, "NFT: There is a limit of tokens for each transaction, try to issue less");
        require (ERC721.totalSupply().add(cap) <= totalCap, "NFT: You can't issue this amount of tokens.");
        for(uint i = 0; i < cap; i++){
            safeMint(holder);
        }
    }

    function safeMint(address holder) public onlyOwnerOrSaleAgent {
        tokenIdTracker.increment();
        _safeMint(holder, getIdTracker());
    }
    
    function setTokenURI(uint256 tokenId, string memory _tokenURI) external onlyOwnerOrSaleAgent {
        _setTokenURI(tokenId, _tokenURI);
    }

    function setBaseURI(string memory baseURI) external onlyOwnerOrSaleAgent {
        _setBaseURI(baseURI);
    }

    function setSaleAgent(address newSaleAgnet) external {
        require(msg.sender == _saleAgent || msg.sender == owner(), "NFT: you must be an owner or a sale agent");
        _saleAgent = newSaleAgnet;
    }

    function saleAgent() public view returns (address) {
        return _saleAgent;
    }

    function setUrl(string memory url) public onlyOwnerOrSaleAgent {
        urls.push(url);
    }

    function getUrl(uint256 id) internal view returns (string memory) {
        // TODO: add checking that this id is excist
        return urls[id];
    }

    function getRandomIndex() internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp))) % urls.length;
    }

    function getImageUrl(uint index) internal returns (string memory) {
        string  memory url = urls[index];
        require(urls.length != 0, "NFT: List of URL is empty");
        urls[index] = urls[urls.length - 1];
        urls.pop();
        return url;
    }

    function setRandomUrl(uint256 id) public onlyOwnerOrSaleAgent {
        uint256 index = uint256(getRandomIndex());
        ERC721._setTokenURI(id, getImageUrl(index));
    }

    function isContract(address addr) internal view returns (bool){
        uint256 size;
        assembly {
            size := extcodesize(addr)
        }
        return (size > 0);
    }

    function getIdTracker() public view returns(uint256) {
        return tokenIdTracker.current();
    }
}


contract TokenSale is Ownable, IERC721Receiver {
    using SafeMath for uint256;
    // Reference to contract tracking NFT ownership
    NFToken public nonFungibleContract;

    address payable _withdrawAgent = address(0);
    uint256 public iterationLimit = 50; // it prevents an error 'out of gas' due to tough transaction

    bool hasEnded = false;
    // 1e18 == 1 ETh
    uint256 private price1 = 3 * 1e16; // 0.03 ETH
    uint256 private price2 = 1e17; // 0.1 ETH
    uint256 private price3 = 3 * 1e17; // 0.3 ETH
    uint256 private price4 = 5 * 1e17; // 0.5 ETH
    uint256 private price5 = 9 * 1e17; // 0.9 ETH

    uint256 private supply1;
    uint256 private supply2;
    uint256 private supply3;
    uint256 private supply4;
    uint256 private supply5;

    constructor(
        address _nftAddress,
        uint256 _supply1,
        uint256 _supply2,
        uint256 _supply3,
        uint256 _supply4,
        uint256 _supply5) {
        NFToken candidateContract = NFToken(_nftAddress);
        nonFungibleContract = candidateContract;
        supply1 = _supply1;
        supply2 = _supply2;
        supply3 = _supply3;
        supply4 = _supply4;
        supply5 = _supply5;
    }

    modifier saleIsOn() {
        require(block.timestamp > nonFungibleContract.startTime(),
            "TokenSale: It is not allowed to buy tokens for now"
        );
        require(!isEnded(), "TokenSale: Sale is over by reaching the total supply or date");
        _;
    }

    receive() saleIsOn external payable {
        uint256 currentPrice = getPrice();
        uint256 value = msg.value;

        require(value >= currentPrice, "TokenSale: ETH value is not enough for token buying");
        uint256 amount = (value).div(currentPrice);

        require (amount <= iterationLimit, "TokenSale: There is a limit of tokens for each transaction, try to buy less");
        
        require(
            isAvailableAmountForStage(amount),
            "TokenSale: These amount of tokens are not available for this stage, try to buy less"
        );

        // (Optional) retuns back excess ether
        // uint256 neatValue = currentPrice.mul(amount);
        // if (neatValue < value)
        //     (msg.sender).send(value.sub(neatValue));

        require(
            nonFungibleContract.getIdTracker().add(amount) <= getTotalSupply(),
            "TokenSale: Tried to buy more then set in total supply."
        );

        for(uint i = 0; i < amount; i++){
            if (nonFungibleContract.getIdTracker().add(1) == getTotalSupply()) {
                hasEnded = true;
            }
            nonFungibleContract.safeMint(msg.sender);
        }
    }
    
    function getPrice() public view returns(uint256) {
        uint256 current = nonFungibleContract.getIdTracker();
        if (current < supply1)
            return price1;
        else if (current >= supply1 && current < supply2)
            return price2;
        else if (current >= supply2 && current < supply3)
            return price3;
        else if (current >= supply3 && current < supply4)
            return price4;
        else if (current >= supply4 && current < supply5)
            return price5;
        else return price5;
    }

    function getCurrentSupply() public view returns(uint256) {
        uint256 current = nonFungibleContract.getIdTracker();
        if (current < supply1)
            return supply1;
        else if (current >= supply1 && current < supply2)
            return supply2;
        else if (current >= supply2 && current < supply3)
            return supply3;
        else if (current >= supply3 && current < supply4)
            return supply4;
        else if (current >= supply4 && current < supply5)
            return supply5;
        else return 0;
    }

    function isAvailableAmountForStage(uint256 amount) public view returns(bool) {
        uint256 current = nonFungibleContract.getIdTracker();
        uint256 preResult = current.add(amount);
        uint256 currentSupply = getCurrentSupply();
        if (preResult <= currentSupply)
            return true;
        else return false; 
    }

    /**
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function getTotalSupply() public view returns (uint256) {
        return nonFungibleContract.totalCap();
    }

    function isEnded() public view returns (bool) {
        return hasEnded || block.timestamp >= nonFungibleContract.endTime();
    }

    function withdraw() public onlyOwner {
        require(_withdrawAgent != address(0), "TokenSale: Set _withdrawAgent address at first");
        _withdrawAgent.transfer(address(this).balance);
    }

    function setWithdrawAgent(address payable _newWithdrawAgent) public onlyOwner {
        _withdrawAgent = _newWithdrawAgent;
    }
}