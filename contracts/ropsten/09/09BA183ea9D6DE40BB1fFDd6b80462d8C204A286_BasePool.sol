// "SPDX-License-Identifier: MIT"
pragma solidity >=0.6.6;
pragma experimental ABIEncoderV2;

import "./vendors/interfaces/IUniswapOracle.sol";
import "./vendors/interfaces/IERC20.sol";
import "./vendors/libraries/SafeMath.sol";
import "./vendors/libraries/SafeERC20.sol";
import "./vendors/libraries/Whitelist.sol";
import "./vendors/libraries/TxStorage.sol";



// helper methods for interacting with sending ETH that do not consistently return true/false
library TransferHelper {
    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }

}

contract BasePool is Whitelist, TxStorage {
    
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    address public _oracleAddress;
    address public _PACT;

    uint public _minBuy;
    uint public _price;

    event Deposit(uint amount, uint price);
    event Withdraw(uint tokensAmount, uint price);
    
 constructor (
        address governanceAddress,
        address oracleAddress,
        address PACT,
        uint minBuy,
        uint price
    ) {
        require (oracleAddress != address(0), "ORACLE ADDRESS SHOULD BE NOT NULL");
        require (PACT != address(0), "PACT ADDRESS SHOULD BE NOT NULL");

        _oracleAddress = oracleAddress;
        _PACT = PACT;
        
        _minBuy = minBuy == 0 ? 10000e18 : minBuy;
        _price = price == 0 ? 100000 : price; //USDT 

        SetGovernance(governanceAddress == address(0) ? msg.sender : governanceAddress);
        IUniswapOracle(_oracleAddress).update();
    }
    
    
    function buylimitsUpdate( uint minLimit) public onlyGovernance {
        _minBuy = minLimit;
    }
    

    function changeOracleAddress (address oracleAddress) 
      public 
      onlyGovernance {
        require (oracleAddress != address(0), "NEW ORACLE ADDRESS SHOULD BE NOT NULL");

        _oracleAddress = oracleAddress;
    }


	function calcPriceEthUdtPact(uint amountIn) public view returns (uint amountOut) {
        uint WETHPrice = IUniswapOracle(_oracleAddress).consultAB(amountIn);
        amountOut = WETHPrice.div(_price).mul(1e18);
	}


    function depositEthToToken() public onlyWhitelisted payable {
        uint amountIn = msg.value;
        IUniswapOracle(_oracleAddress).update();
        uint tokensAmount = calcPriceEthUdtPact(amountIn);
        IERC20 PACT = IERC20(_PACT);

        require(tokensAmount >= _minBuy);
        require(tokensAmount <= PACT.balanceOf(address(this)), "NOT ENOUGH PACT TOKENS ON BASEPOOl CONTRACT BALANCE");

        PACT.safeTransfer(msg.sender, tokensAmount);
        transactionAdd(tokensAmount,amountIn);

        emit Deposit(tokensAmount, amountIn);
    }
    

    function withdrawEthFromToken(uint index) external onlyWhitelisted {
        IERC20 PACT = IERC20(_PACT);
        checkTrransaction(msg.sender , index);
        (uint amount, uint price,,,) = getTransaction(msg.sender , index);
        
        require(address(this).balance >= price, "NOT ENOUGH ETH ON BASEPOOl CONTRACT BALANCE");
        require(PACT.allowance(msg.sender, address(this)) >= amount, "NOT ENOUGH DELEGATED PACT TOKENS ON DESTINATION BALANCE");

        closedTransaction(msg.sender, index);
        PACT.safeTransferFrom(msg.sender, amount);
        TransferHelper.safeTransferETH(msg.sender, price);

        emit Withdraw(amount, price);
    }





}