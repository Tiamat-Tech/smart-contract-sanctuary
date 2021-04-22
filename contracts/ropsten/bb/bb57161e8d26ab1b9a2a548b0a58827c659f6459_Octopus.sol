// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


interface IOption {
    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender) external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    function mint(address account, uint256 amount) external;
    
    function getUnderlying() external view returns (string memory);
    
    function getStrike() external view returns (uint);

    function getExpiresOn() external view returns (uint);
}

interface IPriceConsumerV3EthUsd {
    function getLatestPrice() external view returns (int);
}

interface IUniswapV2Router02 {
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
      external
      payable
      returns (uint[] memory amounts);
      
    function swapExactTokensForTokens(
      uint amountIn,
      uint amountOutMin,
      address[] calldata path,
      address to,
      uint deadline
    ) external returns (uint[] memory amounts);  
    
    function swapTokensForExactTokens(
      uint amountOut,
      uint amountInMax,
      address[] calldata path,
      address to,
      uint deadline
    ) external returns (uint[] memory amounts);
      
    function WETH() external returns (address); 
    
    function getAmountsIn(uint amountOut, address[] memory path) external view returns (uint[] memory amounts);
    
    function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts);
    
    function addLiquidity(
      address tokenA,
      address tokenB,
      uint amountADesired,
      uint amountBDesired,
      uint amountAMin,
      uint amountBMin,
      address to,
      uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
      external
      payable
      returns (uint[] memory amounts);
}

