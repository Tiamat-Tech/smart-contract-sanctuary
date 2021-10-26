// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "../utils/Initializable.sol";
import "../utils/BasicContract.sol";
import "../token/ERC20/IERC20.sol";
import "../utils/SafeERC20.sol";
import "../math/SafeMath.sol";

import "../interfaces/curve/yPool/ICurveFi_DepositY.sol";
import "../interfaces/curve/yPool/ICurveFi_GaugeY.sol";
import "../interfaces/curve/yPool/ICurveFi_Minter.sol";
import "../interfaces/curve/yPool/ICurveFi_SwapY.sol";
import "../interfaces/curve/IYERC20.sol";

library CurveExecution_ETH {

     // HighLevelSystemExecution_ETH config
    struct CurveConfig {
        address curveFi_Swap;
        address curveFi_Gauge;
        address curveFi_Deposit;
        address curveFi_LPToken;
        address curveFi_CRVToken;
        address curveFi_CRVMinter;
    }
    
    // function setupOtherCurveAddress(CurveConfig memory self) public view {
    //     //StableSwapY.vy
    //     self.curveFi_Swap = ICurveFi_DepositY(self.curveFi_Deposit).curve();
    //     //CurveToken.vy
    //     self.curveFi_LPToken = ICurveFi_DepositY(self.curveFi_Deposit).token();
    //     require(ICurveFi_GaugeY(self.curveFi_Gauge).lp_token() == address(self.curveFi_LPToken), "CurveFi LP tokens do not match");        
    //     self.curveFi_CRVToken = ICurveFi_GaugeY(self.curveFi_Gauge).crv_token();
    // }
        
    // TODO - done - add_liquidity可以傳uint嗎？還是一定要傳uint[4]? => 不行。要傳uint[4]
    // TODO - done - 如何接收add_liquidity後回傳的lptoken? => 不用，沒有回傳值
    function deposit(CurveConfig memory self, uint256[4] memory _amount) public {
        ICurveFi_DepositY(self.curveFi_Deposit).add_liquidity(_amount, 0);
    }

    function stakeAll(CurveConfig memory self, uint256 _stakeAmount) public {
        ICurveFi_GaugeY(self.curveFi_Gauge).deposit(_stakeAmount);
    }

    // TODO - done - remove_liquidity_imbalance跟remove_liquidity的差異是？
    // TODO - done - 什麼是remove_liquidiy_imbalance的max_burn_amount?(第二個輸入參數)
    function withdrawFromDeposit(CurveConfig memory self, uint256[4] memory _uamounts, uint256 _max_burn_amount) public {
        IERC20(self.curveFi_LPToken).approve(self.curveFi_Deposit, _max_burn_amount);
        ICurveFi_DepositY(self.curveFi_Deposit).remove_liquidity_imbalance(_uamounts, _max_burn_amount);
        // 在DepositY中，
        // remove_liquidity_imbalance:給定要提出的dai,usdc,usdt,tusd&最大容許燒毀的lptoken -> 會呼叫SwapY的remove_liduiqidity_imbalance
        // remove_liquidiy_onecoin:只提出一種幣 -> 會呼叫yswap的remove_liduiqidity_imbalance
        // remove_liquidiy:一次提出四種幣 -> 會呼叫yswap的remove_liduiqidity
    }

    function unstakeAllLPFromGauge(CurveConfig memory self, uint256 _unstakeShares) public {
        ICurveFi_GaugeY(self.curveFi_Gauge).withdraw(_unstakeShares);
    }

    function getStableCoins(CurveConfig memory self) public view returns(address[4] memory ){

        address[4] memory stableCoins ;
        // TODO - done - 可直接寫下面這樣嗎？=>可，看deposit的interface，有定義ㄑ
        stableCoins = ICurveFi_DepositY(self.curveFi_Deposit).underlying_coins();

        return stableCoins ;
    }
    
    function getPendingCRV(CurveConfig memory self) public view returns(uint256) {
        uint256 pendingCRV = ICurveFi_GaugeY(self.curveFi_Gauge).claimable_tokens(address(this));
        return pendingCRV ;
    }

    // notice that when i==0 || i==3 , decimal == 18 ( DAI & TUSD )
    // notice that when i==1 || i==2 , decimal == 6  ( USDC & USDT )
    function calc_withdraw_one_coin(CurveConfig memory self, uint256 _token_amount, int128 i)public view returns(uint256){
        uint256 equivalentValue = ICurveFi_DepositY(self.curveFi_Deposit).calc_withdraw_one_coin(_token_amount, i);
        return equivalentValue ;
    }

    function getLPSupply(CurveConfig memory self) public view returns(uint256) {
        return IERC20(self.curveFi_LPToken).totalSupply();
    }
    
    function getCurveStakedLPToken(CurveConfig memory self) public view returns(uint256) {
        return ICurveFi_GaugeY(self.curveFi_Gauge).balanceOf(address(this));
    }

    // swap contract裡面的function coins(i)可以read第i種token的address，如yDAI,yUSDC...等
    function getSwapContractCoinAddress(CurveConfig memory self, int128 i) public view returns(address) {
        return ICurveFi_SwapY(self.curveFi_Swap).coins(i);
    }
            
    // swap contract裡面的balances(i)表示的是對於每種token，這份swap contract擁有多少個(wei)
    function getSwapContractCoinBalance(CurveConfig memory self, int128 i) public view returns(uint256) {
        return ICurveFi_SwapY(self.curveFi_Swap).balances(i);
    }

    //就是example的crvTokenClaim
    function mint(CurveConfig memory self) public {
        ICurveFi_Minter(self.curveFi_CRVMinter).mint(self.curveFi_Gauge);
    }

}