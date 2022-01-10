// SPDX-License-Identifier: MIT
//  ______ _        __  __         _____      _              ____                      
// |  ____| |      / _|/ _|       |  __ \    | |            |  _ \                     
// | |__  | |_   _| |_| |_ _   _  | |__) |__ | | __ _ _ __  | |_) | ___  __ _ _ __ ___ 
// |  __| | | | | |  _|  _| | | | |  ___/ _ \| |/ _` | '__| |  _ < / _ \/ _` | '__/ __|
// | |    | | |_| | | | | | |_| | | |  | (_) | | (_| | |    | |_) |  __/ (_| | |  \__ \
// |_|    |_|\__,_|_| |_|  \__, | |_|   \___/|_|\__,_|_|    |____/ \___|\__,_|_|  |___/
//                          __/ |                                                      
//                         |___/                                                       
//
// Fluffy Polar Bears ERC-1155 Contract
// “Ice to meet you, this contract is smart and fluffy.”
/// @creator:     FluffyPolarBears
/// @author:      kodbilen.eth - twitter.com/kodbilenadam 
/// @contributor: peker.eth – twitter.com/MehmetAliCode

pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
//import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";



contract erc1155Test is ERC1155, Ownable, ERC1155Burnable, AccessControl {//ERC1155Pausable
    using Counters for Counters.Counter;

    struct Subscription {
        uint256 price;
        uint256 time;
    }

    struct User_Details {
        uint256 end_of_subscription;
    }

    uint256 constant private SECONDS_IN_DAY = 86400;

    mapping(address => User_Details) private users;
    mapping(uint => Subscription) private subscriptionOptions;




    uint256 public MAX_TOKENS = 9999;
    uint256 public CLAIMED_TOKENS;
    
    bool public hasPublicSaleStarted = true;

    uint256 public PRICE_PER_TOKEN = 0.00000000000000001 ether;

    uint256 constant private _tokenId = 1;

    uint public TEST_VARIABLE = 0;
    
    constructor() ERC1155("https://arweave.net/OMNVhpA1b5BKrOfv-pFhcycWYQ4_av2LWEhXyh8PXq8") {
        //_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        //_setupRole(PAUSER_ROLE, _msgSender());
        subscriptionOptions[0] = Subscription(15, 30 * SECONDS_IN_DAY);
        subscriptionOptions[1] = Subscription(20, 90 * SECONDS_IN_DAY);
        subscriptionOptions[2] = Subscription(25, 365 * SECONDS_IN_DAY);
        subscriptionOptions[69] = Subscription(10, 60);
        //0.00000000000000001
    }

    function getSubscriptionLength(uint256 _index) external view returns(uint256) {
        return subscriptionOptions[_index].time;
    }

    function setSubscriptionLength(uint256 _index, uint256 _timeInDays) external onlyOwner {
        subscriptionOptions[_index].time = _timeInDays * SECONDS_IN_DAY;
    }

    /**
     * @dev Change the URI
     */
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function holderOfNFT(address _address) public view returns(uint256) {
        return ERC1155(address(this)).balanceOf(_address, 1);
    }
    
    /**
     * @dev Start the public sale
     */
    function startPublicSale() public onlyOwner {
        hasPublicSaleStarted = true;
    }
    
    /**
     * @dev Pause the public sale
     */
    function pausePublicSale() public onlyOwner {
        hasPublicSaleStarted = false;
    }
    
     /**
     * @dev Just in case.
     */
    function setPrice(uint256 _newPrice) public onlyOwner() {
        PRICE_PER_TOKEN = _newPrice;
    }
    
     /**
     * @dev Shows the price.
     */
    function getPrice() public view returns (uint256){
        return PRICE_PER_TOKEN;
    }
    
     /**
     * @dev Total claimed sketches.
     */
    function totalSupply() public view returns (uint256){
        return CLAIMED_TOKENS;
    }

    /**
     * @dev Public Sale Minting
     */
    function publicSaleMint(uint256 numberOfTokens) external payable {
        require(hasPublicSaleStarted, "Public sale is not active. Check Discord or Twitter for updates.");
        require(CLAIMED_TOKENS + numberOfTokens <= MAX_TOKENS, "Purchase would exceed max tokens");
        require(numberOfTokens == 1, "Exceeded that max amount of tokens per transaction.");
        require(PRICE_PER_TOKEN * numberOfTokens <= msg.value, "Ether value sent is not correct");
        
        User_Details storage user = users[msg.sender];

        user.end_of_subscription = block.timestamp + subscriptionOptions[69].time;

        CLAIMED_TOKENS += numberOfTokens;
        _mint(msg.sender, _tokenId, numberOfTokens, "");
    }

    function subscribe(uint256 _subscriptionIndex) external payable {
        require(subscriptionOptions[_subscriptionIndex].price == msg.value, "Incorrect Ether value.");
        require(ERC1155(address(this)).balanceOf(msg.sender, 1) > 0);
        //change this later to 4
        require(_subscriptionIndex < 70);

        User_Details storage user = users[msg.sender];

        if (getTimeUntilSubscriptionExpired(msg.sender) <= 0) {
            // time left is 0 or negative (current time + subscription time)
            user.end_of_subscription = block.timestamp + subscriptionOptions[_subscriptionIndex].time;
        } else {
            //time still left on the subscription
            user.end_of_subscription += subscriptionOptions[_subscriptionIndex].time;
        }
    }

    function getSubscriptionPlanPrice(uint _index) external view returns(uint256) {
        return subscriptionOptions[_index].price;
    }

    function setMaxNumberOfTokens(uint _numberOfTokens) external onlyOwner {
        MAX_TOKENS = _numberOfTokens;
    }

    function getMaxNumberOfTokens() external view returns(uint) {
        return MAX_TOKENS;
    }

    function getTimeUntilSubscriptionExpired(address _address) public view returns(int256) {
        return int256(users[_address].end_of_subscription) - int256(block.timestamp);
    }
    
    /**
     * @dev Owner minting function
     */
    function ownerMint(uint256 numberOfTokens) external payable onlyOwner {
        require(CLAIMED_TOKENS + numberOfTokens <= MAX_TOKENS, "Purchase would exceed max tokens");
        
        // Can only claim total amount of tokens
        require(numberOfTokens <= MAX_TOKENS, "Too many requested");
        
        CLAIMED_TOKENS += numberOfTokens;
        _mint(msg.sender, _tokenId, numberOfTokens, "");
    }
    
    /**
     * @dev Withdraw and distribute the ether.
     */
    function withdrawAll() public payable onlyOwner {
        uint256 balance = address(this).balance;

        payable(msg.sender).transfer(balance);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155) { //virtual override(ERC1155, ERC1155Pausable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
        // SET THE BUYERS'S TIME TO THE SELLER'S
        // THEN WE WILL SET THE BUYER'S TIME TO 0
        users[to].end_of_subscription = users[from].end_of_subscription;
        users[from].end_of_subscription = 0;
    }

    function burnToken(address _address) external onlyOwner {
        //Burns all tokens from the address
        _burn(_address, 1, ERC1155(address(this)).balanceOf(_address, 1));
    }
}