contract Octopus is Ownable {
    ERC20 usdtToken = ERC20(0x1aD4B3aA5b6FAb51330471Ea976296d9393f6c65);

    IPriceConsumerV3EthUsd priceConsumer;
    IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    IERC20 kiboToken;
    
    struct Seller {
        bool isValid;
        uint256 collateral; //This is in USDT for PUT and in the underlying for CALL
        uint256 weiCollateral;
        uint256 notional;
        bool claimed;
    }
    
    struct Option {
        bool isValid;
        bool isPut;
        uint256 etherPriceInUSDTAtMaturity;
        uint256 optionWorth;
        mapping(address => Seller) sellers;
    }
    
    mapping(address => Option) public options;
    mapping(address => uint256) public kiboRewards;

    uint256 public totalFees;

    event OptionPurchase(address indexed option, address indexed buyer, uint256 weiNotional, uint256 usdCollateral, uint256 weiCollateral, uint256 premium);
    event RewardsIncreased(address indexed beneficiary, uint256 total);
    event RewardsWithdrawn(address indexed beneficiary, uint256 total);
    event ReturnedToSeller(address indexed option, address indexed seller, uint256 totalUSDTReturned, uint256 collateral, uint256 notional);
    event ReturnedToBuyer(address indexed option, address indexed buyer, uint256 totalUSDTReturned, uint256 _numberOfTokens);
    event OptionFinalPriceSet(address indexed option, uint256 ethPriceInUsdt, uint256 optionWorthInUsdt);

    constructor(IPriceConsumerV3EthUsd _priceConsumer, address _kiboToken) {
        priceConsumer = _priceConsumer;
        kiboToken = IERC20(_kiboToken);
    }

    //Alice / Seller
    function sell(address _optionAddress, uint256 _weiNotional) payable public {
        require(options[_optionAddress].isValid, "Invalid option");
        require(IOption(_optionAddress).getExpiresOn() > block.timestamp, "Expired option");
        
        (uint256 usdCollateral, uint256 weiCollateral) = calculateCollateral(_optionAddress, _weiNotional);
        
        require(msg.value >= weiCollateral, 'Invalid collateral');
        
        uint256 difference = msg.value - weiCollateral;
        if (difference > 0) {
            payable(msg.sender).transfer(difference);
        }
        
        IOption(_optionAddress).mint(address(this), _weiNotional);
        
        Seller storage seller = options[_optionAddress].sellers[msg.sender];
        
        //We sell the tokens for USDT in Uniswap, which is sent to the user
        uint256 premium = sellTokensInUniswap(_optionAddress, _weiNotional);
        
        //We collect fees
        uint256 feesToCollect = weiCollateral / 100;
        totalFees += feesToCollect;
        
        if (options[_optionAddress].isPut) {
            //We keep the collateral in USDT
            uint256 usdtCollateral = sellEthForUSDTInUniswap(weiCollateral - feesToCollect);
            seller.collateral += usdtCollateral;
        } else {
            seller.collateral += weiCollateral - feesToCollect;
        }
        
        seller.isValid = true;
        seller.weiCollateral += weiCollateral;
        seller.notional += _weiNotional;
        
        //We emit an event to be able to send KiboTokens offchain, according to the difference against the theoretical Premium
        emit OptionPurchase(_optionAddress, msg.sender, _weiNotional, usdCollateral, weiCollateral, premium);
    }
    
    function calculateCollateral(address _optionAddress, uint256 _notionalInWei) public view returns (uint256, uint256) {
        require(options[_optionAddress].isValid, "Invalid option");
        
        //Collateral = Strike * Notional (in ETH, not WEI)
        uint256 collateralInUSD = IOption(_optionAddress).getStrike() * _notionalInWei / 1e18;
        
        //Gets the current price in WEI for 1 USDT
        uint256 usdtVsWeiCurrentPrice = uint256(priceConsumer.getLatestPrice());
        
        //Collateral in ETH
        return (collateralInUSD, collateralInUSD * usdtVsWeiCurrentPrice);
    }
    
    function claimCollateralAtMaturityForSellers(address _optionAddress) public {
        require(options[_optionAddress].isValid, "Invalid option");
        require(options[_optionAddress].etherPriceInUSDTAtMaturity > 0, "Still not ready");
        
        Seller storage seller = options[_optionAddress].sellers[msg.sender];
        
        require(seller.isValid, "Seller not valid");
        require(!seller.claimed, "Already claimed");
        
        seller.claimed = true;
        
        uint256 totalToReturn = getHowMuchToClaimForSellers(_optionAddress, msg.sender);
        require(totalToReturn > 0, 'Nothing to return');
        
        SafeERC20.safeTransfer(usdtToken, msg.sender, totalToReturn);
        
        emit ReturnedToSeller(_optionAddress, msg.sender, totalToReturn, seller.collateral, seller.notional);
    }
    
    function getHowMuchToClaimForSellers(address _optionAddress, address _seller) public view returns (uint256) {
        Seller memory seller = options[_optionAddress].sellers[_seller];
        if (seller.claimed) {
            return 0;
        }
        uint256 optionWorth = options[_optionAddress].optionWorth;
        return seller.collateral - seller.notional * optionWorth / 1e18;
    }
    
    function getHowMuchToClaimForBuyers(address _optionAddress, uint256 _numberOfTokens) public view returns (uint256) {
        uint256 optionWorth = options[_optionAddress].optionWorth;
        return _numberOfTokens * optionWorth / 1e18;
    }
    
    function claimCollateralAtMaturityForBuyers(address _optionAddress, uint256 _numberOfTokens) public {
        require(options[_optionAddress].isValid, "Invalid option");
        require(options[_optionAddress].etherPriceInUSDTAtMaturity > 0, "Still not ready");
        
        require(IERC20(_optionAddress).transferFrom(msg.sender, address(this), _numberOfTokens), "Transfer failed");
        
        uint256 totalToReturn = getHowMuchToClaimForBuyers(_optionAddress, _numberOfTokens);
        
        SafeERC20.safeTransfer(usdtToken, msg.sender, totalToReturn);

        emit ReturnedToBuyer(_optionAddress, msg.sender, totalToReturn, _numberOfTokens);
    }
    
    function withdrawKiboTokens() public {
        require(kiboRewards[msg.sender] > 0, "Nothing to withdraw");
        uint256 total = kiboRewards[msg.sender];
        kiboRewards[msg.sender] = 0;
        SafeERC20.safeTransfer(kiboToken, msg.sender, total);
        emit RewardsWithdrawn(msg.sender, total);
    }

    // Public functions
    
    // Returns the amount in USDT if you sell 1 KiboToken in Uniswap
    function getKiboSellPrice() public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(kiboToken);
        path[1] = address(usdtToken);
        uint[] memory amounts = uniswapRouter.getAmountsOut(1e18, path);
        return amounts[1];
    }
    
    // Returns the amount in USDT if you buy 1 KiboToken in Uniswap
    function getKiboBuyPrice() public view returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(usdtToken);
        path[1] = address(kiboToken);
        uint[] memory amounts = uniswapRouter.getAmountsIn(1e18, path);
        return amounts[0];
    }
    
    // Internal functions
    
    function sellTokensInUniswap(address _optionAddress, uint256 _tokensAmount) internal returns (uint256)  {
        address[] memory path = new address[](2);
        path[0] = _optionAddress;
        path[1] = address(usdtToken);
        IERC20(_optionAddress).approve(address(uniswapRouter), _tokensAmount);
        // TODO: uint256[] memory amountsOutMin = uniswapRouter.getAmountsOut(_tokensAmount, path);
        // Use amountsOutMin[1]
        uint[] memory amounts = uniswapRouter.swapExactTokensForTokens(_tokensAmount, 0, path, msg.sender, block.timestamp);
        return amounts[1];
    }
    
    function sellEthForUSDTInUniswap(uint256 _weiAmount) public returns (uint256)  {
        address[] memory path = new address[](2);
        path[0] = uniswapRouter.WETH();
        path[1] = address(usdtToken);
        // TODO: uint256[] memory amountsOutMin = uniswapRouter.getAmountsOut(_tokensAmount, path);
        // Use amountsOutMin[1]
        uint[] memory amounts = uniswapRouter.swapExactETHForTokens{value:_weiAmount}(0, path, address(this), block.timestamp);
        return amounts[1];
    }
    
    function createPairInUniswap(address _optionAddress, uint256 _totalTokens, uint256 _totalUSDT) internal returns (uint amountA, uint amountB, uint liquidity) {
        uint256 allowance = usdtToken.allowance(address(this), address(uniswapRouter));
        if (allowance > 0 && allowance < _totalUSDT) {
            SafeERC20.safeApprove(usdtToken, address(uniswapRouter), 0);
        }
        if (allowance == 0) {
            SafeERC20.safeApprove(usdtToken, address(uniswapRouter), _totalUSDT);
        }
        IERC20(_optionAddress).approve(address(uniswapRouter), _totalTokens);
        (amountA, amountB, liquidity) = uniswapRouter.addLiquidity(_optionAddress, address(usdtToken), _totalTokens, _totalUSDT, 0, 0, msg.sender, block.timestamp);
    }

    //Admin functions
    
    function _addKiboRewards(address _beneficiary, uint256 _total) public onlyOwner {
        kiboRewards[_beneficiary] += _total;
        emit RewardsIncreased(_beneficiary, _total);
    }
    
    function _deactivateOption(address _optionAddress) public onlyOwner {
        require(options[_optionAddress].isValid, "Already not activated");
        options[_optionAddress].isValid = false;
    }
    
    function _activateETHOption(address _optionAddress, uint256 _uniswapInitialUSDT, uint256 _uniswapInitialTokens, bool _createPair, bool _isPut) public payable onlyOwner {
        require(IOption(_optionAddress).getExpiresOn() > block.timestamp, "Expired option");
        require(!options[_optionAddress].isValid, "Already activated");
        require(msg.value > 0, "Collateral cannot be zero");
        
        options[_optionAddress].isValid = true;
        options[_optionAddress].isPut = _isPut;

        IOption(_optionAddress).mint(address(this), _uniswapInitialTokens);
        
        Seller storage seller = options[_optionAddress].sellers[msg.sender];
        
        if (_isPut) {
            //We keep the collateral in USDT
            uint256 usdtCollateral = sellEthForUSDTInUniswap(msg.value);
            seller.collateral = usdtCollateral;
        } else {
            seller.collateral = msg.value;
        }

        seller.isValid = true;
        seller.weiCollateral = msg.value;
        seller.notional = _uniswapInitialTokens;
        
        SafeERC20.safeTransferFrom(usdtToken, msg.sender, address(this), _uniswapInitialUSDT);
        
        if (_createPair) {
            createPairInUniswap(_optionAddress, _uniswapInitialTokens, _uniswapInitialUSDT);
        }
    }
    
    function _setEthFinalPriceAtMaturity(address _optionAddress) public onlyOwner {
        require(options[_optionAddress].isValid, "Invalid option");
        require(options[_optionAddress].etherPriceInUSDTAtMaturity == 0, "Already set");
        require(IOption(_optionAddress).getExpiresOn() < block.timestamp, "Still not expired");
        
        //Gets the price in WEI for 1 usdtToken
        uint256 usdPriceOfEth = uint256(priceConsumer.getLatestPrice());
        //I need the price in USDT for 1 ETH
        uint256 spotPrice = uint256(1 ether) / usdPriceOfEth;
        uint256 strike = IOption(_optionAddress).getStrike();

        uint256 optionWorth = 0;
    
        if (options[_optionAddress].isPut && spotPrice < strike) {
            optionWorth = strike - spotPrice;
        }
        else if (!options[_optionAddress].isPut && spotPrice > strike) {
            optionWorth = spotPrice - strike;
        }
        
        options[_optionAddress].etherPriceInUSDTAtMaturity = spotPrice;
        options[_optionAddress].optionWorth = optionWorth * 1e6;
        
        emit OptionFinalPriceSet(_optionAddress, spotPrice, optionWorth);
    }
    
    function _withdrawFees() public onlyOwner {
        require(totalFees > 0, 'Nothing to claim');
        uint256 amount = totalFees;
        totalFees = 0;
        payable(msg.sender).transfer(amount);
    }

    function _withdrawETH(uint256 _amount) public onlyOwner {
        payable(msg.sender).transfer(_amount);
    }
    
    function _withdrawUSDT(uint256 _amount) public onlyOwner {
        SafeERC20.safeTransfer(usdtToken, msg.sender, _amount);
    }
    
    function _withdrawKibo(uint256 _amount) public onlyOwner {
        SafeERC20.safeTransfer(kiboToken, msg.sender, _amount);
    }
    
    function getSeller(address _optionAddress, address _seller) public view returns (bool _isValid, uint256 _collateral, uint256 _weiCollateral, uint256 _notional, bool _claimed) {
        Seller memory seller = options[_optionAddress].sellers[_seller];
        return (seller.isValid, seller.collateral, seller.weiCollateral, seller.notional, seller.claimed);
    }

    receive() external payable {
        revert();
    }
}