// SPDX-License-Identifier: MIT
/*
* The Control File for HedgeFund like activities.
* PRETNED THIS HAS NOTHING TO DO WITH LiftDAO or StableCoin but is the first idea to be generated
* And produce a return..
*
* Individuals will Stake assets with the hedge fund for it to investe as its sees fit.
* First use case will be the IdeaFund - it will stake some percentage of the IdeaFund
* Into the hedge fund so that we can invest it in other projects and collect a return.
* 
* I suggest the math on the hedgefund be the following - it pays a .25% (variable controlled)
* return every day, it has a 24 hour epoch that takes funds (older than 24 hours) * 1.0025 for the increase
* We are not including funds staked in the last 24 hours because they couldnt have been deployed yet
*
* This HedgeFund will issue HAIF tokens back to the stakers for redemption based on fund current value.
* Those tokens will be stored by the stakers wallet (individual or IdeaFund) - so that the value 
* of the HAIF staking is represented in the local wallet (allows us to move money into an investment account
* and still show value/growth in the IdeaFund)
*
* the upside of the .25% guaranteed daily increase is that the fundmanagers (US), get to take the spread between 
* the guaranteed .25% daily, and the actual return (presumption that it is positive!)
*
* three values exist in the tracking of this 
* public Total Staked Value growth .25% every day
* private Total Value (fund real growth/decline)
* private Hedge Manager Value (what we can collect for investing the money)
*/

// TODO needs a function that takes the provided IdeaFund UniSwap LP tokens and stakes it in the 
// protocol VAULT 

// Need a function that on a triggered basis will collect the LP emissions and transfer them into 
// the boardroom to collect CTRL tokens

pragma solidity >=0.6.0;

import '@openzeppelin/contracts/math/Math.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/SafeERC20.sol';
import '@openzeppelin/contracts/utils/ReentrancyGuard.sol';

import './interfaces/IUniswapV2Pair.sol';
import './interfaces/IUniswapV2Router02.sol';
import './interfaces/IOracle.sol';
import './interfaces/IBasisAsset.sol';
import './interfaces/ISimpleERCFund.sol';
import './interfaces/IHedgeFund.sol';

import './lib/UniswapV2Library.sol';
import './lib/Babylonian.sol';
import './lib/FixedPoint.sol';

import './utils/Operator.sol';
import './utils/Epoch.sol';
import './utils/ContractGuard.sol';

import 'hardhat/console.sol';

