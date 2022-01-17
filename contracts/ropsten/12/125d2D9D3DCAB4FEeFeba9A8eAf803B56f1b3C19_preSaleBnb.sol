pragma solidity ^0.8.9;

// SPDX-License-Identifier: MIT

import './Interfaces/IPreSale.sol';

contract preSaleBnb is ReentrancyGuard {

    using SafeMath for uint256;
    
    address payable public admin;
    address payable public tokenOwner;
    address public deployer;
    IERC20 public token;
    IPancakeRouter02 public routerAddress;
    IGalaxyPadStake public stake;

    uint256 public adminFeePercent;
    uint256 public tokenPrice;
    uint256 public preSaleTime;
    uint256 public hardCap;
    uint256 public softCap;
    uint256 public listingPrice;
    uint256 public liquidityPercent;
    uint256 public soldTokens;
    uint256 public preSaleTokens;
    uint256 public totalUser;
    uint256 public amountRaised;

    bool public allow;
    bool public canClaim;

    mapping(address => uint256) public tokenBalance;
    mapping(address => uint256) public bnbBalance;
    

    modifier onlyAdmin(){
        require(msg.sender == admin,"GalaxyPad: Not an admin");
        _;
    }

    modifier onlyTokenOwner(){
        require(msg.sender == tokenOwner,"GalaxyPad: Not a token owner");
        _;
    }

    modifier allowed(){
        require(allow == true,"GalaxyPad: Not allowed");
        _;
    }
    
    event tokenBought(address indexed user, uint256 indexed numberOfTokens, uint256 indexed amountbnb);

    event tokenClaimed(address indexed user, uint256 indexed numberOfTokens);

    event tokenUnSold(address indexed user, uint256 indexed numberOfTokens);

    constructor() {
        deployer = msg.sender;
        allow = true;
        admin = payable(0x1bF99f349eFdEa693e622792A3D70833979E2854);
        stake = IGalaxyPadStake(0x11A8Cd57Fa94771116AFA81baCc377846D415Eb0);
        adminFeePercent = 2;
    }

    // called once by the deployer contract at time of deployment
    function initialize(
        address _tokenOwner,
        IERC20 _token,
        uint256 [6] memory values,
        address _routerAddress
    ) external {
        require(msg.sender == deployer, "GalaxyPad: FORBIDDEN"); // sufficient check
        tokenOwner = payable(_tokenOwner);
        token = _token;
        tokenPrice = values[0];
        preSaleTime = values[1];
        hardCap = values[2];
        softCap = values[3];
        listingPrice = values[4];
        liquidityPercent = values[5];
        routerAddress = IPancakeRouter02(_routerAddress);
        preSaleTokens = bnbToToken(hardCap);
    }

    receive() payable external{}
    
    // to buy token during preSale time => for web3 use
    function buyToken() public payable allowed isHuman{
        require(block.timestamp < preSaleTime,"GalaxyPad: Time over"); // time check
        require(getContractBnbBalance() <= hardCap,"GalaxyPad: Hardcap reached");
        uint256 numberOfTokens = bnbToToken(msg.value);
        uint256[4] memory tierAmount = stake.distributioncalculation(preSaleTokens);
        uint256 userTier = stake.usertier(msg.sender);
        require(numberOfTokens.add(tokenBalance[msg.sender]) <= tierAmount[userTier],"GalaxyPad: Amount exceeded tier limit");
        if(tokenBalance[msg.sender] == 0){
            totalUser++;
        }
        tokenBalance[msg.sender] = tokenBalance[msg.sender].add(numberOfTokens);
        bnbBalance[msg.sender] = bnbBalance[msg.sender].add(msg.value);
        soldTokens = soldTokens.add(numberOfTokens);
        amountRaised = amountRaised.add(msg.value);

        emit tokenBought(msg.sender, numberOfTokens, msg.value);
    }

    function claim() public allowed isHuman{
        require(block.timestamp > preSaleTime,"GalaxyPad: Presale not over");
        require(canClaim == true,"GalaxyPad: pool not initialized yet");

        if(amountRaised < softCap){
            uint256 numberOfTokens = bnbBalance[msg.sender];
            require(numberOfTokens > 0,"GalaxyPad: Zero balance");
        
            payable(msg.sender).transfer(numberOfTokens);
            bnbBalance[msg.sender] = 0;

            emit tokenClaimed(msg.sender, numberOfTokens);
        }else {
            uint256 numberOfTokens = tokenBalance[msg.sender];
            require(numberOfTokens > 0,"GalaxyPad: Zero balance");
        
            token.transfer(msg.sender, numberOfTokens);
            tokenBalance[msg.sender] = 0;

            emit tokenClaimed(msg.sender, numberOfTokens);
        }
    }
    
    function withdrawAndInitializePool() public onlyTokenOwner allowed isHuman{
        require(block.timestamp > preSaleTime,"GalaxyPad: PreSale not over yet");
        if(amountRaised > softCap){
            canClaim = true;
            uint256 bnbAmountForLiquidity = amountRaised.mul(liquidityPercent).div(100);
            uint256 tokenAmountForLiquidity = listingTokens(bnbAmountForLiquidity);
            token.approve(address(routerAddress), tokenAmountForLiquidity);
            addLiquidity(tokenAmountForLiquidity, bnbAmountForLiquidity);
            admin.transfer(amountRaised.mul(adminFeePercent).div(100));
            token.transfer(admin, soldTokens.mul(adminFeePercent).div(100));
            tokenOwner.transfer(getContractBnbBalance());
            uint256 refund = getContractTokenBalance().sub(soldTokens);
            if(refund > 0)
                token.transfer(tokenOwner, refund);
        
            emit tokenUnSold(tokenOwner, refund);
        }else{
            canClaim = true;
            token.transfer(tokenOwner, getContractTokenBalance());

            emit tokenUnSold(tokenOwner, getContractBnbBalance());
        }
    }    
    
    
    function addLiquidity(
        uint256 tokenAmount,
        uint256 bnbAmount
    ) internal {
        IPancakeRouter02 pancakeRouter = IPancakeRouter02(routerAddress);

        // add the liquidity
        pancakeRouter.addLiquidityETH{value : bnbAmount}(
            address(token),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            tokenOwner,
            block.timestamp + 360
        );
    }

    // to check number of token for buying
    function bnbToToken(uint256 _amount) public view returns(uint256){
        uint256 numberOfTokens = _amount.mul(tokenPrice).mul(1000).div(1e18);
        return numberOfTokens.mul(10 ** (token.decimals())).div(1000);
    }
    
    // to calculate number of tokens for listing price
    function listingTokens(uint256 _amount) public view returns(uint256){
        uint256 numberOfTokens = _amount.mul(listingPrice).mul(1000).div(1e18);
        return numberOfTokens.mul(10 ** (token.decimals())).div(1000);
    }

    // to check contribution
    function userContribution(address _user) public view returns(uint256){
        return bnbBalance[_user];
    }

    // to check token balance of user
    function userTokenBalance(address _user) public view returns(uint256){
        return tokenBalance[_user];
    }

    // to Stop preSale in case of scam
    function setAllow(bool _enable) external onlyAdmin{
        allow = _enable;
    }
    
    function getContractBnbBalance() public view returns(uint256){
        return address(this).balance;
    }
    
    function getContractTokenBalance() public view returns(uint256){
        return token.balanceOf(address(this));
    }
    
}