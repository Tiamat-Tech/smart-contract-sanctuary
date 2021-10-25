// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

import "./token/ERC20/IERC20.sol";
import "./math/SafeMath.sol";
import "./utils/BasicContract.sol";
//import "./utils/Initializable.sol";
import "./utils/SafeERC20.sol";
import { HighLevelSystemExecution_ETH } from "./libs/HighLevelSystemExecution_ETH.sol";
import { SafeERC20 } from "./utils/SafeERC20.sol";

/**
This is master branch of Eth

1.token存進來後，需要累積？還是直接deposit+stake？
2.-done- rebalance, restake
3.當DAI不夠提領時，要做把賺到的CRV swap成DAI？
4.review andrew's code change
5.add different tokens


 */

contract Cashbox_ETH is BasicContract {

    HighLevelSystemExecution_ETH.HLSConfig private HLSConfig ;
    HighLevelSystemExecution_ETH.StableCoins private StableCoins ;
    HighLevelSystemExecution_ETH.Position private position;

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    string public constant name = "Proof token of Ypool DAI";
    string public constant symbol = "pDAI_yPool";
    uint8 public constant decimals = 18;
    uint256 private totalSupply_ ; // 使用者存錢到cashbox後，return給使用者的proof Token的總供給量

    bool public activable;
    address private dofin;
    uint private deposit_limit;   
    
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
    event Transfer(address indexed from, address indexed to, uint tokens);
    mapping(address => uint256) private balances;
    mapping(address => mapping (address => uint256)) private allowed;

    constructor(
        uint  _supplyFund_percentage, 
        address[] memory _addrs, 
        address _dofin, 
        uint _deposit_limit
    ){
        position = HighLevelSystemExecution_ETH.Position({
            a_amount: 0, // DAI amount
            LP_token_amount:0, // yCRv amount
            token_a: _addrs[0], // DAI token address
            LP_token: _addrs[1],// yCrv token address
            supplyFund_percentage: _supplyFund_percentage// ex:如果有75%要進入策略，那這個變數就會是75
        });
        
        activable = true;
        dofin = _dofin;
        deposit_limit = _deposit_limit;

    }

    modifier checkActivable(){
        require(activable == true, 'CashBox is not Activable');
        _;
    }

    function setConfig(address[] memory _config) public  {
        /* TODO 如果沒有deposit contract的pool怎麼辦？ */
        HLSConfig.CurveConfig.curveFi_Swap = _config[0];//Base Pool StableSwap Contract
        HLSConfig.CurveConfig.curveFi_Gauge = _config[1];//Liquidity Gauge Contract
        HLSConfig.CurveConfig.curveFi_Deposit = _config[2];//Base Pool Deposit Contract, not necessary, don't always exist for every pool
        HLSConfig.CurveConfig.curveFi_LPToken = _config[3];
        HLSConfig.CurveConfig.curveFi_CRVToken = _config[4];
        HLSConfig.CurveConfig.curveFi_CRVMinter = _config[5];
        HLSConfig.LinkConfig.CRV_USD = _config[6];
        HLSConfig.LinkConfig.DAI_USD = _config[7];

    }

    // function setStableCoins(address[] memory _stablecoins) public onlyOwner {
    //     //StableCoins.WBNB = _stablecoins[0];
    //     //StableCoins.CAKE = _stablecoins[1];
    //     StableCoins.DAI = _stablecoins[0];
    //     StableCoins.USDC = _stablecoins[1];
    //     StableCoins.USDT = _stablecoins[2];
    //     StableCoins.TUSD = _stablecoins[3];
    // }

    function setActivable(bool _activable) public  {
        activable = _activable;
    }

    function getPosition() public  view returns(HighLevelSystemExecution_ETH.Position memory) {
        return position;
    }

    // User deposits DAI to this cashbox, we return proofToken to the user.
    function userDepositToCashbox(address _token, uint _deposit_amount) public checkActivable returns(bool) {

        require(_deposit_amount <= SafeMath.mul(deposit_limit, 10**IERC20(position.token_a).decimals()), "Deposit too much!");
        require(_token == position.token_a, "Wrong token to deposit.Require DAI in this cashbox");
        require(_deposit_amount > 0, "Deposit amount must be larger than 0.");

        // Calculation of pToken amount need to mint
        uint shares = getDepositAmountOut(_deposit_amount); // 根據user存入的DAI數量跟總DAI資產數量的比例，來決定user這次存入的DAI可以得到多少proofToken
        
        // Mint proofToken 
        mint(msg.sender, shares);
        // Transfer DAI from user to cashbox
        IERC20(position.token_a).transferFrom(msg.sender, address(this),  _deposit_amount);
        
        //如果存完錢，cashbox的錢比最低要求數量還高，就把錢存進curve
        //checkAddNewFunds();

        return true ;
    }

    function getDepositAmountOut(uint _deposit_amount) public view returns (uint) {
        uint totalAssets = getTotalAssets();
        uint shares;
        if (totalSupply_ > 0) {
            shares = SafeMath.div(SafeMath.mul(_deposit_amount, totalSupply_), totalAssets);
        } else {
            shares = _deposit_amount;
        }
        return shares;
    }

    // pending crv   ( in gauge )         , == pendingCrvAmount * Crv price  => getCrvPrice?
    // claimed crv   ( in this contract ) , == 0 , 何時要swap crv for dai?    => 不留crv，都換成dai再redeposit
    // staked lp     ( in gauge )         , == getStakedAmount * yCrv price  => getyCrvPrice?
    // not staked lp ( in cashbox? )      , == 0 , always stake all lp
    // free funds    ( in cashbox )       , TODO what is free funds lower bound?
    function getTotalAssets() public view returns (uint) {

        uint pendingCRVAmount = HighLevelSystemExecution_ETH.getPendingCRV(HLSConfig);//單位？wei,decimal？ // test pendingCRVAmount = 10
        int CRVPrice = HighLevelSystemExecution_ETH.getCRVPrice(HLSConfig.LinkConfig); // CRV/USD // test CRVPrice = 10
        
        uint CRVValueInUSD = SafeMath.mul( pendingCRVAmount , uint(CRVPrice) ) ; // test CRVValueInUSD = 100
        // Toekn == DAI
        int stableCoinPrice = HighLevelSystemExecution_ETH.getStableCoinPrice(HLSConfig.LinkConfig); // test stableCoinPrice = 10
        uint256 CRV_EquivalentAmount_InStableCoin = SafeMath.div( CRVValueInUSD , uint(stableCoinPrice) );//pendingCRV相當於多少DAI // test CRV_EquivalentAmount_InStableCoin = 10


        uint totalLPBalance = HighLevelSystemExecution_ETH.curveLPTokenBalance(HLSConfig); // test totalLPBalance = 20 ;
        uint LP_EquivalentAmount_InStableCoin = HighLevelSystemExecution_ETH.curveLPTokenEquivalence(HLSConfig, totalLPBalance, 0); // test LP_EquivalentAmount_InStableCoin = 10 
        // 第三個參數設為0：表示要找yCrv對DAI(ypool第0個token)的equivalence
        

        uint cashboxFreeFunds =  IERC20(position.token_a).balanceOf(address(this)) ; // test cashboxFreeFunds = 10

        uint total_assets = SafeMath.add( SafeMath.add( CRV_EquivalentAmount_InStableCoin , LP_EquivalentAmount_InStableCoin) , cashboxFreeFunds ) ;//以DAI為計算基準

        return total_assets; // test total_assets = 30 ;
    }

    // TODO 什麼時候rebalance,什麼時候checkEntry
    // TODO position.a_amount 表示的是 ? => 讓position.a_amount表示的是已經有多少錢deposit
    function checkAddNewFunds() public view  checkActivable returns(uint) {
        uint free_funds = IERC20(position.token_a).balanceOf(address(this));
        // 這個contract現在裡面有的DAI
        uint strategy_balance = getTotalAssets();
        // 現在已經在策略裡面跑的DAI
        uint previous_free_funds = SafeMath.div(SafeMath.mul(strategy_balance, 100), position.supplyFund_percentage);
        // 上一次rebalance,supply之前，contract裡面的DAI
        uint condition = SafeMath.div(SafeMath.mul(previous_free_funds, SafeMath.sub(100, position.supplyFund_percentage)), 100);
        // 上一次rebalance,supply時，預設rebalance,supply後要留在contract裡面的DAI

        if (free_funds > condition ) {
            if( position.a_amount == 0 ){ 
                // 本來沒有已經deposit的錢，user存完一次錢進cashbox後，free_funds大於condition
                // Need to enter
                return 1 ; // 開始把錢存進curve
            }
            else{
                // 本來已經有deposit錢，要做的是deposit多出的這些錢(free_funds-condition) 進curve
                // Need to rebalance 
                return 2 ;
            }
        }
        return 0 ;
    }

    function enter(uint _type) public  checkActivable {
        position = HighLevelSystemExecution_ETH.enterPosition(HLSConfig, position, _type);
    }

    function exit(uint _type) public  checkActivable {
        position = HighLevelSystemExecution_ETH.exitPosition(HLSConfig, position, _type);
    }

    // TODO rebalance ( = unstake + withdraw + deposit + stake)
    // TODO 在checkAddNewFunds()中要的功能：本來已經有deposit錢，要做的是deposit多出的這些錢(free_funds-condition) 進curve
    function rebalance() public  checkActivable {
        position = HighLevelSystemExecution_ETH.exitPosition(HLSConfig, position, 1);
        position = HighLevelSystemExecution_ETH.enterPosition(HLSConfig, position, 1);
    }
    
    // TODO restake ( = unstake + stake )
    function restake() public  checkActivable {
        position = HighLevelSystemExecution_ETH.exitPosition( HLSConfig, position, 2);
        position = HighLevelSystemExecution_ETH.enterPosition( HLSConfig, position, 2);
    }
    
    // TODO - done - 把withdraw改成user從cahsbox提出錢
    // TODO enterposition, exitposition 的position設定
    function userWithdrawFromCashbox(uint proofToken_withdraw_amount) public checkActivable returns (bool) {

        require(proofToken_withdraw_amount <= balanceOf(msg.sender), "Wrong amount to withdraw."); 
        // 使用者輸入想用多少proofToken來提領存入的DAI，這個proofToken的數量須小於使用者所擁有的proofToken數量
        
        uint free_funds = IERC20(position.token_a).balanceOf(address(this));
        uint totalAssets = getTotalAssets();
        uint withdraw_funds = SafeMath.div(SafeMath.mul(proofToken_withdraw_amount, totalAssets), totalSupply_);///換算後要提出的DAI的量
        bool need_rebalance = false;
        // If no enough amount of free_funds can transfer will trigger exit position
        if ( withdraw_funds > free_funds ) {
            HighLevelSystemExecution_ETH.exitPosition(HLSConfig, position, 1);
            need_rebalance = true;
        }

        // TODO 如果withdraw完，DAI不夠使用者提領，就要做swap CRV to DAI
        // implement swap?

        
        // Will charge 20% fees
        burn(msg.sender, proofToken_withdraw_amount);
        uint  dofin_value = SafeMath.div(SafeMath.mul(20, withdraw_funds), 100);
        uint  user_value = SafeMath.div(SafeMath.mul(80, withdraw_funds), 100);
        IERC20(position.token_a).transferFrom(address(this), dofin, dofin_value);
        IERC20(position.token_a).transferFrom(address(this), msg.sender, user_value);
        
        if (need_rebalance == true) {
            HighLevelSystemExecution_ETH.enterPosition(HLSConfig, position, 1);
        }
        
        return true;

    }
    
    function getWithdrawAmount(uint _ptoken_amount) public view returns (uint) {
        uint totalAssets = getTotalAssets(); // test 30 ;
        uint value = SafeMath.div(SafeMath.mul(_ptoken_amount, totalAssets), totalSupply_); // 30
        uint user_value = SafeMath.div(SafeMath.mul(80, value), 100); // 24
        
        return user_value;
    }


//-----以下for pToken(proof toekn) -----


    function totalSupply() public view returns (uint256) {
        
        return totalSupply_;
    }

    function balanceOf(address account) public view returns (uint) {
        
        return balances[account];
    }

    function transfer(address recipient, uint amount) public returns (bool) {
        require(amount <= balances[msg.sender]);
        balances[msg.sender] = balances[msg.sender].sub(amount);
        balances[recipient] = balances[recipient].add(amount);
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function approve(address spender, uint amount) public returns (bool) {
        allowed[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function allowance(address owner, address spender) public view returns (uint) {
        
        return allowed[owner][spender];
    }

    function transferFrom(address owner, address buyer, uint numTokens) public returns (bool) {
        require(numTokens <= balances[owner]);    
        require(numTokens <= allowed[owner][msg.sender]);
    
        balances[owner] = balances[owner].sub(numTokens);
        allowed[owner][msg.sender] = allowed[owner][msg.sender].sub(numTokens);
        balances[buyer] = balances[buyer].add(numTokens);
        emit Transfer(owner, buyer, numTokens);
        return true;
    }

    function mint(address account, uint256 amount) internal returns (bool) {
        require(account != address(0), "ERC20: mint to the zero address");

        totalSupply_ += amount;
        balances[account] += amount;
        emit Transfer(address(0), account, amount);

        return true;
    }

    function burn(address account, uint256 amount) internal returns (bool) {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            balances[account] = accountBalance - amount;
        }
        totalSupply_ -= amount;
        emit Transfer(account, address(0), amount);

        return true;
    }

//-----以上for pToken(proof toekn) -----


//-----以下for getting information from cashbox, necessary? ----
    
    // // @notice Get amount of CurveFi LP tokens staked in the Gauge
    // function checkStakedToken() public view returns(uint256) { 
    //     HighLevelSystemExecution_ETH.curveLPTokenStaked(HLSConfig);
    // }

    // // @notice Get amount of unstaked CurveFi LP tokens (which lay on this contract)
    // function checkUnstakedLpToken() public view returns(uint256) { 
    //     HighLevelSystemExecution_ETH.curveLPTokenUnstaked(HLSConfig);
    // }

    // //@notice Get full amount of Curve LP tokens available for this contract
    // function checkTotalLpTokenBalance() public view returns(uint256) { 
    //     HighLevelSystemExecution_ETH.curveLPTokenBalance(HLSConfig); 
    // }
    
    // // TODO 注意struct的傳遞流程是否有中斷？
    // function claimCrvToken() internal {
    //     HighLevelSystemExecution_ETH.claimCRVReward(HLSConfig);
    // }


    // //@notice Balances of stablecoins available for withdraw normalized to 18 decimals
    // function getNormalizedBalance() public view returns(uint256){
    //     HighLevelSystemExecution_ETH.normalizedBalance(HLSConfig); // will call HighLevelSystemExecution_ETH.normalzie() inside HighLevelSystemExecution_ETH.normalizedBalance();
    // }

}