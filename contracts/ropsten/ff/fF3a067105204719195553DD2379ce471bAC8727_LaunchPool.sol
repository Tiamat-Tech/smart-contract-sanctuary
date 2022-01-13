// SPDX-License-Identifier: MIT
pragma solidity 0.8.5;

import "Cert.sol";
import "ERC20.sol";
import "Ownable.sol";

// *********************************
// Launch pool - token sale which issues Certificates
// *********************************

contract LaunchPool is Ownable {
    
    // the token address the cash is raised in
    // assume decimals is 18
    address public investToken;
    // the token to be launched
    address public launchToken;
    // proceeds go to treasury
    address public treasury;
    // the certificate
    Cert public cert;
    // fixed single price
    uint256 public price;
    // ratio quote in 100
    uint256 public priceQuote = 100;
    // maximum cap
    uint256 public investCap;
    // the total amount in stables to be raised
    uint256 public totalraiseCap;
    // how much was raised
    uint256 public totalraised;
    // how much was issued
    uint256 public totalissued;
    // start of the sale
    uint256 public startTime;
    // total duration
    uint256 public duration;
    // end of the sale
    uint256 public endTime;
    // sale has started
    bool public saleEnabled;
    
    // minimum amount
    uint256 public mininvest;
    uint256 public launchDecimals = 18; 
    //
    uint256 public numWhitelisted = 0;
    //
    uint256 public numInvested = 0;
    
    event SaleEnabled(bool enabled, uint256 time);    
    event Invest(address investor, uint256 amount);
    
    struct InvestorInfo {
        uint256 amountInvested; // Amount deposited by user
        bool claimed; // has claimed
    }

    // user is whitelisted
    mapping(address => bool) public whitelisted;

    mapping(address => InvestorInfo) public investorInfoMap;
    
    constructor(
        address _investToken,        
        uint256 _price,
        uint256 _startTime,  
        uint256 _duration,  
        uint256 _totalraiseCap,
        uint256 _minInvest,
        address _treasury        
    ) {
        investToken = _investToken;
        price = _price;
        startTime = _startTime;
        duration = _duration;
        totalraiseCap = _totalraiseCap;
        mininvest = _minInvest; 
        treasury = _treasury;
        require(duration < 7 days, "duration too long");
        endTime = startTime + duration;
        //cert = new Cert("aToken", launchDecimals);
        
        
        saleEnabled = false;
        //investCap = 4000 * 10 ** launchDecimals;
    }

    function setCert(address _cert) external onlyOwner {
        cert = Cert(_cert);
    }

    // adds an address to the whitelist
    function addWhitelist(address _address) external onlyOwner {
        require(!saleEnabled, "sale has already started");
        //require(!whitelisted[_address], "already whitelisted");
        whitelisted[_address] = true;
        numWhitelisted+=1; 
    }

    // adds multiple addresses
    function addMultipleWhitelist(address[] calldata _addresses) external onlyOwner {
        require(!saleEnabled, "sale has already started");
        require(_addresses.length <= 1000, "too many addresses");
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelisted[_addresses[i]] = true;  
            numWhitelisted+=1;          
        }
    }

    // removes a single address from the sale
    function removeWhitelist(address _address) external onlyOwner {
        require(!saleEnabled, "sale has already started");
        whitelisted[_address] = false;
    }

    // invest up to current cap
    function invest(uint256 investAmount) public {
        require(block.timestamp >= startTime, "not started yet");
        require(saleEnabled, "not enabled yet");
        require(whitelisted[msg.sender] == true, 'msg.sender is not whitelisted');
        require(totalraised + investAmount <= totalraiseCap, "over total raise");
        require(investAmount >= mininvest, "below minimum invest");

        InvestorInfo storage investor = investorInfoMap[msg.sender];

        //require(investor.amountInvested + investAmount <= investCap, "above cap");        

        require(
            ERC20(investToken).transferFrom(
                msg.sender,
                address(this),
                investAmount
            ),
            "transfer failed"
        );
        
        uint256 issueAmount = investAmount * priceQuote / price;

        cert.issue(msg.sender, issueAmount);

        totalraised += investAmount;
        totalissued += issueAmount;
        if (investor.amountInvested == 0){
            numInvested += 1;
        }
        investor.amountInvested += investAmount;
        
        emit Invest(msg.sender, investAmount);
    }

    // withdraw funds to treasury
    function withdrawTreasury(uint256 amount) public onlyOwner {
        //uint256 b = ERC20(investToken).balanceOf(address(this));
        require(
            ERC20(investToken).transfer(treasury, amount),
            "transfer failed"
        );
    }

    function enableSale() public onlyOwner {
        saleEnabled = true;
        emit SaleEnabled(true, block.timestamp);
    }
    
}