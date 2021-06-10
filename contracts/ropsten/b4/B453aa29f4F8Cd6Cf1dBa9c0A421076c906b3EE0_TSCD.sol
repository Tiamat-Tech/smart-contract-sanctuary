// SPDX-License-Identifier: Unlicensed

// Imports
import "./SafeMath.sol";
import "./Address.sol";
import "./IBEP20.sol";
import "./Context.sol";
import "./IPancakeFactory.sol";
import "./IPancakeRouter01.sol";
import "./IPancakeRouter02.sol";
import "./SafeBEP20.sol";

import "./VRFConsumerBase.sol"; // VRF for randomness

// TODO - Socials and Things at the top


// TODO - events





pragma solidity ^0.8.4;

contract TSCD is Context, IBEP20, VRFConsumerBase  {

    address private ownerOfToken;
    address private previousOwnerOfToken;

    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;
    using Address for address;

    uint256 private totalSupplyOfToken;
    uint8 private totalDecimalsOfToken;
    string private tokenSymbol;
    string private tokenName;

    mapping(address => bool) private isAccountExcludedFromReward;
    address[] private excludedFromRewardAddresses;      // holds the address of the account that is excluded from reward

    mapping(address => bool) private isAccountExcludedFromFee;

    mapping(address => mapping(address => uint256)) private allowanceAmount;

    mapping(address => uint256) private reflectTokensOwned;
    mapping(address => uint256) private totalTokensOwned;


    // RFI Variables....
    uint256 private MAXintNum;
    uint256 private _rTotal;
    uint256 private totalFeeAmount;



    uint256 public taxFeePercent;
    uint256 private previousTaxFeePercent;

    uint256 public charityFeePercent;
    uint256 private previousCharityFeePercent;

    uint256 public burnFeePercent;
    uint256 private previousBurnFeePercent;

    uint256 public lotteryFeePercent;
    uint256 private previousLotteryFeePercent;

    uint256 public liquidityFeePercent;
    uint256 private previousLiquidityFeePercent;



    IPancakeRouter02 public pancakeswapRouter;
    address public pancakeswapPair;
    address public routerAddressForDEX;

    bool private inSwapAndLiquify;
    bool public swapAndLiquifyEnabled;

    // uint256 public maxTransferAmount;   

    uint256 public numTokensSellToAddToLiquidity;





    // Transfer Time Variables
    uint256 public maxTransferTime;
    mapping(address => uint256) public timeSinceLastTransferCurrent;
    mapping(address => uint256) public timeSinceLastTransferStart;
    mapping(address => uint256) public amountTransferedWithinOneDay;


    // Release Time Stamp
    uint256 releaseUnixTimeStampV1;


    // Addresses
    address public deadAddress;
    address public charityAddress;
    address public lotteryAddress;
    address public developmentAddress;
    address public teamAddress;

    address public drawingAddress;
    address public marketingAddress;


    address public deadAddressZero; 
    address public deadAddressOne; 



    // Lottery Tracking Vars
    mapping(address => bool) public isExcludedFromLottery;

    address[] public lottoPool;     // this pool will have multiple of the same addresses if they have enough entires
    address[] public lottoPoolTemp;     // this array is for temporarily storing the new lottoarray


    mapping(address => bool) public hasEnoughTokensForLottery;
    mapping(address => uint256) public numberOfEntriesIntoLottery;


    // mapping(address => uint256) public amountBalanceTracking;
    // mapping(address => uint256) public amountOverForLottoEntry;

    uint256 public lotteryTime;
    address public currentLotteryWinner;

    uint256 public maxDrawingChances;
    uint256 public amountNeededForDrawingChance;

    uint256 public amountToDisperseInDrawingTotal;
    uint256 public amountToDisperseInDrawingPerPeriod;
    uint256 public amountToDisperseInDrawingLeft;

    uint256 public periodsToDisperse;
    uint256 public hoursInPeriodToDisperse;
    uint256 public dispersalTime;

    bool public isLotterySystemEnabled;


    // Chainlink VRF
    bytes32 private keyHashForLINK;
    uint256 private feeForLINK;
    uint256 public randomResultFromLINKVRF;

    // CHANGEIT - change for live
    // address public linkTokenAddress = 0x404460C6A5EdE2D891e8297795264fDe62ADBB75;
    // address public vrfCoordinatorAddress = 0x747973a5A2a4Ae1D3a8fDF5479f1514F65Db9C31;

    // CHANGEIT - this is for BSC Test NETWORK
    address public linkTokenAddress = 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06;
    address public vrfCoordinatorAddress = 0xa555fC018435bef5A13C6c6870a9d4C11DEC329C;





    

    






    // Events
    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiqudity);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);


    event DEBUGuint1(uint256 param1);
    event DEBUGuint2(uint256 param1);
    event DEBUGuint3(uint256 param1);
    event DEBUGuint4(uint256 param1);
    event DEBUGuint5(uint256 param1);

    event DEBUGaddress1(address param1);
    event DEBUGaddress2(address param1);

    event DEBUGbool1(bool param1);
    event DEBUGbool2(bool param1);

    constructor () VRFConsumerBase(vrfCoordinatorAddress, linkTokenAddress){

        // Fee Addresses
        deadAddress = 0x000000000000000000000000000000000000dEaD;
        charityAddress = 0xf83F607DEE4B83f4eae8ACFAEe611cb199D1bBFD;
        lotteryAddress = 0xd200823A20398B58Af2D0Eda6F61b10AC81A1728;

        teamAddress = 0x607C9C13ef8Eb886328B40b2DE41A8C255d84f77;
        developmentAddress = 0xe2176A2649376493b774411B611420Ed03d989E7;
        drawingAddress = 0x1eE54a458290b903B50A5c69Fe11ac4C681D8196;
        marketingAddress = 0x6f00F0Df507d91993Db7fD40c173f6adC4dBb88a;



        deadAddressZero = 0x0000000000000000000000000000000000000000; 
        deadAddressOne = 0x0000000000000000000000000000000000000001; 



        amountToDisperseInDrawingTotal = 0;
        amountToDisperseInDrawingPerPeriod = 0;
        amountToDisperseInDrawingLeft = 0;


        // periodsToDisperse = 7; // CHANGEIT - must change to 7 here
        periodsToDisperse = 2;

        // hoursInPeriodToDisperse = 24 hours;  // CHANGEIT - must change to 24 hours here
        hoursInPeriodToDisperse = 1 minutes;



        maxDrawingChances = 25;
        amountNeededForDrawingChance = 100 * 10**9 * 10**9;
        lotteryTime = block.timestamp.add(periodsToDisperse.mul(hoursInPeriodToDisperse));
        dispersalTime = 0;
        currentLotteryWinner = 0x000000000000000000000000000000000000dEaD;



        


        address msgSender = _msgSender();   

        ownerOfToken = msgSender;
        emit OwnershipTransferred(address(0), msgSender);

        totalSupplyOfToken = 100 * 10**15 * 10**9;
        totalDecimalsOfToken = 9;

        MAXintNum = ~uint256(0);
        _rTotal = (MAXintNum - (MAXintNum % totalSupplyOfToken));       // might stand for reflection totals, meaning the total number of possible reflections?
        
        tokenSymbol = "TSCD";  
        tokenName = "Top Secret Coin D";   
        
        
        // YOU MUST CHANGE 
        // taxFeePercent = 3;
        taxFeePercent = 0;
        previousTaxFeePercent = taxFeePercent;
        // charityFeePercent = 3; 
        charityFeePercent = 0; 
        previousCharityFeePercent = charityFeePercent;
        // burnFeePercent = 2; 
        burnFeePercent = 0; 
        previousBurnFeePercent = burnFeePercent;
        // lotteryFeePercent = 5; 
        lotteryFeePercent = 0; 
        previousLotteryFeePercent = lotteryFeePercent;
        // liquidityFeePercent = 2;
        liquidityFeePercent = 0;
        previousLiquidityFeePercent = liquidityFeePercent;

    
        // maxTransferAmount = 100 * 10**15 * 10**9;   
        // maxTransferTime = 86400;        // sets max transfer time to 1 day, essentially you can't transfer more than the max transfer amount in more than one day (86400)

        swapAndLiquifyEnabled = false;       // set to false at first while handles the presale and the airdrop
        numTokensSellToAddToLiquidity = 100 * 10**11 * 10**9;  


        // TODO - get more of the wallets their totals.
        reflectTokensOwned[msgSender] = _rTotal;      // sets the funds to the Gnosis Safe



        // V2 Router - 0x10ED43C718714eb63d5aA57B78B54704E256024E   // CHANGEIT - this is the one you want for live

        // 0x10ED43C718714eb63d5aA57B78B54704E256024E = LIVE PancakeSwap ROUTER V2
        // 0x73feaa1eE314F8c655E354234017bE2193C9E24E = LIVE PancakeSwap Staking Contract
        // 0xA527a61703D82139F8a06Bc30097cC9CAA2df5A6 = LIVE PancakeSwap CAKE
        // 0x1B96B92314C44b159149f7E0303511fB2Fc4774f = LIVE PancakeSwap BUSD
        // 0xfa249Caa1D16f75fa159F7DFBAc0cC5EaB48CeFf = LIVE PancakeSwap FACTORY (Bunny Factory?) 

        // 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D = TESTNET/LIVE Uniswap Ropsten and Rinkeby ROUTER
        // 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f = TESTNET/LIVE Uniswap FACTORY
        // uniswap v3 factory 0x1F98431c8aD98523631AE4a59f267346ea31F984

        // 0x6725F303b657a9451d8BA641348b6761A6CC7a17 = TESTNET PancakeSwap FACTORY
        // 0xD99D1c33F9fC3444f8101754aBC46c52416550D1 = TESTNET PancakeSwap ROUTER


        // Address for Testing with https://pancake.kiemtienonline360.com/#/swap
        // 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3
        // You will need to update the pair address if you do this
        

        // routerAddressForDEX = 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3;       // CHANGEIT - change this to real pancakeswap router
        routerAddressForDEX = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;       // CHANGEIT - change this to real pancakeswap router



        IPancakeRouter02 pancakeswapRouterLocal = IPancakeRouter02(routerAddressForDEX);      // gets the router
        pancakeswapPair = IPancakeFactory(pancakeswapRouterLocal.factory()).createPair(address(this), pancakeswapRouterLocal.WETH());     // Creates the pancakeswap pair   
        pancakeswapRouter = pancakeswapRouterLocal;   // set the rest of the contract variables in the global router variable from the local one

        isAccountExcludedFromFee[owner()] = true;  // exclude owner from Fee
        isAccountExcludedFromFee[address(this)] = true;  // exclude contract from Fee

        //emit Transfer(address(0), _msgSender(), totalSupplyOfToken);    // emits event of the transfer of the supply from dead to owner
        emit Transfer(address(0), payableTeamWalletAddr(), totalSupplyOfToken);    // emits event of the transfer of the supply from dead to owner

        releaseUnixTimeStampV1 = block.timestamp;     // gets the block timestamp so we can know when it was deployed





        // Excluding basic addresses from lottery
        isExcludedFromLottery[deadAddress] = true;
        isExcludedFromLottery[deadAddressZero] = true;
        isExcludedFromLottery[deadAddressOne] = true;
        isExcludedFromLottery[marketingAddress] = true;
        isExcludedFromLottery[drawingAddress] = true;
        isExcludedFromLottery[developmentAddress] = true;
        isExcludedFromLottery[teamAddress] = true;
        isExcludedFromLottery[lotteryAddress] = true;
        isExcludedFromLottery[charityAddress] = true;
        isExcludedFromLottery[routerAddressForDEX] = true;
        isExcludedFromLottery[pancakeswapPair] = true;
        isExcludedFromLottery[address(this)] = true;


        // isLotterySystemEnabled = true;     // You must change it to true after dxsale
        isLotterySystemEnabled = false;    

        // chainlink vrf  
        // CHANGEIT - change for live net here
        // keyHashForLINK = 0xc251acd21ec4fb7f31bb8868288bfdbaeb4fbfec2df3735ddbd4f7dc8d60103c;
        // feeForLINK = 0.2 * 10 ** 18; // 0.2 LINK (Varies by network)


        // CHANGEIT - this is for BSC Test Network
        keyHashForLINK = 0xcaf3c3727e033261d383b315559476f48034c13b18f8cafed4d871abe5049186;
        feeForLINK = 0.1 * 10 ** 18; // 0.2 LINK (Varies by network)






    }


    function owner() public view returns (address) {
        return ownerOfToken;        // Returns the address of the current owner.
    }

    function getOwner() external view override returns (address){
        return owner();     // gets current owner address
    }

    modifier onlyOwner() {
        require(ownerOfToken == _msgSender(), "Ownable: caller is not the owner");  // Throws if called by any account other than the owner.
        _;      // when using a modifier, the code from the function is inserted here. // if multiple modifiers then the previous one inherits the next one's modifier code
    }

    function transferOwnership(address newOwner) public onlyOwner() {     // changes ownership
        require(newOwner != address(0), "Ownable: new owner is the zero address");   
        emit OwnershipTransferred(ownerOfToken, newOwner);
        previousOwnerOfToken = ownerOfToken;
        ownerOfToken = newOwner;
    }

    


    function decimals() public view override returns (uint8) {
        return totalDecimalsOfToken;    // gets total decimals  
    }


    function symbol() public view override returns (string memory) {
        return tokenSymbol;     // gets token symbol
    }


    function name() public view override returns (string memory) {
        return tokenName;       // gets token name
    }


    function totalSupply() external view override returns (uint256){
        return totalSupplyOfToken;      // gets total supply
    }


    function balanceOf(address account) public view override returns (uint256) {
        if (isAccountExcludedFromReward[account]) {     // I have no idea what this does exactly
            return totalTokensOwned[account];
        }
        return tokenFromReflection(reflectTokensOwned[account]);
    }

    
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        transferInternal(_msgSender(), recipient, amount, false); // transfers with fees applied
        return true;
    }


    function allowance(address ownerAddr, address spender) external view override returns (uint256) { 
        return allowanceAmount[ownerAddr][spender];    // Returns remaining tokens that spender is allowed during {approve} or {transferFrom} 
    }


    function approveInternal(address ownerAddr, address spender, uint256 amount) private { 
        // This is internal function is equivalent to `approve`, and can be used to e.g. set automatic allowances for certain subsystems, etc.
        require(ownerAddr != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");
        allowanceAmount[ownerAddr][spender] = amount;       // approves the amount to spend by the ownerAddr
        emit Approval(ownerAddr, spender, amount);
    }


    function approve(address spender, uint256 amount) public override returns (bool){
        approveInternal(_msgSender(), spender, amount);     
        return true;
    }


    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        transferInternal(sender, recipient, amount, false); 
        approveInternal(sender, _msgSender(), allowanceAmount[sender][_msgSender()].sub(amount, "BEP20: transfer amount exceeds allowance"));
        return true;
    }


    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool){
        approveInternal(_msgSender(), spender, allowanceAmount[_msgSender()][spender].add(addedValue));
        return true;
    }


    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool){
        approveInternal(_msgSender(),spender,allowanceAmount[_msgSender()][spender].sub(subtractedValue,"BEP20: decreased allowance below zero"));
        return true;
    }


    function totalFees() public view returns (uint256) {
        return totalFeeAmount;
    }


    
    function deliverReflectTokens(uint256 tAmount) public {     // this is just a burn for Reflect Tokens
        address sender = _msgSender();           
        require(!isAccountExcludedFromReward[sender],"Excluded addresses cannot call this function");
        (uint256 rAmount, , , ) = getTaxAndReflectionValues(tAmount);
        reflectTokensOwned[sender] = reflectTokensOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        totalFeeAmount = totalFeeAmount.add(tAmount);     
    }


    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns (uint256) {
        require(tAmount <= totalSupplyOfToken, "Amount must be less than supply");         
        (uint256 rAmount, uint256 rTransferAmount, , ) = getTaxAndReflectionValues(tAmount);
        if(deductTransferFee){
            return rTransferAmount;     // if we are deducting the transfer fee, then use this amount, otherwise return the regular Amount
        }
        else{
            return rAmount;
        }
    }

    
    function tokenFromReflection(uint256 rAmount) public view returns (uint256){  
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate = getReflectRate();
        return rAmount.div(currentRate);        // gets the amount of the reflection
    }


    function isExcludedFromReward(address account) public view returns (bool) {
        return isAccountExcludedFromReward[account];
    }


    function excludeFromReward(address account) public onlyOwner() {
        // if there is ever cross change compatability, then in the future you will need to include Uniswap Addresses, but for now Pancake Swap works, just one router address works
        require(account != routerAddressForDEX, "Account must not be PancakeSwap Router");    // don't ever exclude the Uniswap or Pancake Swap router
        require(!isAccountExcludedFromReward[account], "Account is already excluded");
        if (reflectTokensOwned[account] > 0) {
            totalTokensOwned[account] = tokenFromReflection(reflectTokensOwned[account]);   // gets the reflect tokens and gives them to the address before excluding it
        }
        isAccountExcludedFromReward[account] = true;
        excludedFromRewardAddresses.push(account);
    }


    // this is basically the internal version of the exclude in reward function
    function excludeBurnAddrFromReward(address account) private {
        if(!isAccountExcludedFromReward[account]){      // if the account is not yet excluded let's exclude
            if (reflectTokensOwned[account] > 0) {
                totalTokensOwned[account] = tokenFromReflection(reflectTokensOwned[account]);   // gets the reflect tokens and gives them to the address before excluding it
            }
            isAccountExcludedFromReward[account] = true;
            excludedFromRewardAddresses.push(account);
        }
    }


    function includeInReward(address account) external onlyOwner() {
        require(isAccountExcludedFromReward[account], "Account is already included");
        for (uint256 i = 0; i < excludedFromRewardAddresses.length; i++) {
            if (excludedFromRewardAddresses[i] == account) {
                excludedFromRewardAddresses[i] = excludedFromRewardAddresses[excludedFromRewardAddresses.length - 1];   // finds and removes the address from the excluded addresses
                totalTokensOwned[account] = 0;  // sets the reward tokens to 0
                isAccountExcludedFromReward[account] = false;
                excludedFromRewardAddresses.pop();
                break;
            }
        }
    }


    // this is basically the internal version of the include in reward function
    function includeBurnAddrInReward(address account) private {
        if(isAccountExcludedFromReward[account]){       // check to see if it's actually excluded
            for(uint256 i = 0; i < excludedFromRewardAddresses.length; i++) {
                if(excludedFromRewardAddresses[i] == account) {
                    excludedFromRewardAddresses[i] = excludedFromRewardAddresses[excludedFromRewardAddresses.length - 1];   // finds and removes the address from the excluded addresses
                    totalTokensOwned[account] = 0;  
                    isAccountExcludedFromReward[account] = false;
                    excludedFromRewardAddresses.pop();
                    break;
                }
            }
        }
    }

    
    function excludeFromFee(address account) public onlyOwner() {
        isAccountExcludedFromFee[account] = true;
    }


    function includeInFee(address account) public onlyOwner() {
        isAccountExcludedFromFee[account] = false;
    }


    function isExcludedFromFee(address account) public view returns (bool) {
        return isAccountExcludedFromFee[account];
    }


    function setTaxFeePercent(uint256 newTaxFeePercent) external onlyOwner() {
        taxFeePercent = newTaxFeePercent;
    }

    function setCharityFeePercent(uint256 newCharityFee) external onlyOwner() {
        charityFeePercent = newCharityFee;
    }

    function setBurnFeePercent(uint256 newBurnFee) external onlyOwner() {
        burnFeePercent = newBurnFee;
    }

    function setLotteryFeePercent(uint256 newLotteryFee) external onlyOwner() {
        lotteryFeePercent = newLotteryFee;
    }

    function setLiquidityFeePercent(uint256 newLiquidityFeePercent) external onlyOwner() {
        liquidityFeePercent = newLiquidityFeePercent;
    }



    // function setMaxTransferPercent(uint256 maxTransferPercent) external onlyOwner() {
    //     maxTransferAmount = totalSupplyOfToken.mul(maxTransferPercent).div(10**2);  // the math is ((Total Supply * %) / 100)
    // }



    function setMaxTransferTimeInUnixTime(uint256 maxTransferTimeToSet) external onlyOwner() {
        maxTransferTime = maxTransferTimeToSet;     // you can set the max transfer time this way, must be in UNIX time.
    }


    function setSwapAndLiquifyEnabled(bool enableSwapAndLiquify) external onlyOwner() {     
        swapAndLiquifyEnabled = enableSwapAndLiquify;   // allows owner to turn off the liquification fee
        emit SwapAndLiquifyEnabledUpdated(enableSwapAndLiquify);
    }



    function takeReflectFee(uint256 reflectFee, uint256 taxFee) private {
        _rTotal = _rTotal.sub(reflectFee);      // subtracts the fee from the reflect totals
        totalFeeAmount = totalFeeAmount.add(taxFee);    // adds to the toal fee amount
    }



    function getReflectRate() private view returns (uint256) {
        (uint256 reflectSupply, uint256 tokenSupply) = getCurrentSupplyTotals();       // gets the current reflect supply, and the total token supply.
        return reflectSupply.div(tokenSupply);        // to get the rate, we will divide the reflect supply by the total token supply.
    }



    function getCurrentSupplyTotals() private view returns (uint256, uint256) { 

        uint256 rSupply = _rTotal;      // total reflections
        uint256 tSupply = totalSupplyOfToken;       // total supply

        for (uint256 i = 0; i < excludedFromRewardAddresses.length; i++) {
            if ((reflectTokensOwned[excludedFromRewardAddresses[i]] > rSupply) || (totalTokensOwned[excludedFromRewardAddresses[i]] > tSupply)){
                return (_rTotal, totalSupplyOfToken);       // if any address that is excluded has a greater reflection supply or great than the total supply then we just return that
            } 
            rSupply = rSupply.sub(reflectTokensOwned[excludedFromRewardAddresses[i]]);  // calculates the reflection supply by subtracting the reflect tokens owned from every address
            tSupply = tSupply.sub(totalTokensOwned[excludedFromRewardAddresses[i]]);    // calculates the total token supply by subtracting the total tokens owned from every address
            // I think this will eventually leave the supplies with what's left in the PancakeSwap router
        }

        if (rSupply < _rTotal.div(totalSupplyOfToken)){     // checks to see if the reflection total rate is greater than the reflection supply after subtractions
            return (_rTotal, totalSupplyOfToken);
        } 

        return (rSupply, tSupply);
    }


    function takeLiquidityFee(uint256 tLiquidity) private {
        uint256 currentRate = getReflectRate();
        uint256 rLiquidity = tLiquidity.mul(currentRate);
        reflectTokensOwned[address(this)] = reflectTokensOwned[address(this)].add(rLiquidity);  // if included gives the reward to their reflect tokens owned part
        if (isAccountExcludedFromReward[address(this)]){
            totalTokensOwned[address(this)] = totalTokensOwned[address(this)].add(tLiquidity);  // if excluded from reward gives it to their tokens, 
        }
    }


    function takeCharityFee(uint256 taxCharityFee) private {
        uint256 currentRate = getReflectRate();
        uint256 rCharityTaxFee = taxCharityFee.mul(currentRate);
        reflectTokensOwned[charityAddress] = reflectTokensOwned[charityAddress].add(rCharityTaxFee); 
        if (isAccountExcludedFromReward[charityAddress]){
            totalTokensOwned[charityAddress] = totalTokensOwned[charityAddress].add(taxCharityFee);
        }
    }

    function takeBurnFee(uint256 taxBurnFee) private {
        uint256 currentRate = getReflectRate();
        uint256 rBurnTaxFee = taxBurnFee.mul(currentRate);
        reflectTokensOwned[deadAddress] = reflectTokensOwned[deadAddress].add(rBurnTaxFee); 
        if (isAccountExcludedFromReward[deadAddress]){
            totalTokensOwned[deadAddress] = totalTokensOwned[deadAddress].add(taxBurnFee);
        }
    }

    function takeLotteryFee(uint256 taxLotteryFee) private {
        uint256 currentRate = getReflectRate();
        uint256 rLotteryTaxFee = taxLotteryFee.mul(currentRate);
        reflectTokensOwned[lotteryAddress] = reflectTokensOwned[lotteryAddress].add(rLotteryTaxFee); 
        if (isAccountExcludedFromReward[lotteryAddress]){
            totalTokensOwned[lotteryAddress] = totalTokensOwned[lotteryAddress].add(taxLotteryFee);
        }
    }


    
    function transferInternal(address senderAddr, address receiverAddr, uint256 amount, bool ignoreMaxTxAmt) private {   
        // internal function is equivalent to {transfer}, and can be used to e.g. implement automatic token fees, slashing mechanisms, etc.

        require(senderAddr != address(0), "BEP20: transfer from the zero address");
        require(receiverAddr != address(0), "BEP20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");



        if(!ignoreMaxTxAmt){
            // require(amount <= maxTransferAmount, "Transfer amount exceeds the maxTxAmount."); 
            timeSinceLastTransferCurrent[senderAddr] = getNowBlockTime().sub(timeSinceLastTransferStart[senderAddr]); 
            if(timeSinceLastTransferCurrent[senderAddr] > maxTransferTime){        // check to see if it's over the max transfer time yet
                timeSinceLastTransferStart[senderAddr] = getNowBlockTime();     // sets the last transfer time to now
                amountTransferedWithinOneDay[senderAddr] = 0;

                // this is for the Max Transfer Functionality
                // amountTransferedWithinOneDay[sender] += taxTransferAmount; // find this part over in  transferTokens after the transfer occurs
            }

            // uint256 potentialTransferAmtPlusPrevTransferAmts = amountTransferedWithinOneDay[senderAddr].add(amount);
            // require(potentialTransferAmtPlusPrevTransferAmts <= maxTransferAmount, "Transfer amount exceeds the 24h Max Transfer Amount"); 
        }
        
 
        // is the token balance of this contract address over the min number of tokens that we need to initiate a swap + liquidity lock?
        // don't get caught in the a circular liquidity event, don't swap and liquify if sender is the uniswap pair.
        uint256 contractStoredFeeTokenBalance = balanceOf(address(this));

        // if (contractStoredFeeTokenBalance >= maxTransferAmount) {
        //     // why would we do this? we should store all the amounts at once, not just the max. doesn't make a lot of sense
        //     contractStoredFeeTokenBalance = maxTransferAmount;        // sets the storedFeeTokenBalance to the MaxtxAmount, this will leave some of the tokens in the pool behind maybe?
        // }

        bool overMinContractStoredFeeTokenBalance = false; 
        if(contractStoredFeeTokenBalance >= numTokensSellToAddToLiquidity){  // check to see if there are enough tokens stored from fees in the Contract to justify the Swap
            overMinContractStoredFeeTokenBalance = true;                        // if we did not have a minimum, the gas would eat into the profits generated from the fees.
        }

        if (overMinContractStoredFeeTokenBalance && !inSwapAndLiquify && senderAddr != pancakeswapPair && swapAndLiquifyEnabled) {
            contractStoredFeeTokenBalance = numTokensSellToAddToLiquidity;     // the reason this is set to that, is to make sure we get the exact amount we are wanting to swap and liquify   
            swapAndLiquify(contractStoredFeeTokenBalance);   //add liquidity
        }

        bool takeFee = true;    // should fee be taken?
        if (isAccountExcludedFromFee[senderAddr] || isAccountExcludedFromFee[receiverAddr]) {   // if either address is excluded from fee, then set takeFee to false.
            takeFee = false;    
        }

        //transfer amount, it will take tax, burn, liquidity fee
        transferTokens(senderAddr, receiverAddr, amount, takeFee);  // transfer the tokens, take the fee, burn, and liquidity fee
    }



    function swapAndLiquify(uint256 contractStoredFeeTokenBalance) private {        // this sells half the tokens when over a certain amount.
        inSwapAndLiquify = true;
        // gets two halves to be used in liquification
        uint256 half1 = contractStoredFeeTokenBalance.div(2);
        uint256 half2 = contractStoredFeeTokenBalance.sub(half1);
        uint256 initialBalance = address(this).balance;     
        // gets initial balance, get exact amount of BNB that swap creates, and make sure the liquidity event doesn't include BNB manually sent to the contract.
        swapTokensForEth(half1); // swaps tokens into BNB to add back into liquidity. Uses half 1
        uint256 newBalance = address(this).balance.sub(initialBalance);     // new Balance calculated after that swap
        addLiquidity(half2, newBalance);     // Adds liquidity to PancakeSwap using Half 2
        emit SwapAndLiquify(half1, newBalance, half2);
        inSwapAndLiquify = false;
    }



    function swapTokensForEth(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);       // Contract Token Address
        path[1] = pancakeswapRouter.WETH();     // Router Address
        approveInternal(address(this), address(pancakeswapRouter), tokenAmount);        // Why two approvals? Have to approve both halfs
        pancakeswapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(tokenAmount, 0, path, address(this), block.timestamp);     // make the swap
    }



    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        approveInternal(address(this), address(pancakeswapRouter), tokenAmount);        // Why two approvals? Have to approve both halfs
        pancakeswapRouter.addLiquidityETH{value: ethAmount}(address(this),tokenAmount, 0, 0, address(this), block.timestamp);     // adds the liquidity
        // perhaps in the future I might want to change the minimum amounts that are swapped - the 0, 0, parameters
    }



    
    function changeNumberOfTokensToSwapAndLiquify(uint256 newTokenAmount) external onlyOwner() {      // addition, in version 1 of NIP, this will allow you to set the numTokensSellToAddToLiquidity later on if you need to.
        numTokensSellToAddToLiquidity = newTokenAmount;
    }



    function removeAllFee() private {
        previousTaxFeePercent = taxFeePercent;
        previousCharityFeePercent = charityFeePercent;
        previousBurnFeePercent = burnFeePercent;
        previousLotteryFeePercent = lotteryFeePercent;
        previousLiquidityFeePercent = liquidityFeePercent;

        taxFeePercent = 0;
        charityFeePercent = 0;
        burnFeePercent = 0;
        lotteryFeePercent = 0;
        liquidityFeePercent = 0;
    }

    function restoreAllFee() private {
        taxFeePercent = previousTaxFeePercent;
        charityFeePercent = previousCharityFeePercent;
        burnFeePercent = previousBurnFeePercent;
        lotteryFeePercent = previousLotteryFeePercent;
        liquidityFeePercent = previousLiquidityFeePercent;
    }

    
    // function getTaxValues(uint256 transferAmount) private view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
    function getTaxValues(uint256 transferAmount) private view returns (uint256[6] memory) {


        uint256[6] memory taxLiqCharityBurnLotteryFeeArray;
        taxLiqCharityBurnLotteryFeeArray[0] = transferAmount.mul(taxFeePercent).div(10**2);    // calculate Tax Fee
        taxLiqCharityBurnLotteryFeeArray[1] = transferAmount.mul(liquidityFeePercent).div(10**2);   // calculate Liquidity Fee
        taxLiqCharityBurnLotteryFeeArray[2] = transferAmount.mul(charityFeePercent).div(10**2);   // calculate Charity Fee
        taxLiqCharityBurnLotteryFeeArray[3] = transferAmount.mul(burnFeePercent).div(10**2);   // calculate Burn Fee
        taxLiqCharityBurnLotteryFeeArray[4] = transferAmount.mul(lotteryFeePercent).div(10**2);   // calculate Lottery Fee
        taxLiqCharityBurnLotteryFeeArray[5] = transferAmount.sub(taxLiqCharityBurnLotteryFeeArray[0]).sub(taxLiqCharityBurnLotteryFeeArray[1])
            .sub(taxLiqCharityBurnLotteryFeeArray[2]).sub(taxLiqCharityBurnLotteryFeeArray[3]).sub(taxLiqCharityBurnLotteryFeeArray[4]);

        return (taxLiqCharityBurnLotteryFeeArray);

        // uint256 taxFee = transferAmount.mul(taxFeePercent).div(10**2);    // calculate Tax Fee
        // uint256 taxLiquidity = transferAmount.mul(liquidityFeePercent).div(10**2);   // calculate Liquidity Fee
        // uint256 taxCharityFee = transferAmount.mul(charityFeePercent).div(10**2);   // calculate Charity Fee
        // uint256 taxBurnFee = transferAmount.mul(burnFeePercent).div(10**2);   // calculate Burn Fee
        // uint256 taxLotteryFee = transferAmount.mul(lotteryFeePercent).div(10**2);   // calculate Lottery Fee

        // uint256 taxTransferAmount = transferAmount.sub(taxFee).sub(taxLiquidity).sub(taxCharityFee).sub(taxBurnFee).sub(taxLotteryFee);
        // return (taxTransferAmount, taxFee, taxLiquidity, taxCharityFee, taxBurnFee, taxLotteryFee);
    }

    
    function getReflectionValues(uint256 transferAmount, uint256 taxFee, uint256 taxLiquidity, uint256 taxCharityFee, uint256 taxBurnFee, uint256 taxLotteryFee, uint256 currentRate) 
    private pure returns (uint256, uint256, uint256){
        uint256 reflectionAmount = transferAmount.mul(currentRate);
        uint256 reflectionFee = taxFee.mul(currentRate);
        uint256 reflectionLiquidity = taxLiquidity.mul(currentRate);
        uint256 reflectionFeeCharity = taxCharityFee.mul(currentRate);
        uint256 reflectionFeeBurn = taxBurnFee.mul(currentRate);
        uint256 reflectionFeeLottery = taxLotteryFee.mul(currentRate);
        uint256 reflectionTransferAmount = reflectionAmount.sub(reflectionFee).sub(reflectionLiquidity);
        reflectionTransferAmount = reflectionTransferAmount.sub(reflectionFeeCharity).sub(reflectionFeeBurn).sub(reflectionFeeLottery);
        return (reflectionAmount, reflectionTransferAmount, reflectionFee);
    }

    function getTaxAndReflectionValues(uint256 tAmount) private view returns (uint256,uint256,uint256, uint256[6] memory) {

        (uint256[6] memory taxLiqCharityBurnLotteryFeeArray) = getTaxValues(tAmount);
        (uint256 reflectAmount, uint256 reflectTransferAmount, uint256 reflectFee) = 
            getReflectionValues(tAmount, taxLiqCharityBurnLotteryFeeArray[0], taxLiqCharityBurnLotteryFeeArray[1], 
                taxLiqCharityBurnLotteryFeeArray[2], taxLiqCharityBurnLotteryFeeArray[3], taxLiqCharityBurnLotteryFeeArray[4], getReflectRate());
        return (reflectAmount, reflectTransferAmount, reflectFee, taxLiqCharityBurnLotteryFeeArray);




        // (uint256 taxTransferAmount, uint256 taxFee, uint256 taxLiquidity, uint256 taxCharityFee, uint256 taxBurnFee, uint256 taxLotteryFee) = getTaxValues(tAmount);
        // (uint256 reflectAmount, uint256 reflectTransferAmount, uint256 reflectFee) = getReflectionValues(tAmount, taxFee, taxLiquidity, taxCharityFee, taxBurnFee, taxLotteryFee, getReflectRate());
        // return (reflectAmount, reflectTransferAmount, reflectFee, taxTransferAmount, taxFee, taxLiquidity, taxCharityFee, taxBurnFee, taxLotteryFee);
    }

    


    function transferTokens(address sender, address recipient, uint256 transferAmount, bool takeFee) private {
        if (!takeFee) {
            removeAllFee();
        }


        (uint256 reflectAmount, uint256 reflectTransferAmount,uint256 reflectFee, uint256[6] memory taxLiqCharityBurnLotteryFeeArray) = getTaxAndReflectionValues(transferAmount);

        
        // (uint256 reflectAmount, uint256 reflectTransferAmount,uint256 reflectFee,uint256 taxTransferAmount,uint256 taxFee,uint256 taxLiquidity, uint256 taxCharityFee, uint256 taxBurnFee, uint256 taxLotteryFee) = getTaxAndReflectionValues(transferAmount);

        if(isAccountExcludedFromReward[sender]){    // is the sender address excluded from Reward?
            totalTokensOwned[sender] = totalTokensOwned[sender].sub(transferAmount);
        }

        reflectTokensOwned[sender] = reflectTokensOwned[sender].sub(reflectAmount);

        if(isAccountExcludedFromReward[recipient]){    // is the sender address excluded from Reward?
            totalTokensOwned[recipient] = totalTokensOwned[recipient].add(taxLiqCharityBurnLotteryFeeArray[5]);
        }

        reflectTokensOwned[recipient] = reflectTokensOwned[recipient].add(reflectTransferAmount);

        takeLiquidityFee(taxLiqCharityBurnLotteryFeeArray[1]);   

        takeCharityFee(taxLiqCharityBurnLotteryFeeArray[2]);      
        takeBurnFee(taxLiqCharityBurnLotteryFeeArray[3]);      
        takeLotteryFee(taxLiqCharityBurnLotteryFeeArray[4]);      

        takeReflectFee(reflectFee, taxLiqCharityBurnLotteryFeeArray[0]);

        amountTransferedWithinOneDay[sender] += transferAmount;

        emit Transfer(sender, recipient, taxLiqCharityBurnLotteryFeeArray[5]);

        if (!takeFee){
            restoreAllFee();
        } 




        if(isLotterySystemEnabled){ // Lotto functions
            
            checkForLotteryParticipationOrRemoval(recipient);
            checkForLotteryParticipationOrRemoval(sender);

            weeklyLottery();

            lotteryDisperseFromDrawingWallet();
        }
    }












    function getNowBlockTime() public view returns (uint) {
        return block.timestamp;     // gets the current time and date in Unix timestamp
    }









    ///////////////// withdraw from contract functions
    function payableTeamWalletAddr() private view returns (address payable) {   // gets the sender of the payable address
        address payable payableMsgSender = payable(address(teamAddress));      
        return payableMsgSender;
    }

    function withdrawBNBSentToContractAddress() external onlyOwner()  {   
        payableTeamWalletAddr().transfer(address(this).balance);
    }

    
    function withdrawBEP20SentToContractAddress(IBEP20 tokenToWithdraw) external onlyOwner() {
        tokenToWithdraw.safeTransfer(payableTeamWalletAddr(), tokenToWithdraw.balanceOf(address(this)));
    }



    function releaseUnixTimeDate() public view returns (uint256) {
        return releaseUnixTimeStampV1;
    }





    function setRouterAddress(address newRouter) external onlyOwner() {
        routerAddressForDEX = newRouter;
        IPancakeRouter02 pancakeswapRouterLocal = IPancakeRouter02(routerAddressForDEX);      // gets the router
        pancakeswapPair = IPancakeFactory(pancakeswapRouterLocal.factory()).createPair(address(this), pancakeswapRouterLocal.WETH());     // Creates the pancakeswap pair   
        pancakeswapRouter = pancakeswapRouterLocal;   // set the rest of the contract variables in the global router variable from the local one
    }

    function setPairAddress(address newPairAddress) public onlyOwner() {
        pancakeswapPair = newPairAddress;
    }




    // Setters for Chainlink VRF
    function setKeyHashForLinkVRF(bytes32 newKeyHash) public onlyOwner() {
        keyHashForLINK = newKeyHash;
    }

    function setFeeForLinkVRF(uint256 newFee) public onlyOwner() {
        feeForLINK = newFee;
    }


    ///////////////////// LOTTERY FUNCTIONS /////////////////////////////

    // TODO - possibly have it where, one big array holds all the holders past and present
    // then as we pick the lotto winner, make a new temp array that only has the people who have the right amount.
    // pick the winner, then delete the temporary array.
    // problem is you would have to go through a giant one.

    function weeklyLottery() private {     // gets called at the end of every transfer

        // multiplies periods by hours, at the start its 7 periods x 24 hours ( 7days)
        // make sure the lotto pool exists, has at least 1 entrant
        if(block.timestamp >= lotteryTime && lottoPool.length > 0){      

            // check to make sure the link balance is greater than or equal to the balance in the address
            // make sure we are done dispersing before going to the next winner, this might cause some delay
            if(amountToDisperseInDrawingLeft == 0 && LINK.balanceOf(address(this)) >= feeForLINK){ 

                uint256 currentLotteryWalletBalance = balanceOf(lotteryAddress);
                if(currentLotteryWalletBalance > 0){
                    transferTokensForLotteryToDrawingOrWinner(lotteryAddress, drawingAddress, currentLotteryWalletBalance, false);    // transfers the tokens to the drawing address

                    uint256 currentDrawingWalletBalance = balanceOf(drawingAddress);
                    amountToDisperseInDrawingTotal = currentDrawingWalletBalance;
                    amountToDisperseInDrawingLeft = currentDrawingWalletBalance;
                    amountToDisperseInDrawingPerPeriod = currentDrawingWalletBalance.div(periodsToDisperse);
                    dispersalTime = block.timestamp;
                    lotteryTime = lotteryTime.add(periodsToDisperse.mul(hoursInPeriodToDisperse)); // reset the lotteryTime back to the block until it's time for a new drawing 

                    bytes32 requestIdForRandomNum = getRandomNumber(block.timestamp);   // gets random number to determine lottery winner
                    currentLotteryWinner = lottoPool[randomResultFromLINKVRF];      // set current lottery winner

                    isExcludedFromLottery[currentLotteryWinner] = true;     // exclude him and remove chances from lotto pool
                    removeAddrFromLottoPoolCompletely(currentLotteryWinner);   // remove them from the lotto pool
                }
            }

        }
            
    }
    function weeklyLotteryManual() external onlyOwner() {
        weeklyLottery();
    }




    function lotteryDisperseFromDrawingWallet() private {      // gets called at the end of every transfer
        
        if(amountToDisperseInDrawingLeft > 0){  // make sure it has tokens to disperse
            if(block.timestamp >= dispersalTime) {    // is it time to disperse again?
                if(amountToDisperseInDrawingLeft > 0){

                    uint256 currentDrawingWalletBalance = balanceOf(drawingAddress);
                    if(currentDrawingWalletBalance >= amountToDisperseInDrawingPerPeriod){
                        transferTokensForLotteryToDrawingOrWinner(drawingAddress, currentLotteryWinner, amountToDisperseInDrawingPerPeriod, false);
                        amountToDisperseInDrawingLeft = amountToDisperseInDrawingLeft.sub(amountToDisperseInDrawingPerPeriod);
                    }
                    else if(currentDrawingWalletBalance > 0){
                        // this will just get rid of any remainder to the winner, there might be instances where there are left over tokens
                        transferTokensForLotteryToDrawingOrWinner(drawingAddress, currentLotteryWinner, amountToDisperseInDrawingLeft, false);
                        amountToDisperseInDrawingLeft = 0;
                    }

                }
                dispersalTime = block.timestamp + hoursInPeriodToDisperse;
            }
        }
    }
    function lotteryDisperseFromDrawingWalletManual() external onlyOwner() {
        lotteryDisperseFromDrawingWallet();
    }


    function getRandomNumber(uint256 userProvidedSeed) public returns (bytes32 requestId) {     // Requests randomness from a user-provided seed
        require(LINK.balanceOf(address(this)) >= feeForLINK, "Not enough LINK - fill contract with faucet");
        return requestRandomness(keyHashForLINK, feeForLINK, userProvidedSeed);
    }
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {   // Callback function used by VRF Coordinator
        randomResultFromLINKVRF = randomness.mod( (lottoPool.length.sub(1)) );       // gets a random element to use with the lotto array
    }


    function getSecondsUntilNextLotto() public view returns (uint256 secondsUntilNextLotto){
        if(lotteryTime.sub(block.timestamp) > 0){
            return lotteryTime.sub(block.timestamp);
        }
        return 0;
    }








    function transferTokensForLotteryToDrawingOrWinner(address sender, address recipient, uint256 transferAmount, bool takeFee) private {
        if (!takeFee) {
            removeAllFee();
        }
        (uint256 reflectAmount, uint256 reflectTransferAmount,uint256 reflectFee, uint256[6] memory taxLiqCharityBurnLotteryFeeArray) = getTaxAndReflectionValues(transferAmount);

        // (uint256 reflectAmount, uint256 reflectTransferAmount,uint256 reflectFee,uint256 taxTransferAmount,uint256 taxFee,uint256 taxLiquidity, uint256 taxCharityFee, uint256 taxBurnFee, uint256 taxLotteryFee) = getTaxAndReflectionValues(transferAmount);

        if(isAccountExcludedFromReward[sender]){    // is the sender address excluded from Reward?
            totalTokensOwned[sender] = totalTokensOwned[sender].sub(transferAmount);
        }

        reflectTokensOwned[sender] = reflectTokensOwned[sender].sub(reflectAmount);

        if(isAccountExcludedFromReward[recipient]){    // is the sender address excluded from Reward?
            totalTokensOwned[recipient] = totalTokensOwned[recipient].add(taxLiqCharityBurnLotteryFeeArray[5]);
        }

        reflectTokensOwned[recipient] = reflectTokensOwned[recipient].add(reflectTransferAmount);

        takeLiquidityFee(taxLiqCharityBurnLotteryFeeArray[1]);   

        takeCharityFee(taxLiqCharityBurnLotteryFeeArray[2]);      
        takeBurnFee(taxLiqCharityBurnLotteryFeeArray[3]);      
        takeLotteryFee(taxLiqCharityBurnLotteryFeeArray[4]);      

        takeReflectFee(reflectFee, taxLiqCharityBurnLotteryFeeArray[0]);

        amountTransferedWithinOneDay[sender] += transferAmount;

        emit Transfer(sender, recipient, taxLiqCharityBurnLotteryFeeArray[5]);

        if (!takeFee){
            restoreAllFee();
        } 

    }






    function setMaxDrawingChances(uint256 newMaxDrawingChances) public onlyOwner() {
        maxDrawingChances = newMaxDrawingChances;
    }

    function setAmountNeededForDrawingChance(uint256 newAmountNeededForDrawingChance) public onlyOwner() {
        amountNeededForDrawingChance = newAmountNeededForDrawingChance;
    }

    function setPeriodsToDisperse(uint256 newPeriodsToDisperse) public onlyOwner() {
        periodsToDisperse = newPeriodsToDisperse;
    }

    function setHoursInPeriodToDisperse(uint256 newHoursInPeriodToDisperse) public onlyOwner() {
        hoursInPeriodToDisperse = newHoursInPeriodToDisperse;
    }

    function setLotterySystemEnabled(bool isLotterySystemEnabledNew) public onlyOwner() {
        isLotterySystemEnabled = isLotterySystemEnabledNew;
    }


    function excludeOrIncludeFromLottery(address addressToExcludeInclude, bool setIsExcludedFromLottery) public onlyOwner() {
        isExcludedFromLottery[addressToExcludeInclude] = setIsExcludedFromLottery;
        if(setIsExcludedFromLottery){
            removeAddrFromLottoPoolCompletely(addressToExcludeInclude);   // remove them from the lotto pool
        }
    }




    function checkForLotteryParticipationOrRemoval(address addressToCheck) private {

        if(!isExcludedFromLottery[addressToCheck]){  // if the recipient isn't excluded from the lottery we must check balance and add 

            uint256 currentBalanceOfAddrToCheck = balanceOf(addressToCheck);


            if(currentBalanceOfAddrToCheck >= amountNeededForDrawingChance){       // make sure they have enough

                if(!hasEnoughTokensForLottery[addressToCheck]){
                    hasEnoughTokensForLottery[addressToCheck] = true;
                }

                uint256 numberOfChancesGivenCurrentAmount = currentBalanceOfAddrToCheck.div(amountNeededForDrawingChance); // get number of chances they should have
                if(numberOfChancesGivenCurrentAmount > maxDrawingChances){
                    numberOfChancesGivenCurrentAmount = maxDrawingChances;
                }

                uint256 numberOfChancesPreviously = numberOfEntriesIntoLottery[addressToCheck];

                if(numberOfChancesGivenCurrentAmount < numberOfChancesPreviously){      // removes entries
                    uint256 numEntriesToRemove = numberOfChancesPreviously.sub(numberOfChancesGivenCurrentAmount);      // get number of chances that should be removed

                    for (uint256 i = 0; i < lottoPool.length; i++) {    // goes through lotto pool to find him
                        if (lottoPool[i] == addressToCheck) {
                            delete lottoPool[i];
                            numEntriesToRemove--;
                            if(numEntriesToRemove == 0){
                                break;  // break when we have removed enough entries
                            }
                        }
                    }
                    lottoPool = cleanUpLotteryArray();
                }
                else if(numberOfChancesGivenCurrentAmount > numberOfChancesPreviously){     // add an entry
                    uint256 numEntriesToAdd = numberOfChancesGivenCurrentAmount.sub(numberOfChancesPreviously);     // gets num of chances to add
                    for (uint i = 0; i < numEntriesToAdd; i++){  // goes through lotto pool to find him
                        lottoPool.push(addressToCheck);
                    }
                }
                // if equal no changes needed, they should already be in the list, no need for an else here

                if(numberOfChancesGivenCurrentAmount != numberOfChancesPreviously){     // checks to see if the original amount was unequal, if they are then set it
                    numberOfEntriesIntoLottery[addressToCheck] = numberOfChancesGivenCurrentAmount;      // sets their new amount to the mapping
                }   // this should save on gas a tiny amount
                

            }
            else{

                if(hasEnoughTokensForLottery[addressToCheck]){      // checks to see if they at one point did have enough tokens, remove them out of lotto if they did
                    hasEnoughTokensForLottery[addressToCheck] = false;
                    removeAddrFromLottoPoolCompletely(addressToCheck);
                }
            }
        }
    }





    function removeIndexFromLotteryArray(uint index) private {
        if (index < lottoPool.length){
            for (uint256 i = index; i < lottoPool.length-1; i++){
                lottoPool[i] = lottoPool[i+1];
            }
            lottoPool.pop();
        }
    }
    function removeIndexFromLotteryArrayOwnerOnly(uint index) external onlyOwner() {   
        removeIndexFromLotteryArray(index);
    }


    function removeAddrFromLottoPoolCompletely(address addrToRemove) private {
        for (uint256 i = 0; i < lottoPool.length; i++) {    // goes through lotto pool to find him
            if (lottoPool[i] == addrToRemove) {
                delete lottoPool[i];        // sets this element to 0
            }
        }
        lottoPool = cleanUpLotteryArray();
        numberOfEntriesIntoLottery[addrToRemove] = 0;
    }

    

    function cleanUpLotteryArray() private returns (address[] memory) {
        delete lottoPoolTemp;
        for (uint256 i = 0; i < lottoPool.length; i++) {    // goes through lotto pool to find him
            if (lottoPool[i] != address(0)) {
                lottoPoolTemp.push(lottoPool[i]);
            }
        }
        return lottoPoolTemp;
    }



    

    ///////////////////// LOTTERY FUNCTIONS /////////////////////////////



    receive() external payable {}       // Oh it's payable alright.


}