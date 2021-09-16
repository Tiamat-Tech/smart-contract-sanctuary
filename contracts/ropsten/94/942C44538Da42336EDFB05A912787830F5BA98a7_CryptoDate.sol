// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// Uniswap Oracle
interface IPriceFeed {
    function consult(address token, uint256 amountIn) external view returns (uint256 amountOut);

    function update() external;
}

// subset of Uniswap Router Interface
interface IUniswapV2Router02 {
    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint[] memory amounts);
}

// used for call to legacy NFT contract
interface IExist {
    function exists(uint256 _tokenId) external returns (bool _exists);
}

contract CryptoDate is ERC721Enumerable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /* VARIABLES FOR REWARDS */

    uint256 public periodFinish = 0;
    //amount of CDT you earn per nft per period
    //use of ether keyword adds 18 zeros
    uint256 public rewardPerNFTPerPeriod = 100 ether;
    uint256 public rewardsDuration = 365 days;
    uint256 public rewardRate; 
    uint256 public lastUpdateTime;
    uint256 public rewardPerTokenStored;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) private _balances;

    /* VARIABLES FOR ADDRESSES */

    // CDT address which is reward token
    address public immutable CDT;

    // WETH address
    address public immutable WETH;

    // WETH address
    address public immutable DAI;

    // CDT_WETH price feed address
    address public immutable PRICE_FEED_CDT_WETH;

    // DAI_WETH price feed address
    address public immutable PRICE_FEED_DAI_WETH;

    // UNISWAP ROUTER address
    address payable public immutable UNISWAP_ROUTER;

    // TREASURY address
    address public immutable TREASURY;

    // CRYPTODATE V1
    address public immutable CRYPTO_DATE_LEGACY;

    /* VARIABLES FOR TOKENOMICS */

    //percentage for split of ETH sales between UNISWAP pool and TREASURY
    uint256 public constant splitPercentage = 50;

    //percentage for reward of CDT when purchased with ETH
    uint256 public constant rewardPecentage = 10;

    // The price of a crypto date in USD is $200
    // using the ether keyword is a convenience method to get 18 zeros added
    uint256 public constant cryptoDatePriceInUSD = 200 ether;

    constructor(
        address _cdt,
        address payable _uniswapRouter,
        address _weth,
        address _dai,
        address _price_feed_cdt_weth,
        address _price_feed_dai_weth,
        address _treasury,
        address _crypto_date_legacy
    ) ERC721("CryptoDate", "CD") {
        CDT = _cdt;
        UNISWAP_ROUTER = _uniswapRouter;
        WETH = _weth;
        DAI = _dai;
        PRICE_FEED_CDT_WETH = _price_feed_cdt_weth;
        PRICE_FEED_DAI_WETH = _price_feed_dai_weth;
        TREASURY = _treasury;
        CRYPTO_DATE_LEGACY = _crypto_date_legacy;

        //approve uniswap router to spend CDT token
        IERC20(_cdt).safeApprove(_uniswapRouter, uint(2**256 - 1));
        //init rewards
        rewardRate = rewardPerNFTPerPeriod.div(rewardsDuration);
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(rewardsDuration);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "https://api.cryptodate.io/date/";
    }

    function mintWithETH(
        address _to,
        uint256 year,
        uint256 month,
        uint256 day
    ) external payable nonReentrant {
        uint256 _tokenId = valiDate(year, month, day);
        uint256 priceInEth = getPriceInETH();
        require(msg.value >= priceInEth, "INSUFFICIENT ETH");

        // half the ETH is used to buy back CDT tokens from the pool
        uint256 split = priceInEth.mul(splitPercentage).div(100);
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = CDT;
        IUniswapV2Router02(UNISWAP_ROUTER).swapExactETHForTokens{value: split}(
            uint(0),
            path,
            TREASURY,
            block.timestamp + 1800
        );

        // the other half of ETH goes to TREASURY fund
        (bool sent, ) = TREASURY.call{value: split}("");
        require(sent, "Failed to send Ether");
        super._safeMint(_to, _tokenId);
        //issue reward based on price in CDT if contract has CDT left
        uint256 rewardInCDT = getPriceInCDTBasedOnPriceInEth(priceInEth).mul(rewardPecentage).div(100);
        if (IERC20(CDT).balanceOf(address(this)) >= rewardInCDT) {
            IERC20(CDT).safeTransfer(msg.sender, rewardInCDT);
        }
    }

    function getPriceInETH() public view returns (uint256 priceInEth) {
        return IPriceFeed(PRICE_FEED_DAI_WETH).consult(DAI, cryptoDatePriceInUSD);
    }

    function mintWithCDT(
        address _to,
        uint256 year,
        uint256 month,
        uint256 day
    ) external nonReentrant {
        uint256 _tokenId = valiDate(year, month, day);
        uint256 priceInCDT = getPriceInCDT();

        // half of CDT stays in contract to fund future rewards and half goes to treasury
        IERC20(CDT).safeTransferFrom(msg.sender, TREASURY, priceInCDT.mul(splitPercentage).div(100));
        IERC20(CDT).safeTransferFrom(msg.sender, address(this), priceInCDT.mul(splitPercentage).div(100));
        super._safeMint(_to, _tokenId);
    }

    function getPriceInCDT() public view returns (uint256 priceInCDT) {
        return IPriceFeed(PRICE_FEED_CDT_WETH).consult(WETH, getPriceInETH());
    }

    function getPriceInCDTBasedOnPriceInEth(uint256 priceInEth) public view returns (uint256 priceInCDT) {
        return IPriceFeed(PRICE_FEED_CDT_WETH).consult(WETH, priceInEth);
    }

    function migrationMint(address _to, uint256 _tokenId) external nonReentrant {
        // this call will revert if the token does not exist in the legacy contract
        // which prevents people from trying to migrate dates that haven't been minted
        address legacyAddress = IERC721(CRYPTO_DATE_LEGACY).ownerOf(_tokenId);
        // if the call does return address, make sure the owner of the legacy
        // address is the person that called the function
        require(msg.sender == legacyAddress, "Only legacy owner can migrate.");
        super._safeMint(_to, _tokenId);
    }

    function valiDate(
        uint256 year,
        uint256 month,
        uint256 day
    ) private returns (uint256 tokenizedDate) {
        require(year > 1899 && year < 2100, "invalid date");
        require(month > 0 && month < 13, "invalid date");
        require(day > 0, "invalid date");
        if (month == 2) {
            // account for leap year
            if (year % 4 == 0) {
                require(day < 30, "invalid date");
            } else {
                require(day < 29, "invalid date");
            }
        }
        if (month == 1 || month == 3 || month == 5 || month == 7 || month == 8 || month == 10 || month == 12) {
            require(day < 32, "invalid date");
        }
        if (month == 4 || month == 6 || month == 9 || month == 11) {
            require(day < 31, "invalid date");
        }
        tokenizedDate = year.mul(100).add(month).mul(100).add(day);
        //make sure that this date isn't reserved from the v1 migration
        require(IExist(CRYPTO_DATE_LEGACY).exists(tokenizedDate) == false, "Date already minted.");
    }

    // also rewards to be extended 
    function extendRewards(uint256 newRewardPerNFTPerPeriod, uint256 newRewardDuration) external {
        require(newRewardPerNFTPerPeriod > 0, "reward too small");
        require(newRewardDuration > 0, "reward duration too small");
        require(block.timestamp >= periodFinish, "rewards still in progress");
        // Ensure the provided reward amount is sufficient to reward all NFTs
        uint balance = IERC20(CDT).balanceOf(address(this));
        require(balance > newRewardPerNFTPerPeriod.mul(73050), "insufficient balance");
        updateReward(address(0));
        rewardsDuration = newRewardDuration;
        rewardRate = newRewardPerNFTPerPeriod.div(rewardsDuration);
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp.add(rewardsDuration);
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        return Math.min(block.timestamp, periodFinish);
    }

    function rewardPerToken() public view returns (uint256) {
        return rewardPerTokenStored.add(lastTimeRewardApplicable().sub(lastUpdateTime).mul(rewardRate));
    }

    function earned(address account) public view returns (uint256) {
        // uses the balance of account's NFTs
        return balanceOf(account).mul(rewardPerToken().sub(userRewardPerTokenPaid[account])).add(rewards[account]);
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate.mul(rewardsDuration);
    }

    function getReward() external nonReentrant {
        updateReward(msg.sender);
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            if (IERC20(CDT).balanceOf(address(this)) >= reward) {
                IERC20(CDT).safeTransfer(msg.sender, reward);
            }
        }
    }

    function updateReward(address account) internal {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        //update price avgs
        IPriceFeed(PRICE_FEED_CDT_WETH).update();
        IPriceFeed(PRICE_FEED_DAI_WETH).update();

        //this will get fired either on 1) mint or 2) transfer
        //we always want to updateReward on the to address
        updateReward(to);
        //if it got called on transfer (as opposed to called via minting), it means the "from"
        //address has transferred the NFT, so need to call update for that address
        if (from != address(0)) {
            updateReward(from);
        }

        super._beforeTokenTransfer(from, to, amount); // Call parent hook
    }

    //allows anyone to recover wrong tokens sent to the contract
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external {
        require(_tokenAddress != CDT, "Cannot be reward token");
        IERC20(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);
    }

    //allows anyone to recover ETH mistakenly sent to contract
    function withdrawETH(uint256 _amount) external payable {
        (bool sent, ) = msg.sender.call{value: _amount}("");
        require(sent, "Failed to send Ether");
    }

    receive() external payable {}
}