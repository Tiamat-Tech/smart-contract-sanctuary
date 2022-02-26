// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USMILX is ERC20 {
    uint256 public INITIAL_SUPPLY = 100000000000 * (10**18);
    address public marketing;
    address public charity;
    address public exchange;
    address public platform;
    uint256 public marketingFee;
    uint256 public charityFee;
    uint256 public exchangeFee;
    uint256 public platformFee;
    uint256 public holdersFee;
    uint256 public currentPayroll = 1;
    mapping(uint256 => address) public holdersList;
    mapping(address => bool) public isHolder;
    mapping(address => bool) public blacklist;
    mapping(address => bool) public frozen;
    mapping(address => uint256) public blacklistLimit;
    mapping(address => uint256) public holderLastPayroll;
    mapping(address => uint256) public blacklistSentAmount;
    uint256 public holders = 0;

    constructor() ERC20("USMILX", "USMX") {
        _mint(msg.sender, INITIAL_SUPPLY);
        platform = msg.sender;
    }

    modifier OnlyPlatform() {
        require(msg.sender == platform, "Platform owner only");
        _;
    }

    function setMarketing(address wallet) public OnlyPlatform{
        marketing = wallet;
    }

    function setCharity(address wallet) public OnlyPlatform{
        charity = wallet;
    }

    function setExchange(address wallet) public OnlyPlatform{
        exchange = wallet;
    }

    function setPlatform(address wallet) public OnlyPlatform{
        platform = wallet;
    }

    function airdrop(address[] memory wallet, uint256[] memory amount) public OnlyPlatform{
        require(wallet.length == amount.length, "wrong array length");
        for (uint256 index = 0; index < wallet.length; index++) {
            transfer(wallet[index], amount[index]);
        }
    }

    function blacklistWallet(address wallet) public OnlyPlatform{
        blacklistLimit[wallet] = (balanceOf(wallet) * 5) / 100;
        blacklist[wallet] = true;
    }

    function removeWalletFromBlacklist(address wallet) public OnlyPlatform{
        blacklist[wallet] = false;
    }

    function freezeWallet(address wallet) public OnlyPlatform{
        frozen[wallet] = true;
    }

    function unFreezeWallet(address wallet) public OnlyPlatform{
        frozen[wallet] = false;
    }

    function sendCharityFee() public OnlyPlatform{
        _transfer(address(this), charity, charityFee);
    }

    function sendMarketingFee() public OnlyPlatform{
        _transfer(address(this), marketing, marketingFee);
    }

    function sendPlatformFee() public OnlyPlatform{
        _transfer(address(this), platform, platformFee);
    }

    function sendExchangeFee() public OnlyPlatform{
        _transfer(address(this), exchange, exchangeFee);
    }

    function updatePayroll() public OnlyPlatform{
        currentPayroll++;
    }

    function claimHolderFee() public {
        require(isHolder[msg.sender] && balanceOf(msg.sender) > 0);
        require(!frozen[msg.sender], "frozen");
        require(!blacklist[msg.sender], "blacklisted");
        require(
            holderLastPayroll[msg.sender] <= currentPayroll,
            "cannot claim twice"
        );
        holderLastPayroll[msg.sender] = currentPayroll;
        _transfer(address(this), msg.sender, holdersFee / holders);
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool success)
    {
        require(balanceOf(msg.sender) >= amount, "Not enough funds");
        require(!frozen[msg.sender], "frozen");
        require(!frozen[recipient], "frozen");
        require(!blacklist[recipient], "blacklisted");
        if (blacklist[msg.sender]) {
            require(amount <= blacklistLimit[msg.sender], "exceed");
            require(
                blacklistSentAmount[msg.sender] <= blacklistLimit[msg.sender],
                "exceed"
            );
            blacklistSentAmount[msg.sender] += amount;
        }
        uint256 fee = (amount * 30) / 100;
        holdersFee += (fee * 6) / 100;
        if (balanceOf(recipient) <= 0 && !isHolder[recipient]) {
            holders++;
            holdersList[holders] = recipient;
            isHolder[recipient] = true;
        }
        holdersFee += (fee * 6) / 100;
        charityFee += (fee * 15) / 100;
        marketingFee += (fee * 3) / 100;
        platformFee += (fee * 3) / 100;
        exchangeFee += (fee * 3) / 100;
        super.transfer(recipient, amount - fee);
        _transfer(msg.sender, address(this), fee);
        return true;
    }
}