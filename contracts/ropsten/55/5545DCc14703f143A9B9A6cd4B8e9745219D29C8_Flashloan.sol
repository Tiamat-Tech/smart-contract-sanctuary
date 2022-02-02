pragma solidity ^0.6.6;

import "./aave/FlashLoanReceiverBase.sol";
import "./aave/ILendingPoolAddressesProvider.sol";
import "./aave/ILendingPool.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Flashloan is FlashLoanReceiverBase {

    using SafeMath for uint256;
    IUniswapV2Router02 uniswapV2Router;
    IUniswapV2Router02 sushiswapV1Router;
    uint deadline;
    IERC20 dai;
    address daiTokenAddress;
    uint256 amountToTrade;
    uint256 tokensOut;

    event SwapFailed(string _endpoint);
    
    /**
        Initialize deployment parameters
     */
    constructor(
        address _aaveLendingPool, 
        IUniswapV2Router02 _uniswapV2Router, 
        IUniswapV2Router02 _sushiswapV1Router
        ) FlashLoanReceiverBase(_aaveLendingPool) public {

            // instantiate SushiswapV1 and UniswapV2 Router02
            sushiswapV1Router = IUniswapV2Router02(address(_sushiswapV1Router));
            uniswapV2Router = IUniswapV2Router02(address(_uniswapV2Router));

            // setting deadline to avoid scenario where miners hang onto it and execute at a more profitable time
            deadline = block.timestamp + 300; // 5 minutes
    }

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address _reserve,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _params
    )
        external
        override
    {
        require(_amount <= getBalanceInternal(address(this), _reserve), "Invalid balance, was the flashLoan successful?");


        // execute arbitrage strategy
        try this.executeArbitrage() {
        } catch Error(string memory) {
            // Reverted with a reason string provided
        } catch (bytes memory) {
            // failing assertion, division by zero.. blah blah
        }

        uint totalDebt = _amount.add(_fee);
        transferFundsBackToPoolInternal(_reserve, totalDebt);
    }

    function getDepth(address _reserve) public view returns(uint) {
        return getBalanceInternal(address(this), _reserve);
    }

    /**
        Flash loan 1000000000000000000 wei (1 ether) worth of `_asset`
     */
    function flashloan(address _asset) public onlyOwner {
        bytes memory data = "";
        uint amount = 1 ether;

        ILendingPool lendingPool = ILendingPool(addressesProvider.getLendingPool());
        lendingPool.flashLoan(address(this), _asset, amount, data);
    }

     /**
        The specific cross protocol swaps that makes up your arb strategy
        UniswapV2 -> SushiswapV1 example below
     */
    function executeArbitrage() public {

        // Trade 1: Execute swap of Ether into designated ERC20 token on UniswapV2
        try uniswapV2Router.swapETHForExactTokens{ 
            value: amountToTrade 
        }(
            amountToTrade, 
            getPathForETHToToken(daiTokenAddress), 
            address(this), 
            deadline
        ){
        } catch {
            emit SwapFailed("swapETHForExactTokens");
            // error handling when arb failed due to trade 1
        }
        
        // Re-checking prior to execution since the NodeJS bot that instantiated this contract would have checked already
        uint256 tokenAmountInWEI = tokensOut.mul(1000000000000000000); //convert into Wei
        uint256 estimatedETH = getEstimatedETHForToken(tokensOut, daiTokenAddress)[0]; // check how much ETH you'll get for x number of ERC20 token
        
        // grant uniswap / sushiswap access to your token, DAI used since we're swapping DAI back into ETH
        dai.approve(address(uniswapV2Router), tokenAmountInWEI);
        dai.approve(address(sushiswapV1Router), tokenAmountInWEI);

        // Trade 2: Execute swap of the ERC20 token back into ETH on Sushiswap to complete the arb
        try sushiswapV1Router.swapExactTokensForETH (
            tokenAmountInWEI, 
            estimatedETH, 
            getPathForTokenToETH(daiTokenAddress), 
            address(this), 
            deadline
        ){
        } catch {
            emit SwapFailed("swapExactTokensForETH");
            // error handling when arb failed due to trade 2    
        }
    }

    /**
        sweep entire balance on the arb contract back to contract owner
     */
    function WithdrawBalance() public payable onlyOwner {
        
        // withdraw all ETH
        msg.sender.call{ value: address(this).balance }("");
        
        // withdraw all x ERC20 tokens
        dai.transfer(msg.sender, dai.balanceOf(address(this)));
    }

    /**
        Flash loan x amount of wei's worth of `_flashAsset`
        e.g. 1 ether = 1000000000000000000 wei
     */
    // function flashloan (
    //     address _flashAsset, 
    //     uint _flashAmount,
    //     address _daiTokenAddress,
    //     uint _amountToTrade,
    //     uint256 _tokensOut
    //     ) public onlyOwner {
            
    //     bytes memory data = "";

    //     daiTokenAddress = address(_daiTokenAddress);
    //     dai = IERC20(daiTokenAddress);
        
    //     amountToTrade = _amountToTrade; // how much wei you want to trade
    //     tokensOut = _tokensOut; // how many tokens you want converted on the return trade     

    //     // call lending pool to commence flash loan
    //     ILendingPool lendingPool = ILendingPool(addressesProvider.getLendingPool());
    //     lendingPool.flashLoan(address(this), _flashAsset, uint(_flashAmount), data);
    // }

    /**
        Using a WETH wrapper here since there are no direct ETH pairs in Uniswap v2
        and sushiswap v1 is based on uniswap v2
     */
    function getPathForETHToToken(address ERC20Token) private view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = ERC20Token;
    
        return path;
    }

    /**
        Using a WETH wrapper to convert ERC20 token back into ETH
     */
     function getPathForTokenToETH(address ERC20Token) private view returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = ERC20Token;
        path[1] = sushiswapV1Router.WETH();
        
        return path;
    }

    /**
        helper function to check ERC20 to ETH conversion rate
     */
    function getEstimatedETHForToken(uint _tokenAmount, address ERC20Token) public view returns (uint[] memory) {
        return uniswapV2Router.getAmountsOut(_tokenAmount, getPathForTokenToETH(ERC20Token));
    }

    /**
        helper function to check ETH to ERC20 conversion rate
     */
    function getEstimatedTokenForETH(uint _ethAmount, address ERC20Token) public view returns(uint[] memory) {
        return uniswapV2Router.getAmountsOut(_ethAmount, getPathForETHToToken(ERC20Token));
    }
}