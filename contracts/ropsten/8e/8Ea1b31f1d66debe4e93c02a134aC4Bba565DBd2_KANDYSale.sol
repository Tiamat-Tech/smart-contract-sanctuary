// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity 0.7.5;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

/*
  basic assumptions:
  - every new whitelisted user is distinct from (1) old whitelisted users and (2) old LBE participants
    i.e. an address can only participate in either the old or the new LBE
  - every blacklisted user is a bot who should not be able to claim
*/


contract KANDYSale is Ownable {
    using SafeERC20 for ERC20;
    using Address for address;

    uint constant MIMdecimals = 10 ** 18;
    uint constant KANDYdecimals = 10 ** 9;
    uint public constant MAX_SOLD = 160000 * KANDYdecimals;
    uint public constant PRICE = 5 * MIMdecimals / KANDYdecimals ;
    uint public constant MIN_PRESALE_PER_ACCOUNT = 200 * KANDYdecimals;
    uint public constant MAX_PRESALE_PER_ACCOUNT = 400 * KANDYdecimals;

    address public dev;
    ERC20 MIM;

    uint public sold;
    address public KANDY;
    bool canClaim;
    bool privateSale;
    mapping( address => uint256 ) public invested;
    mapping( address => bool ) public claimed;
    mapping( address => bool ) public approvedBuyers;
    mapping( address => bool ) public blacklisted;

    constructor() {
        MIM = ERC20(0x9ce0b698BC7eF9B796A438edf59F6229216B71e6);
        dev = 0x39eA12dA7D4991D96572FD8addb8E397C113401B;
        sold = 0; 
    }


    modifier onlyEOA() {
        require(msg.sender == tx.origin, "!EOA");
        _;
    }

    /* approving buyers into new whitelist */

    function _approveBuyer( address newBuyer_ ) internal onlyOwner() returns ( bool ) {
        approvedBuyers[newBuyer_] = true;
        return approvedBuyers[newBuyer_];
    }

    function approveBuyer( address newBuyer_ ) external onlyOwner() returns ( bool ) {
        return _approveBuyer( newBuyer_ );
    }

    function approveBuyers( address[] calldata newBuyers_ ) external onlyOwner() returns ( uint256 ) {
        for( uint256 iteration_ = 0; newBuyers_.length > iteration_; iteration_++ ) {
            _approveBuyer( newBuyers_[iteration_] );
        }
        return newBuyers_.length;
    }

    function _deapproveBuyer( address newBuyer_ ) internal onlyOwner() returns ( bool ) {
        approvedBuyers[newBuyer_] = false;
        return approvedBuyers[newBuyer_];
    }

    function deapproveBuyer( address newBuyer_ ) external onlyOwner() returns ( bool ) {
        return _deapproveBuyer(newBuyer_);
    }

    /* blacklisting old buyers who shouldn't be able to claim; subtract contrib from sold allocation */

    function _blacklistBuyer( address badBuyer_ ) internal onlyOwner() returns ( bool ) {
        blacklisted[badBuyer_] = true;
        return blacklisted[badBuyer_];
    }

    function blacklistBuyer( address badBuyer_ ) external onlyOwner() returns ( bool ) {
        return _blacklistBuyer( badBuyer_ );
    }

    function blacklistBuyers ( address[] calldata badBuyers_ ) external onlyOwner() returns ( uint256 ) {
        for ( uint256 iteration_ = 0; badBuyers_.length > iteration_; iteration_++ ) {
            _blacklistBuyer( badBuyers_[iteration_] );
        }
        return badBuyers_.length;
    }

    /* allow non-blacklisted users to buy KANDY */

    function amountBuyable(address buyer) public view returns (uint256) {
        uint256 max;
        if ( approvedBuyers[buyer] && privateSale ) {
            max = MAX_PRESALE_PER_ACCOUNT;
        }
        return max - invested[buyer];
    }

    function buyKANDY(uint256 amount) public onlyEOA {
        require(sold < MAX_SOLD, "sold out");
        require(sold + amount < MAX_SOLD, "not enough remaining");
        require(amount <= amountBuyable(msg.sender), "amount exceeds buyable amount");
        require(amount + invested[msg.sender] >= MIN_PRESALE_PER_ACCOUNT, "amount is not sufficient");
        MIM.safeTransferFrom( msg.sender, address(this), amount * PRICE  );
        invested[msg.sender] += amount;
        sold += amount;
    }

    // set KANDY token address and activate claiming
    function setClaimingActive(address kandy) public {
        require(msg.sender == dev, "!dev");
        KANDY = kandy;
        canClaim = true;
    }

    // claim KANDY allocation based on old + new invested amounts
    function claimKANDY() public onlyEOA {
        require(canClaim, "cannot claim yet");
        require(!claimed[msg.sender], "already claimed");
        require(!blacklisted[msg.sender], "blacklisted");
        if ( invested[msg.sender] > 0 ) {
            ERC20(KANDY).transfer(msg.sender, invested[msg.sender]);
        } 
        claimed[msg.sender] = true;
    }

    // token withdrawal by dev
    function withdraw(address _token) public {
        require(msg.sender == dev, "!dev");
        uint b = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transfer(dev,b);
    }

    // manual activation of whitelisted sales
    function activatePrivateSale() public {
        require(msg.sender == dev, "!dev");
        privateSale = true;
    }

    // manual deactivation of whitelisted sales
    function deactivatePrivateSale() public {
        require(msg.sender == dev, "!dev");
        privateSale = false;
    }

    function setSold(uint _soldAmount) public onlyOwner {
        sold = _soldAmount;
    }
}