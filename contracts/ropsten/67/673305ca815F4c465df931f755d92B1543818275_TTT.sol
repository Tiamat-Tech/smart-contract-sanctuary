// contracts/TTT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "./node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TTT is ERC20, Ownable {
    uint256 constant ICO_START = 45; // Data of ICO's beginning
    uint256 constant ICO_TERM_1 = 3; // Length of first ICO's term
    uint256 constant ICO_TERM_2 = 30; // Length of second ICO's term
    uint256 constant ICO_TERM_3 = 14; // Length of third ICO's term
    uint256 constant ICO_PRICE_1 = 42; // Price of the token during the first term
    uint256 constant ICO_PRICE_2 = 21; // Price of the token during the second term
    uint256 constant ICO_PRICE_3 = 8; // Price of the token during the third term

    uint256 private currentDay = 0;

    mapping(address => bool) whitelist; // List of addresses who can participate at ICO

    modifier isWhitelisted(address _buyer) {
        require(whitelist[_buyer]);
        _;
    }

    constructor() ERC20("The Test Token", "TTT") {}

    receive() external payable {
        buyTokens(msg.sender);
    }

    function buyTokens(address _buyer) internal isWhitelisted(_buyer) {
        uint256 term = whatDayItIs();
        require(term > 0 && term < 4); // ICO should start and shouldn't be finished

        uint256 price = 0; // Price of the token depending on term
        if (term == 1) price = ICO_PRICE_1;
        else if (term == 2) price = ICO_PRICE_2;
        else if (term == 3) price = ICO_PRICE_3;
        require(price != 0);

        uint256 amount = price * msg.value;
        _mint(_buyer, amount);
    }

    function setCurrentDay(uint256 _currentDay) public onlyOwner {
        currentDay = _currentDay;
    }

    function addToWhitelist(address _buyer) external onlyOwner {
        whitelist[_buyer] = true;
    }

    function removeFromWhitelist(address _buyer) external onlyOwner {
        whitelist[_buyer] = false;
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        isWhitelisted(msg.sender)
        returns (bool)
    {
        return super.transfer(recipient, amount);
    }

    // Check which of ICO's terms (if any) it is
    function whatDayItIs() internal view returns (uint256) {
        if (currentDay < ICO_START) return 0;
        else if (currentDay < (ICO_START + ICO_TERM_1)) return 1;
        else if (currentDay < (ICO_START + ICO_TERM_1 + ICO_TERM_2)) return 2;
        else if (
            currentDay < (ICO_START + ICO_TERM_1 + ICO_TERM_2 + ICO_TERM_3)
        ) return 3;
        else return 4;
    }
}