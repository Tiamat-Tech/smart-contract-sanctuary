// SPDX-License-Identifier: MIT
pragma solidity 0.7.1;

import "./facades/IWETH.sol";
import "./facades/Ownable.sol";
import "./facades/Uniswap.sol";
import "./facades/IERC20.sol";
import "./facades/SafeMath.sol";

contract HodlerVault is Ownable {
    using SafeMath for uint;

    /** Emitted when purchaseLP() is called and LP tokens minted */
    event LPQueued(
        address hodler,
        uint amount,
        uint eth,
        uint zapTokens,
        uint timeStamp
    );

    /** Emitted when claimLP() is called */
    event LPClaimed(
        address hodler,
        uint amount,
        uint timestamp,
        uint donation
    );

    struct LPbatch {
        uint amount;
        uint timestamp;
        bool claimed;
    }

    struct HodlerVaultConfig {
        IERC20 zapToken;
        IUniswapV2Router02 uniswapRouter;
        IUniswapV2Pair tokenPair;
        address accVaultAddress;
        address payable marketingAddress;
        address weth;
        uint32 stakeDuration;
        uint16 donationShare; //0-10000
        uint16 purchaseFee; //0-10000
        uint16 marketingFee; //0-10000
    }

    bool public tokenTransferEnabled;
    bool private locked;
    bool public forceUnlock;

    modifier lock {
        require(!locked, "HodlerVault: reentrancy violation");
        locked = true;
        _;
        locked = false;
    }

    HodlerVaultConfig public config;
    //Front end can loop through this and inspect if enough time has passed
    mapping(address => LPbatch[]) public lockedLP;
    mapping(address => uint) public queueCounter;

    receive() external payable {}

    function maxTokensToInvest() public view returns (uint) {
        uint totalETH = address(this).balance;
        if (totalETH == 0) {
            return 0;
        }

        uint zapMaxAllowed;

        (uint reserve1, uint reserve2,) = config.tokenPair.getReserves();

        if (address(config.zapToken) < address(config.weth)) {
            zapMaxAllowed = config.uniswapRouter.quote(
                totalETH,
                reserve2,
                reserve1
            );
        } else {
            zapMaxAllowed = config.uniswapRouter.quote(
                totalETH,
                reserve1,
                reserve2
            );
        }

        return zapMaxAllowed;
    }

    function getLockedLP(address hodler, uint position)
        public
        view
        returns (
            address,
            uint,
            uint,
            bool
        )
    {
        LPbatch memory batch = lockedLP[hodler][position];
        return (hodler, batch.amount, batch.timestamp, batch.claimed);
    }

    function lockedLPLength(address hodler) public view returns (uint) {
        return lockedLP[hodler].length;
    }

    function getStakeDuration() public view returns (uint) {
        return forceUnlock ? 0 : config.stakeDuration;
    }

    function setTokenToMarketing(bool enabled) public onlyOwner {
        tokenTransferEnabled = enabled;
    }

    function seed(
        IERC20 zapToken,
        address uniswapPair,
        address uniswapRouter,
        address accVaultAddress,
        address payable marketingAddress
    ) public onlyOwner {
        config.zapToken = zapToken;
        config.uniswapRouter = IUniswapV2Router02(uniswapRouter);
        config.tokenPair = IUniswapV2Pair(uniswapPair);
        config.weth = config.uniswapRouter.WETH();

        setMarketingAddress(marketingAddress);
        setAccVaultAddress(accVaultAddress);

        setStageOptions(1);
    }

    function setParameters(uint32 duration, uint16 donationShare, uint16 purchaseFee, uint16 marketingFee)
        public
        onlyOwner
    {
        require(
            donationShare <= 10000,
            "HodlerVault: donation share % between 0 and 10000"
        );
        require(
            purchaseFee <= 10000,
            "HodlerVault: purchase fee share % between 0 and 10000"
        );
        require(
            marketingFee <= 10000,
            "HodlerVault: marketing fee share % between 0 and 10000"
        );

        config.stakeDuration = duration * 1 days;
        config.donationShare = donationShare;
        config.purchaseFee = purchaseFee;
        config.marketingFee = marketingFee;
    }

    function setMarketingAddress(address payable _marketingAddr) public onlyOwner {
        require(
            _marketingAddr != address(0),
            "HodlerVault: Marketing address is zero address"
        );

        config.marketingAddress = _marketingAddr;
    }

    function setAccVaultAddress(address _accVault) public onlyOwner {
        require(
            _accVault != address(0),
            "HodlerVault: Accelerator vault address is zero address"
        );

        config.accVaultAddress = _accVault;
    }

    function approveOnUni() public {
        config.zapToken.approve(address(config.uniswapRouter), uint(-1));
    }


    function purchaseLP(uint amount) public lock {
        require(amount > 0, "HodlerVault: Zap required to mint LP");
        require(config.zapToken.balanceOf(msg.sender) >= amount, "HodlerVault: Not enough Zap tokens");
        require(config.zapToken.allowance(msg.sender, address(this)) >= amount, "HodlerVault: Not enough Zap tokens allowance");

        uint zapFee = amount.mul(config.purchaseFee).div(10000);
        uint marketingFee = amount.mul(config.marketingFee).div(10000);
        uint netZap = amount.sub(zapFee).sub(marketingFee);

        (uint reserve1, uint reserve2, ) = config.tokenPair.getReserves();

        uint ethRequired;

        if (address(config.zapToken) > address(config.weth)) {
            ethRequired = config.uniswapRouter.quote(
                netZap,
                reserve2,
                reserve1
            );
        } else {
            ethRequired = config.uniswapRouter.quote(
                netZap,
                reserve1,
                reserve2
            );
        }

        require(
            address(this).balance >= ethRequired,
            "HodlerVault: insufficient ETH on HodlerVault"
        );

        config.zapToken.transferFrom(
            msg.sender,
            address(this),
            amount
        );

        IWETH(config.weth).deposit{ value: ethRequired }();
        address tokenPairAddress = address(config.tokenPair);
        IWETH(config.weth).transfer(tokenPairAddress, ethRequired);
        config.zapToken.transfer(tokenPairAddress, netZap);

        uint liquidityCreated = config.tokenPair.mint(address(this));

        if(zapFee > 0 && config.accVaultAddress != address(0)){
            config.zapToken.transfer(config.accVaultAddress, zapFee);
        }

        if (zapFee > 0 && config.marketingAddress != address(0)) {
            if (!tokenTransferEnabled) {
                address[] memory path = new address[](2);
                path[0] = address(config.zapToken);
                path[1] = address(config.weth);

                config.uniswapRouter.swapExactTokensForETH(
                    marketingFee,
                    0,
                    path,
                    config.marketingAddress,
                    block.timestamp
                );
            } else {
                config.zapToken.transfer(config.marketingAddress, marketingFee);
            }
        }

        lockedLP[msg.sender].push(
            LPbatch({
                amount: liquidityCreated,
                timestamp: block.timestamp,
                claimed: false
            })
        );

        emit LPQueued(
            msg.sender,
            liquidityCreated,
            ethRequired,
            netZap,
            block.timestamp
        );
    }

    //pops latest LP if older than period
    function claimLP() public {
        uint next = queueCounter[msg.sender];
        require(
            next < lockedLP[msg.sender].length,
            "HodlerVault: nothing to claim."
        );
        LPbatch storage batch = lockedLP[msg.sender][next];
        require(
            block.timestamp - batch.timestamp > getStakeDuration(),
            "HodlerVault: LP still locked."
        );
        next++;
        queueCounter[msg.sender] = next;
        uint donation = (config.donationShare * batch.amount) / 10000;
        batch.claimed = true;
        emit LPClaimed(msg.sender, batch.amount, block.timestamp, donation);
        require(
            config.tokenPair.transfer(address(0), donation),
            "HodlerVault: donation transfer failed in LP claim."
        );
        require(
            config.tokenPair.transfer(msg.sender, batch.amount - donation),
            "HodlerVault: transfer failed in LP claim."
        );
    }

    // Could not be canceled if activated
    function enableLPForceUnlock() public onlyOwner {
        forceUnlock = true;
    }

    function setStageOptions(uint8 stage) public onlyOwner {
        if(stage == 1){
            setParameters(30, 0, 1500, 0);
            setTokenToMarketing(true);
        }

        if(stage == 2){
            setParameters(30, 500, 2000, 0);
            setTokenToMarketing(true);
        }

        if(stage == 3){
            setParameters(15, 1000, 3000, 0);
            setTokenToMarketing(true);           
        }
    }
}