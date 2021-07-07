pragma solidity 0.8.0;

import "openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/access/Ownable2.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

interface Memecoin {
    function maxTxAmount() external pure returns (uint256);
}

contract BuyBackBot is Ownable2 {

	using SafeMath for uint256;

	address public tokenAddress;
	address public ethAddress;
	address public pairAddress;

	uint256 public nextThreshold;
	uint256 public previousRate;

	uint256 public minBuyBack;
	uint256 public upperDiviation;

	IUniswapV2Router02 private uniswapV2Router;

	bool public isReady;
	bool private initialized;

	event randomNumGenerated (
		uint256 num
	);

	event msgSenderChecker (
		address senderAddress
	);

	function initialize() public override {
		require(!initialized, "Contract instance has already been initialized");
		super.initialize();
		uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
		ethAddress = uniswapV2Router.WETH();
		previousRate = 0;

		minBuyBack = 4 * 10**18;
		upperDiviation = 2 * 10**18;

		generateNextThreshold();

		isReady = false;
		initialized = true;
	}

	receive() external payable {
		address sender = msg.sender;
		execute(sender);
		// if (sender == tokenAddress && ready) {
		// 	execute();
		// }
	}

	function toggleReady(bool isReady_) public onlyOwner {
		isReady = isReady_;
	}

	function registerToken(address tokenAddress_, address pairAddress_) public onlyOwner {
		tokenAddress = tokenAddress_;
		pairAddress = pairAddress_;

		isReady = true;
	}

	function setThresholdRange(uint256 minThreshold, uint256 allowedDeviation) public onlyOwner {
		minBuyBack = minThreshold;
		upperDiviation = allowedDeviation;

		generateNextThreshold();
	}

	function generateNextThreshold() public onlyOwner {
		uint seed = 12;
		uint256 random = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, seed))) % upperDiviation;
		emit randomNumGenerated(random);
		nextThreshold = minBuyBack.add(random);
	}

	function execute(address sender) private {
		emit msgSenderChecker(sender);
		if (isReady) {
			uint256 currentBalance = address(this).balance;
			if (nextThreshold <= currentBalance) {
				uint256 currentBalanceOfToken = IERC20(tokenAddress).balanceOf(pairAddress);
				uint256 currentBalanceOfEth = IERC20(ethAddress).balanceOf(pairAddress);
				uint256 ratio = currentBalanceOfEth.div(currentBalanceOfToken);
				if (ratio < previousRate) {
					buyback();
					previousRate = ratio;
				}
				generateNextThreshold();
			}
		}
	}

	function buyback() public onlyOwner {
		uint256 currentBalance = address(this).balance;
		uint256 maxTxnAllowed = Memecoin(tokenAddress).maxTxAmount();
		uint256 coinTotalSupply = IERC20(tokenAddress).totalSupply();

		if (coinTotalSupply > maxTxnAllowed) {
			_buyBackExactToken(maxTxnAllowed, currentBalance);
		} else {
			_buyBackExactEth(currentBalance);
		}
	}

	function _buyBackExactEth (uint256 ethAmount) private {
		address[] memory path = new address[](2);
        path[0] = ethAddress;
        path[1] = tokenAddress;

        uint deadline = block.timestamp + 3000;
        
        try uniswapV2Router.swapExactETHForTokens{ 
            value: ethAmount 
        }(
            0, 
            path, 
            address(this), 
            deadline
        ){
        } catch {
            // emit error detail?
        }
	}

	function _buyBackExactToken (uint256 tokenAmount, uint256 ethAmount) private {
		address[] memory path = new address[](2);
        path[0] = ethAddress;
        path[1] = tokenAddress;

        uint deadline = block.timestamp + 3000;

        uniswapV2Router.swapETHForExactTokens{value: ethAmount}(
        	tokenAmount,
        	path,
        	address(this),
        	deadline
        );
	}
}