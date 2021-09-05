// SPDX-License-Identifier: Unlicensed

pragma solidity 0.7.1;

import "./facades/IWETH.sol";
import "./facades/Ownable.sol";
import "./facades/Uniswap.sol";
import "./facades/IERC20.sol";

contract AcceleratorVault is Ownable {
    /** Emitted when purchaseLP() is called to track ETH amounts */
    event EthTransferred(
        address from,
        uint amount,
        uint percentageAmount,
        bool ethFeeTransferEnabled
    );

    /** Emitted when purchaseLP() is called and LP tokens minted */
    event LPQueued(
        address holder,
        uint amount,
        uint eth,
        uint zapToken,
        uint timestamp
    );

    /** Emitted when claimLP() is called */
    event LPClaimed(
        address holder,
        uint amount,
        uint timestamp,
        uint exitFee,
        bool claimed
    );

    struct LPbatch {
        address holder;
        uint amount;
        uint timestamp;
        bool claimed;
    }

    struct AcceleratorVaultConfig {
        address zapToken;
        IUniswapV2Router02 uniswapRouter;
        IUniswapV2Pair tokenPair;
        address weth;
        address payable ethHodler;
        uint32 stakeDuration;
        uint16 donationShare; //0-10000
        uint16 purchaseFee; //0-10000
    }

    bool public ethFeeTransferEnabled;
    bool public forceUnlock;
    bool private locked;

    modifier lock {
        require(!locked, "AcceleratorVault: reentrancy violation");
        locked = true;
        _;
        locked = false;
    }

    AcceleratorVaultConfig public config;

    mapping(address => LPbatch[]) public lockedLP;
    mapping(address => uint) public queueCounter;

    function seed(
        address zapToken,
        address uniswapPair,
        address uniswapRouter,
        address payable ethHodler
    ) public onlyOwner {
        config.zapToken = zapToken;
        config.uniswapRouter = IUniswapV2Router02(uniswapRouter);
        config.tokenPair = IUniswapV2Pair(uniswapPair);
        config.weth = config.uniswapRouter.WETH();
        setEthHodlerAddress(ethHodler);
        setStageOptions(1);
    }

    function getStakeDuration() public view returns (uint) {
        return forceUnlock ? 0 : config.stakeDuration;
    }

    // Could not be canceled if activated
    function enableLPForceUnlock() public onlyOwner {
        forceUnlock = true;
    }

    function setEthFeeToHodler() public onlyOwner {
        ethFeeTransferEnabled = true;
    }

    function setBuyPressure() public onlyOwner {
        ethFeeTransferEnabled = false;
    }

    function setEthHodlerAddress(address payable ethHodler) public onlyOwner {
        require(
            ethHodler != address(0),
            "AcceleratorVault: eth receiver is zero address"
        );

        config.ethHodler = ethHodler;
    }

    function setParameters(uint32 duration, uint16 donationShare, uint16 purchaseFee)
        public
        onlyOwner
    {
        require(
            donationShare <= 10000,
            "AcceleratorVault: donation share % between 0 and 10000"
        );
        require(
            purchaseFee <= 10000,
            "AcceleratorVault: purchase fee share % between 0 and 10000"
        );

        config.stakeDuration = duration * 1 days;
        config.donationShare = donationShare;
        config.purchaseFee = purchaseFee;
    }

    function purchaseLPFor(address beneficiary) public payable lock {
        require(msg.value > 0, "AcceleratorVault: ETH required to mint ZAP LP");

        uint feeValue = (config.purchaseFee * msg.value) / 10000;
        uint exchangeValue = msg.value - feeValue;

        (uint reserve1, uint reserve2, ) = config.tokenPair.getReserves();

        uint zapRequired;

        if (address(config.zapToken) < address(config.weth)) {
            zapRequired = config.uniswapRouter.quote(
                exchangeValue,
                reserve2,
                reserve1
            );
        } else {
            zapRequired = config.uniswapRouter.quote(
                exchangeValue,
                reserve1,
                reserve2
            );
        }

        uint balance = IERC20(config.zapToken).balanceOf(address(this));
        require(
            balance >= zapRequired,
            "AcceleratorVault: insufficient ZAP tokens in AcceleratorVault"
        );

        IWETH(config.weth).deposit{ value: exchangeValue }();
        address tokenPairAddress = address(config.tokenPair);
        IWETH(config.weth).transfer(tokenPairAddress, exchangeValue);
        IERC20(config.zapToken).transfer(
            tokenPairAddress,
            zapRequired
        );

        uint liquidityCreated = config.tokenPair.mint(address(this));

        if (!ethFeeTransferEnabled) {
            address[] memory path = new address[](2);
            path[0] = address(config.weth);
            path[1] = address(config.zapToken);

            config.uniswapRouter.swapExactETHForTokens{ value: feeValue }(
                0,
                path,
                address(this),
                block.timestamp
            );
        } else {
            //ETH receiver is hodler vault here
            config.ethHodler.transfer(feeValue);
        }

        lockedLP[beneficiary].push(
            LPbatch({
                holder: beneficiary,
                amount: liquidityCreated,
                timestamp: block.timestamp,
                claimed: false
            })
        );

        emit LPQueued(
            beneficiary,
            liquidityCreated,
            exchangeValue,
            zapRequired,
            block.timestamp
        );

        emit EthTransferred(msg.sender, exchangeValue, feeValue, ethFeeTransferEnabled);
    }

    //send eth to match with ZAP tokens in AcceleratorVault
    function purchaseLP() public payable {
        purchaseLPFor(msg.sender);
    }

    function claimLP() public {
        uint next = queueCounter[msg.sender];
        require(
            next < lockedLP[msg.sender].length,
            "AcceleratorVault: nothing to claim."
        );
        LPbatch storage batch = lockedLP[msg.sender][next];
        require(
            block.timestamp - batch.timestamp > getStakeDuration(),
            "AcceleratorVault: LP still locked."
        );
        next++;
        queueCounter[msg.sender] = next;
        uint donation = (config.donationShare * batch.amount) / 10000;
        batch.claimed = true;
        emit LPClaimed(msg.sender, batch.amount, block.timestamp, donation, batch.claimed);
        require(
            config.tokenPair.transfer(address(0), donation),
            "AcceleratorVault: donation transfer failed in LP claim."
        );
        require(
            config.tokenPair.transfer(batch.holder, batch.amount - donation),
            "AcceleratorVault: transfer failed in LP claim."
        );
    }

    function lockedLPLength(address holder) public view returns (uint) {
        return lockedLP[holder].length;
    }

    function getLockedLP(address holder, uint position)
        public
        view
        returns (
            address,
            uint,
            uint,
            bool
        )
    {
        LPbatch memory batch = lockedLP[holder][position];
        return (batch.holder, batch.amount, batch.timestamp, batch.claimed);
    }

    function setStageOptions(uint8 stage) public onlyOwner{
        if(stage == 1){
            setParameters(5, 1000, 3000);
            setEthFeeToHodler();
        }

        if(stage == 2){
            setParameters(30, 500, 3000);
            setBuyPressure();
        }

        if(stage == 3){
            setParameters(3, 1000, 3750);
            setEthFeeToHodler();
        }
    }
}