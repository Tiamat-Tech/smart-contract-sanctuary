pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "./Token.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
//need this to test locally
import "./interfaces/IUniswapV2Router01.sol";

contract Presale is AccessControl {
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    Counters.Counter private _presaleIds;
    uint256 public usageFeeBasisPoint;

    struct TokenPresale {
        IERC20 TOKEN;
        uint256 presaleId;
        uint256 startTime;
        uint256 endTime;
        uint256 ethPriceMantissa;
        uint256 totalEthPoolMantissa;
        uint256 totalEthUsageFeeMantissa;
        uint256 totalTokenAmountMantissa;
        uint256 currTokenAmountMantissa;
        mapping(address => uint256) purchases;
    }
    mapping(uint256 => TokenPresale) presales;

    constructor(uint256 usageFee) public {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        usageFeeBasisPoint = usageFee;
    }

    function getbasisPoint(uint256 number) public view returns (uint256) {
        return number.mul(usageFeeBasisPoint).div(10000);
    }

    function startPresale(
        uint256 startTimestamp,
        uint256 endTimestamp,
        uint256 ethPriceMantissa,
        uint256 tokenAmountMantissa,
        IERC20 _TOKEN
    ) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Must be admin to start presale"
        );
        require(
            startTimestamp < endTimestamp,
            "the start time must be before the end time"
        );
        require(
            block.timestamp < endTimestamp,
            "the end timestamp must be later then current time"
        );
        _presaleIds.increment();
        TokenPresale storage newTokenPresale = presales[_presaleIds.current()];
        newTokenPresale.TOKEN = _TOKEN;
        newTokenPresale.presaleId = _presaleIds.current();
        newTokenPresale.startTime = startTimestamp;
        newTokenPresale.endTime = endTimestamp;
        newTokenPresale.ethPriceMantissa = ethPriceMantissa;
        newTokenPresale.totalTokenAmountMantissa = tokenAmountMantissa;
        newTokenPresale.currTokenAmountMantissa = tokenAmountMantissa;
        
        // transfer from owner to contract to store
        newTokenPresale.TOKEN.transferFrom(msg.sender, address(this), tokenAmountMantissa);
    }

    function getPresaleEthPriceMantissa(uint256 presaleId)
        public
        view
        returns (uint256)
    {
        return presales[presaleId].ethPriceMantissa;
    }

    function buy(uint256 presaleId, uint256 tokenAmountMantissa)
        public
        payable
    {
        require(tokenAmountMantissa > 0, "should buy more than 0");
        require(
            block.timestamp > presales[presaleId].startTime,
            "presale has not started yet"
        );
        require(
            block.timestamp < presales[presaleId].endTime,
            "presale has already ended"
        );
        require(
            presales[presaleId].currTokenAmountMantissa >= tokenAmountMantissa,
            "not enough tokens left"
        );
        uint256 totalEthBuyMantissa =
            tokenAmountMantissa.mul(presales[presaleId].ethPriceMantissa).div(
                1 ether
            );

        // instead of += / -=, should i use .add/.sub

        presales[presaleId].currTokenAmountMantissa -= tokenAmountMantissa;
        presales[presaleId].purchases[msg.sender] += tokenAmountMantissa;

        uint256 usageFeeEthMantissa =
            totalEthBuyMantissa.mul(usageFeeBasisPoint).div(10000);
        presales[presaleId].totalEthUsageFeeMantissa += usageFeeEthMantissa;

        uint256 poolEthMantissa = totalEthBuyMantissa.sub(usageFeeEthMantissa);
        presales[presaleId].totalEthPoolMantissa += poolEthMantissa;

        presales[presaleId].TOKEN.approve(msg.sender, tokenAmountMantissa);
        presales[presaleId].TOKEN.transfer(
            msg.sender,
            tokenAmountMantissa
        );
    }

    function withdraw(uint256 presaleId) public {
        require(
            block.timestamp > presales[presaleId].endTime,
            "presale is not yet ended"
        );
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Must be admin to withdraw remaining tokens"
        );
        require(
            presales[presaleId].currTokenAmountMantissa > 0,
            "There must be a remaining balance to withdraw"
        );
        uint256 amountWithdraw = presales[presaleId].currTokenAmountMantissa;
        presales[presaleId].currTokenAmountMantissa = 0;
        presales[presaleId].TOKEN.approve(msg.sender, amountWithdraw);
        presales[presaleId].TOKEN.transfer(msg.sender, amountWithdraw);
    }

    function getPresaleEthPoolAmountMantissa(uint256 presaleId)
        public
        view
        returns (uint256)
    {
        return presales[presaleId].totalEthPoolMantissa;
    }

    function endPresale(
        uint256 presaleId,
        uint256 tokenAmountMantissa
    ) public {
        require(
            block.timestamp > presales[presaleId].endTime,
            "presale is not yet ended"
        );
        require(
            presales[presaleId].totalEthPoolMantissa > 0,
            "ETH amount must not be 0"
        );
        require(tokenAmountMantissa > 0, "Token amount must not be 0");

        // uniswap periphery router 1
        address router1Add = 0xf164fC0Ec4E93095b804a4795bBe1e041497b92a;
        IUniswapV2Router01 router1 = IUniswapV2Router01(router1Add);

        // approve uniswap
        presales[presaleId].TOKEN.approve(router1Add, tokenAmountMantissa);

        // add liquidity
        address token = address(presales[presaleId].TOKEN);
        uint256 amountTokenDesired = tokenAmountMantissa;
        uint256 amountTokenMin = tokenAmountMantissa;
        uint256 amountETHMin = presales[presaleId].totalEthPoolMantissa;
        address to = msg.sender;
        uint256 deadline = (block.timestamp) + (20 minutes);
        router1.addLiquidityETH(
            token,
            amountTokenDesired,
            amountTokenMin,
            amountETHMin,
            to,
            deadline
        );

        // withdraw usage fees
        uint256 amountWithdraw = presales[presaleId].totalEthUsageFeeMantissa;
        presales[presaleId].totalEthUsageFeeMantissa = 0;
        presales[presaleId].TOKEN.approve(msg.sender, amountWithdraw);
        presales[presaleId].TOKEN.transfer(msg.sender, amountWithdraw);
    }

    function changeUsageFee(uint256 usageFee) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, msg.sender),
            "Must be admin to change Usage Fee"
        );
        usageFeeBasisPoint = usageFee;
    }

    function getBlocktime() public view returns (uint256) {
      return block.timestamp;
    }
}