contract HedgeFund is Operator, ContractGuard {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public storedvalueToken; // wbtc
    address public peg; // lfbtc
    address public share; // lift
    address public control; // ctrl
    address public stakepegPool; // wBTC-lfBTC-Pair
    address public pegsharePool; // lfBTC-LIFT-Pair
    address public hedge; // Operator of the HAIF token
    address public theOracle;
    
    //validate this is 500
    uint public startingValue = 500e8;
    uint256 public starttime;
    uint256 public haifValue;

    mapping(address => uint256) private _haifBalances;

    //validate this is .25% (1.0025)
    uint public growthRate = uint(25).div(1000);

    bool migrated = false;
    bool _hasOracle = false;
    
    constructor(
        address _storedvalueToken,
        address _peg,
        address _share,
        address _control,
        address _hedge,
        uint256 _starttime
    ) public {
        storedvalueToken = _storedvalueToken;
        peg = _peg;
        share = _share;
        control = _control;
        hedge = _hedge;
        starttime = _starttime;
    }

    
    modifier hasOracle {
        require(_hasOracle, 'Set my oracle!');
        _;
    }

    modifier hasLPPoolValues {
        require(stakepegPool != address(0) && pegsharePool != address(0), 'Set the LP Pools');
        _;
    }

    function setLPPoolValues(address _stakepegPool, address _pegsharePool) external onlyOperator {
        stakepegPool = _stakepegPool;
        pegsharePool = _pegsharePool;   
    }

    // need to allow any address to deposit any token at any time.
    // need to track balances of deposits and reqeusts for withdraw
    // mint and burn haif based on withdraw / deposit requests
    // haif is a fixed $500 value on genesis day and increases in value .25% per day
    // when a deposit is made haif is returned based on VALUE divided by TOMORROWS VALUE

    // reinvestment into strategies will be always changing.  Good use of proxy?
    // some strategies will involve migrating funds to personal wallets for investment and return (lots of trust)

    function depositToHedgeFund(address tokentoDeposit, uint256 amount) external hasOracle hasLPPoolValues returns (uint256 returnHaifAmount) {
            //calculate value of token... 
            require(amount > 0, 'HedgeFund: cant take in 0 funds');
            require(tokentoDeposit == storedvalueToken ||
                    tokentoDeposit == peg ||
                    tokentoDeposit == share ||
                    tokentoDeposit == control ||
                    tokentoDeposit == stakepegPool ||
                    tokentoDeposit == pegsharePool, 
                    'HedgeFund: Send a token we can work with!');
            require(amount <= IERC20(tokentoDeposit).allowance(msg.sender, address(this)), 'HedgeFund: not approved to spend token');

            IOracle(theOracle).update();

            IERC20(tokentoDeposit).transferFrom(msg.sender, address(this), amount);
            uint256 mintedHedge = 0;

            if(tokentoDeposit == storedvalueToken ||
                tokentoDeposit == peg ||
                tokentoDeposit == share ||
                tokentoDeposit == control) {
                mintedHedge = amount.mul(IOracle(theOracle).priceOf(tokentoDeposit)).div(hedgePrice());
            } else if (tokentoDeposit == stakepegPool || tokentoDeposit == pegsharePool) {
                IUniswapV2Pair pair = IUniswapV2Pair(tokentoDeposit);
                uint112 token0Supply = 0;
                uint112 token1Supply = 0;

                (token0Supply, token1Supply, ) = pair.getReserves();

                // this should arrive at the value of the pairing...
                // when testing this in rinkeby we need to see if it discounts the lfBTC price to 0 and only returns tlv of wbtc
                uint256 tokenPrice = (uint256(token0Supply).mul(pair.price0CumulativeLast()) + uint256(token1Supply).mul(pair.price1CumulativeLast())).div(pair.totalSupply());

                mintedHedge = amount.mul(tokenPrice).div(hedgePrice());
            }
            
            _haifBalances[msg.sender] += mintedHedge;
            IBasisAsset(hedge).mint(address(this), mintedHedge);
            IERC20(hedge).transfer(msg.sender, mintedHedge);

//console.log("hedgefund:" ,mintedHedge);
            emit DepositIntoHedgeFund(msg.sender, amount);

            return uint256(mintedHedge);
    }

    // this will only return availble wBTC - and only to people with HAIF balances.
    function withdrawFromHedgeFund(uint256 amount) external hasOracle hasLPPoolValues returns (uint256 removedHaifAmount) {

            require(_haifBalances[msg.sender] >= amount, 'HedgeFund: You dont have this amount invested');
            require(IERC20(storedvalueToken).balanceOf(address(this)).mul(IOracle(theOracle).wbtcPriceOne()) >= amount.mul(hedgePrice()), 'HedgeFund: We dont have enough wbtc to pay you out currently please check back in 24 hours');
            require(amount <= IERC20(hedge).allowance(msg.sender, address(this)), 'HedgeFund: You must approve the haif amount before calling');

            _haifBalances[msg.sender] -= amount;
            IBasisAsset(hedge).burnFrom(msg.sender,amount);

            uint256 transferAmount = amount.mul(hedgePrice()).div(IOracle(theOracle).wbtcPriceOne());
            IERC20(storedvalueToken).transfer(msg.sender, transferAmount);
            
            emit WithDrawFromHedgeFund(msg.sender, amount);

            return amount;
    }

    function hedgePrice() public view hasOracle returns (uint256) {
            uint daysSinceStart = (block.timestamp - starttime) / 60 / 60 / 24;
            return startingValue.mul((1+growthRate)**daysSinceStart);
    }

    // YES this 100% can rug pull the IdeaFund just like every other stablization fund via with a Migrate Function
    function withdrawForInvestment(address tokenToWithDraw, address to, uint256 amount) public onlyOperator hasOracle
    {
        // allows the operator to pull funds and 
        // - invest them in assets 
        // - convert them to wbtc for withdrawl requests
        IERC20(tokenToWithDraw).transfer(to, amount);

        emit OperatorWithdrawForInvestment(to, amount);
    }

    function updateOracle(address newOracle) public onlyOperator {
        theOracle = newOracle;
        _hasOracle = true;
    }

    function migrate(address target) public onlyOperator {
        require(!migrated, 'HedgeFund: migrated');

        // HAIF
        Operator(hedge).transferOperator(target);
        Operator(hedge).transferOwnership(target);
        IERC20(hedge).transfer(target, IERC20(hedge).balanceOf(address(this)));

        migrated = true;
        emit Migration(target);
    }

    // THIS CONTRACT SHOULD EVOLVE OVER TIME TO NOT REQUIRE THE ABOVE.  
    // It must be able to be self managing / investing and growing without moving to a private wallet

    event DepositIntoHedgeFund(address sender, uint256 amount);
    event WithDrawFromHedgeFund(address sender, uint256 amount);
    event OperatorWithdrawForInvestment(address sender, uint256 amount);
    event Migration(address target);
}