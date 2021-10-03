// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AniCatsMintpassBeta is ERC1155, Ownable {
    address constant public CHARITY_ADDRESS = 0x897fe74d43CDA5003dB8917DFC53eA770D12ef71; // Public charity 5% to Best Friends Animal Society

    uint constant public TICKET_ID = 0;
    uint constant public MAX_SUPPLY = 1000;
    uint constant public MAX_TICKETS_PER_WALLET = 10;

    struct MintpassPlan {
        uint price;
        uint amount;
    }

    bool public _mintpassEnabled = false;
    uint public _ticketsMinted = 0;

    bool public _transferLocked;

    mapping(address => bool) public _isOperatorApproved;
    mapping(address => uint) public _ticketsOfWallet;
    mapping(uint => MintpassPlan) public _minpassPlans;

    constructor() ERC1155("https://anicats-api-beta.herokuapp.com/meta/{id}") {
        giveAway(msg.sender, 1); // auto mint to contract owner

        _transferLocked = false;
        _mintpassEnabled = true;

        _minpassPlans[1] = MintpassPlan(0.065 ether, 1);  // 0.065 per one ticket
        _minpassPlans[2] = MintpassPlan(0.180 ether, 3);  // 0.060 per one ticket
        _minpassPlans[3] = MintpassPlan(0.275 ether, 5);  // 0.055 per one ticket
        _minpassPlans[4] = MintpassPlan(0.500 ether, 10); // 0.050 per one ticket
    }

    // Admin methods region
    function setURI(string memory uri) external onlyOwner {
        _setURI(uri);
    }

    function approveOperator(address operator, bool approved) external onlyOwner {
        _isOperatorApproved[operator] = approved;
    }

    function setTransferLocked(bool locked) external onlyOwner {
        _transferLocked = locked;
    }
    
    function setMintpassSaleState(bool state) external onlyOwner {
        _mintpassEnabled = state;
    }
    
    function withdraw(address to) external onlyOwner {
        uint balance = address(this).balance;
        uint share = balance * 5 / 100; // 5% goes to a charity wallet

        payable(CHARITY_ADDRESS).transfer(share);
        payable(to).transfer(balance - share);
    }
    // endregion

    // Mint methods
    modifier mintpassGuard(uint planId) {
        require(_mintpassEnabled, "Minting is not available");
        require(_ticketsMinted + _minpassPlans[planId].amount <= MAX_SUPPLY, "Mintpass tickets supply reached limit");
        require(_minpassPlans[planId].amount != 0, "No such pre order plan");
        _;
    }

    function buyMintpass(uint planId) external payable mintpassGuard(planId) {
        require(_minpassPlans[planId].price == msg.value, "Incorrect ethers value");
        require(_ticketsOfWallet[msg.sender] + _minpassPlans[planId].amount <= MAX_TICKETS_PER_WALLET, "MAX_TICKETS_PER_WALLET constraint violation");

        _ticketsOfWallet[msg.sender] += _minpassPlans[planId].amount;
        _ticketsMinted += _minpassPlans[planId].amount;

        _mint(msg.sender, TICKET_ID, _minpassPlans[planId].amount, "");
    }

    function giveAway(address to, uint amount) public onlyOwner {
        _ticketsOfWallet[to] += amount;
        _ticketsMinted += amount;

        _mint(to, TICKET_ID, amount, "");
    }
    // endregion


    // 1151 interface region
    function isApprovedForAll(address account, address operator) public view override returns (bool) {
        return _isOperatorApproved[operator] || super.isApprovedForAll(account, operator);
    }

    function safeTransferFrom(address from,address to,uint256 id,uint256 amount,bytes memory data
    ) public override {
        require(!_transferLocked, "Transfer is locked");
        super._safeTransferFrom(from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(!_transferLocked, "Transfer is locked");
        super._safeBatchTransferFrom(from, to, ids, amounts, data);
    }
    // endregion
}