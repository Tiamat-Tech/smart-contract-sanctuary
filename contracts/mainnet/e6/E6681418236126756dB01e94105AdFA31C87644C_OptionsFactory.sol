pragma solidity ^0.5.10;

import "./interfaces/OracleInterface.sol";
import "./interfaces/UniswapFactoryInterface.sol";
import "./interfaces/UniswapExchangeInterface.sol";
import "./packages/ERC20.sol";
import "./packages/IERC20.sol";
import "./packages/ERC20Detailed.sol";
import "./packages/Ownable.sol";
import "./packages/SafeMath.sol";


/**
 * @title Opyn's Options Contract
 * @author Opyn
 */
contract OptionsContract is Ownable, ERC20 {
    using SafeMath for uint256;

    /* represents floting point numbers, where number = value * 10 ** exponent
    i.e 0.1 = 10 * 10 ** -3 */
    struct Number {
        uint256 value;
        int32 exponent;
    }

    // Keeps track of the weighted collateral and weighted debt for each vault.
    struct Vault {
        uint256 collateral;
        uint256 oTokensIssued;
        uint256 underlying;
        bool owned;
    }

    mapping(address => Vault) internal vaults;

    address payable[] public vaultOwners;

    // 10 is 0.01 i.e. 1% incentive.
    Number public liquidationIncentive = Number(10, -3);

    /* 500 is 0.5. Max amount that a Vault can be liquidated by i.e.
    max collateral that can be taken in one function call */
    Number public liquidationFactor = Number(500, -3);

    /* 16 means 1.6. The minimum ratio of a Vault's collateral to insurance promised.
    The ratio is calculated as below:
    vault.collateral / (Vault.oTokensIssued * strikePrice) */
    Number public minCollateralizationRatio = Number(10, -1);

    // The amount of insurance promised per oToken
    Number public strikePrice;

    // The amount of underlying that 1 oToken protects.
    Number public oTokenExchangeRate;

    /* UNIX time.
    Exercise period starts at `(expiry - windowSize)` and ends at `expiry` */
    uint256 internal windowSize;

    /* The total fees accumulated in the contract any time liquidate or exercise is called */
    uint256 internal totalFee;

    // The time of expiry of the options contract
    uint256 public expiry;

    // The precision of the collateral
    int32 public collateralExp = -18;

    // The precision of the underlying
    int32 public underlyingExp = -18;

    // The collateral asset
    IERC20 public collateral;

    // The asset being protected by the insurance
    IERC20 public underlying;

    // The asset in which insurance is denominated in.
    IERC20 public strike;

    // The Oracle used for the contract
    OracleInterface public oracle;

    // The name of  the contract
    string public name;

    // The symbol of  the contract
    string public symbol;

    // The number of decimals of the contract
    uint8 public decimals;

    // the state of the option contract, if true then all option functionalities are paused other than removing collateral
    bool internal isPaused;

    /**
     * @param _collateral The collateral asset
     * @param _underlying The asset that is being protected
     * @param _oTokenExchangeExp The precision of the `amount of underlying` that 1 oToken protects
     * @param _strikePrice The amount of strike asset that will be paid out per oToken
     * @param _strikeExp The precision of the strike price.
     * @param _strike The asset in which the insurance is calculated
     * @param _expiry The time at which the insurance expires
     * @param _windowSize UNIX time. Exercise window is from `expiry - _windowSize` to `expiry`.
     * @param _oracleAddress The address of the oracle
     */
    constructor(
        address _collateral,
        address _underlying,
        address _strike,
        int32 _oTokenExchangeExp,
        uint256 _strikePrice,
        int32 _strikeExp,
        uint256 _expiry,
        uint256 _windowSize,
        address _oracleAddress
    ) public {
        require(block.timestamp < _expiry, "Can't deploy an expired contract");
        require(
            _windowSize <= _expiry,
            "Exercise window can't be longer than the contract's lifespan"
        );

        require(
            isWithinExponentRange(_strikeExp),
            "strike price exponent not within expected range"
        );
        require(
            isWithinExponentRange(_oTokenExchangeExp),
            "oToken exchange rate exponent not within expected range"
        );

        require(
            address(_underlying) != address(0),
            "OptionsContract: Can't use ETH as underlying."
        );

        collateral = IERC20(_collateral);
        underlying = IERC20(_underlying);
        strike = IERC20(_strike);

        collateralExp = getAssetExp(_collateral);
        underlyingExp = getAssetExp(_underlying);
        require(
            isWithinExponentRange(collateralExp),
            "collateral exponent not within expected range"
        );
        require(
            isWithinExponentRange(underlyingExp),
            "underlying exponent not within expected range"
        );
        require(
            _oTokenExchangeExp >= underlyingExp,
            "Options Contract: The exchange rate has greater precision than the underlying"
        );

        oTokenExchangeRate = Number(1, _oTokenExchangeExp);

        strikePrice = Number(_strikePrice, _strikeExp);

        expiry = _expiry;
        oracle = OracleInterface(_oracleAddress);
        windowSize = _windowSize;
    }

    /*** Events ***/
    event VaultOpened(address payable vaultOwner);
    event ETHCollateralAdded(
        address payable vaultOwner,
        uint256 amount,
        address payer
    );
    event ERC20CollateralAdded(
        address payable vaultOwner,
        uint256 amount,
        address payer
    );
    event IssuedOTokens(
        address issuedTo,
        uint256 oTokensIssued,
        address payable vaultOwner
    );
    event Liquidate(
        uint256 amtCollateralToPay,
        address payable vaultOwner,
        address payable liquidator
    );
    event Exercise(
        uint256 amtUnderlyingToPay,
        uint256 amtCollateralToPay,
        address payable exerciser,
        address payable vaultExercisedFrom
    );
    event RedeemVaultBalance(
        uint256 amtCollateralRedeemed,
        uint256 amtUnderlyingRedeemed,
        address payable vaultOwner
    );
    event BurnOTokens(address payable vaultOwner, uint256 oTokensBurned);
    event RemoveCollateral(uint256 amtRemoved, address payable vaultOwner);
    event UpdateParameters(
        uint256 liquidationIncentive,
        uint256 liquidationFactor,
        uint256 minCollateralizationRatio,
        address owner
    );
    event TransferFee(address payable to, uint256 fees);
    event RemoveUnderlying(
        uint256 amountUnderlying,
        address payable vaultOwner
    );
    event OptionStateUpdated(
        bool oldState,
        bool newState,
        uint256 updateTimestamp
    );

    /**
     * @dev Throws if called Options contract is expired.
     */
    modifier notExpired() {
        require(!hasExpired(), "Options contract expired");
        _;
    }

    /**
     * @notice This function gets the length of vaultOwners array
     */
    function getVaultOwnersLength() external view returns (uint256) {
        return vaultOwners.length;
    }

    /**
     * @notice Can only be called by owner. Used to update the fees, minCollateralizationRatio, etc
     * @param _liquidationIncentive The incentive paid to liquidator. 10 is 0.01 i.e. 1% incentive.
     * @param _liquidationFactor Max amount that a Vault can be liquidated by. 500 is 0.5.
     * @param _minCollateralizationRatio The minimum ratio of a Vault's collateral to insurance promised. 16 means 1.6.
     */
    function updateParameters(
        uint256 _liquidationIncentive,
        uint256 _liquidationFactor,
        uint256 _minCollateralizationRatio
    ) external onlyOwner {
        require(
            _liquidationIncentive <= 200,
            "Can't have >20% liquidation incentive"
        );
        require(
            _liquidationFactor <= 1000,
            "Can't liquidate more than 100% of the vault"
        );
        require(
            _minCollateralizationRatio >= 10,
            "Can't have minCollateralizationRatio < 1"
        );

        liquidationIncentive.value = _liquidationIncentive;
        liquidationFactor.value = _liquidationFactor;
        minCollateralizationRatio.value = _minCollateralizationRatio;

        emit UpdateParameters(
            _liquidationIncentive,
            _liquidationFactor,
            _minCollateralizationRatio,
            owner()
        );
    }

    function harvest(address _token, uint256 _amount) external onlyOwner {
        require(
            (_token != address(underlying)) &&
                (_token != address(collateral)) &&
                (_token != address(strike)),
            "Owner can't harvest this token"
        );

        ERC20(_token).transfer(msg.sender, _amount);
    }

    /**
     * @notice Can only be called by owner. Used to set the name, symbol and decimals of the contract
     * @param _name The name of the contract
     * @param _symbol The symbol of the contract
     */
    function setDetails(string calldata _name, string calldata _symbol)
        external
        onlyOwner
    {
        name = _name;
        symbol = _symbol;
        decimals = uint8(-1 * oTokenExchangeRate.exponent);
    }

    /**
     * @notice Can only be called by owner. Used to take out the protocol fees from the contract.
     * @param _address The address to send the fee to.
     */
    function transferFee(address payable _address) external onlyOwner {
        uint256 fees = totalFee;
        totalFee = 0;
        transferCollateral(_address, fees);

        emit TransferFee(_address, fees);
    }

    /**
     * @notice Can only be called by owner. Used to pause and restart the option contract.
     * @dev can not restart an already running option, and can not pause an already paused option
     * @param _isPaused The option contract state, if true then pause the contract, if false then restart contract
     */
    function setIsPaused(bool _isPaused) external onlyOwner {
        require(_isPaused != isPaused, "Option contract already in that state");

        emit OptionStateUpdated(isPaused, _isPaused, now);

        isPaused = _isPaused;
    }

    /**
     * @notice Get option contract state. If option is paused should return true, else false.
     * @return option contract state
     */
    function isSystemPaused() public view returns (bool) {
        return isPaused;
    }

    /**
     * @notice Checks if a `owner` has already created a Vault
     * @param _owner The address of the supposed owner
     * @return true or false
     */
    function hasVault(address payable _owner) public view returns (bool) {
        return vaults[_owner].owned;
    }

    /**
     * @notice Creates a new empty Vault and sets the owner of the vault to be the msg.sender.
     */
    function openVault() public notExpired returns (bool) {
        require(!isSystemPaused(), "Option contract is paused");
        require(!hasVault(msg.sender), "Vault already created");

        vaults[msg.sender] = Vault(0, 0, 0, true);
        vaultOwners.push(msg.sender);

        emit VaultOpened(msg.sender);
        return true;
    }

    /**
     * @notice If the collateral type is ETH, anyone can call this function any time before
     * expiry to increase the amount of collateral in a Vault. Will fail if ETH is not the
     * collateral asset.
     * Remember that adding ETH collateral even if no oTokens have been created can put the owner at a
     * risk of losing the collateral if an exercise event happens.
     * Ensure that you issue and immediately sell oTokens to allow the owner to earn premiums.
     * (Either call the createAndSell function in the oToken contract or batch the
     * addERC20Collateral, issueOTokens and sell transactions and ensure they happen atomically to protect
     * the end user).
     * @param vaultOwner the index of the Vault to which collateral will be added.
     */
    function addETHCollateral(address payable vaultOwner)
        public
        payable
        notExpired
        returns (uint256)
    {
        require(!isSystemPaused(), "Option contract is paused");
        require(isETH(collateral), "ETH is not the specified collateral type");
        require(hasVault(vaultOwner), "Vault does not exist");

        emit ETHCollateralAdded(vaultOwner, msg.value, msg.sender);
        return _addCollateral(vaultOwner, msg.value);
    }

    /**
     * @notice If the collateral type is any ERC20, anyone can call this function any time before
     * expiry to increase the amount of collateral in a Vault. Can only transfer in the collateral asset.
     * Will fail if ETH is the collateral asset.
     * The user has to allow the contract to handle their ERC20 tokens on his behalf before these
     * functions are called.
     * Remember that adding ERC20 collateral even if no oTokens have been created can put the owner at a
     * risk of losing the collateral. Ensure that you issue and immediately sell the oTokens!
     * (Either call the createAndSell function in the oToken contract or batch the
     * addERC20Collateral, issueOTokens and sell transactions and ensure they happen atomically to protect
     * the end user).
     * @param vaultOwner the index of the Vault to which collateral will be added.
     * @param amt the amount of collateral to be transferred in.
     */
    function addERC20Collateral(address payable vaultOwner, uint256 amt)
        public
        notExpired
        returns (uint256)
    {
        require(!isSystemPaused(), "Option contract is paused");
        require(
            collateral.transferFrom(msg.sender, address(this), amt),
            "OptionsContract: transfer collateral failed."
        );
        require(hasVault(vaultOwner), "Vault does not exist");

        emit ERC20CollateralAdded(vaultOwner, amt, msg.sender);
        return _addCollateral(vaultOwner, amt);
    }

    /**
     * @notice Returns the amount of underlying to be transferred during an exercise call
     */
    function underlyingRequiredToExercise(uint256 oTokensToExercise)
        public
        view
        returns (uint256)
    {
        uint256 underlyingPerOTokenExp = uint256(
            oTokenExchangeRate.exponent - underlyingExp
        );

        // underlyingPerOTokenExp <= 60, no danger of overflowing uint256
        return oTokensToExercise.mul(10**underlyingPerOTokenExp);
    }

    /**
     * @notice Returns true if exercise can be called
     */
    function isExerciseWindow() public view returns (bool) {
        return ((block.timestamp >= expiry.sub(windowSize)) &&
            (block.timestamp < expiry));
    }

    /**
     * @notice Returns true if the oToken contract has expired
     */
    function hasExpired() public view returns (bool) {
        return (block.timestamp >= expiry);
    }

    /**
     * @notice Called by anyone holding the oTokens and underlying during the
     * exercise window i.e. from `expiry - windowSize` time to `expiry` time. The caller
     * transfers in their oTokens and corresponding amount of underlying and gets
     * `strikePrice * oTokens` amount of collateral out. The collateral paid out is taken from
     * the each vault owner starting with the first and iterating until the oTokens to exercise
     * are found.
     * NOTE: This uses a for loop and hence could run out of gas if the array passed in is too big!
     * @param oTokensToExercise the number of oTokens being exercised.
     * @param vaultsToExerciseFrom the array of vaults to exercise from.
     */
    function exercise(
        uint256 oTokensToExercise,
        address payable[] memory vaultsToExerciseFrom
    ) public payable {
        require(!isSystemPaused(), "Option contract is paused");
        require(oTokensToExercise > 0, "Can't exercise 0 oTokens");

        for (uint256 i = 0; i < vaultsToExerciseFrom.length; i++) {
            address payable vaultOwner = vaultsToExerciseFrom[i];
            require(
                hasVault(vaultOwner),
                "Cannot exercise from a vault that doesn't exist"
            );
            Vault storage vault = vaults[vaultOwner];
            if (oTokensToExercise == 0) {
                return;
            } else if (vault.oTokensIssued >= oTokensToExercise) {
                _exercise(oTokensToExercise, vaultOwner);
                return;
            } else {
                oTokensToExercise = oTokensToExercise.sub(vault.oTokensIssued);
                _exercise(vault.oTokensIssued, vaultOwner);
            }
        }
        require(
            oTokensToExercise == 0,
            "Specified vaults have insufficient collateral"
        );
    }

    /**
     * @notice This function allows the vault owner to remove their share of underlying after an exercise
     */
    function removeUnderlying() external {
        require(hasVault(msg.sender), "Vault does not exist");
        Vault storage vault = vaults[msg.sender];

        require(vault.underlying > 0, "No underlying balance");

        uint256 underlyingToTransfer = vault.underlying;
        vault.underlying = 0;

        transferUnderlying(msg.sender, underlyingToTransfer);
        emit RemoveUnderlying(underlyingToTransfer, msg.sender);
    }

    /**
     * @notice This function is called to issue the option tokens. Remember that issuing oTokens even if they
     * haven't been sold can put the owner at a risk of not making premiums on the oTokens. Ensure that you
     * issue and immidiately sell the oTokens! (Either call the createAndSell function in the oToken contract
     * of batch the issueOTokens transaction with a sell transaction and ensure it happens atomically).
     * @dev The owner of a Vault should only be able to have a max of
     * repo.collateral * collateralToStrike / (minCollateralizationRatio * strikePrice) tokens issued.
     * @param oTokensToIssue The number of o tokens to issue
     * @param receiver The address to send the oTokens to
     */
    function issueOTokens(uint256 oTokensToIssue, address receiver)
        public
        notExpired
    {
        require(!isSystemPaused(), "Option contract is paused");
        //check that we're properly collateralized to mint this number, then call _mint(address account, uint256 amount)
        require(hasVault(msg.sender), "Vault does not exist");

        Vault storage vault = vaults[msg.sender];

        // checks that the vault is sufficiently collateralized
        uint256 newOTokensBalance = vault.oTokensIssued.add(oTokensToIssue);
        require(isSafe(vault.collateral, newOTokensBalance), "unsafe to mint");

        // issue the oTokens
        vault.oTokensIssued = newOTokensBalance;
        _mint(receiver, oTokensToIssue);

        emit IssuedOTokens(receiver, oTokensToIssue, msg.sender);
        return;
    }

    /**
     * @notice Returns the vault for a given address
     * @param vaultOwner the owner of the Vault to return
     */
    function getVault(address payable vaultOwner)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            bool
        )
    {
        Vault storage vault = vaults[vaultOwner];
        return (
            vault.collateral,
            vault.oTokensIssued,
            vault.underlying,
            vault.owned
        );
    }

    /**
     * @notice Returns true if the given ERC20 is ETH.
     * @param _ierc20 the ERC20 asset.
     */
    function isETH(IERC20 _ierc20) public pure returns (bool) {
        return _ierc20 == IERC20(0);
    }

    /**
     * @notice allows the owner to burn their oTokens to increase the collateralization ratio of
     * their vault.
     * @param amtToBurn number of oTokens to burn
     * @dev only want to call this function before expiry. After expiry, no benefit to calling it.
     */
    function burnOTokens(uint256 amtToBurn) external notExpired {
        require(!isSystemPaused(), "Option contract is paused");
        require(hasVault(msg.sender), "Vault does not exist");

        Vault storage vault = vaults[msg.sender];

        vault.oTokensIssued = vault.oTokensIssued.sub(amtToBurn);
        _burn(msg.sender, amtToBurn);

        emit BurnOTokens(msg.sender, amtToBurn);
    }

    /**
     * @notice allows the owner to remove excess collateral from the vault before expiry. Removing collateral lowers
     * the collateralization ratio of the vault.
     * @param amtToRemove Amount of collateral to remove in 10^-18.
     */
    function removeCollateral(uint256 amtToRemove) external notExpired {
        require(amtToRemove > 0, "Cannot remove 0 collateral");
        require(hasVault(msg.sender), "Vault does not exist");

        Vault storage vault = vaults[msg.sender];
        require(
            amtToRemove <= getCollateral(msg.sender),
            "Can't remove more collateral than owned"
        );

        // check that vault will remain safe after removing collateral
        uint256 newCollateralBalance = vault.collateral.sub(amtToRemove);

        require(
            isSafe(newCollateralBalance, vault.oTokensIssued),
            "Vault is unsafe"
        );

        // remove the collateral
        vault.collateral = newCollateralBalance;
        transferCollateral(msg.sender, amtToRemove);

        emit RemoveCollateral(amtToRemove, msg.sender);
    }

    /**
     * @notice after expiry, each vault holder can get back their proportional share of collateral
     * from vaults that they own.
     * @dev The owner gets all of their collateral back if no exercise event took their collateral.
     */
    function redeemVaultBalance() external {
        require(hasExpired(), "Can't collect collateral until expiry");
        require(hasVault(msg.sender), "Vault does not exist");

        // pay out owner their share
        Vault storage vault = vaults[msg.sender];

        // To deal with lower precision
        uint256 collateralToTransfer = vault.collateral;
        uint256 underlyingToTransfer = vault.underlying;

        vault.collateral = 0;
        vault.oTokensIssued = 0;
        vault.underlying = 0;

        transferCollateral(msg.sender, collateralToTransfer);
        transferUnderlying(msg.sender, underlyingToTransfer);

        emit RedeemVaultBalance(
            collateralToTransfer,
            underlyingToTransfer,
            msg.sender
        );
    }

    /**
     * This function returns the maximum amount of collateral liquidatable if the given vault is unsafe
     * @param vaultOwner The index of the vault to be liquidated
     */
    function maxOTokensLiquidatable(address payable vaultOwner)
        external
        view
        returns (uint256)
    {
        if (isUnsafe(vaultOwner)) {
            Vault storage vault = vaults[vaultOwner];
            uint256 maxCollateralLiquidatable = vault
                .collateral
                .mul(liquidationFactor.value)
                .div(10**uint256(-liquidationFactor.exponent));

            uint256 one = 10**uint256(-liquidationIncentive.exponent);
            Number memory liqIncentive = Number(
                liquidationIncentive.value.add(one),
                liquidationIncentive.exponent
            );
            return calculateOTokens(maxCollateralLiquidatable, liqIncentive);
        } else {
            return 0;
        }
    }

    /**
     * @notice This function can be called by anyone who notices a vault is undercollateralized.
     * The caller gets a reward for reducing the amount of oTokens in circulation.
     * @dev Liquidator comes with _oTokens. They get _oTokens * strikePrice * (incentive + fee)
     * amount of collateral out. They can liquidate a max of liquidationFactor * vault.collateral out
     * in one function call i.e. partial liquidations.
     * @param vaultOwner The index of the vault to be liquidated
     * @param oTokensToLiquidate The number of oTokens being taken out of circulation
     */
    function liquidate(address payable vaultOwner, uint256 oTokensToLiquidate)
        external
        notExpired
    {
        require(!isSystemPaused(), "Option contract is paused");
        require(hasVault(vaultOwner), "Vault does not exist");

        Vault storage vault = vaults[vaultOwner];

        // cannot liquidate a safe vault.
        require(isUnsafe(vaultOwner), "Vault is safe");

        // Owner can't liquidate themselves
        require(msg.sender != vaultOwner, "Owner can't liquidate themselves");

        uint256 amtCollateral = calculateCollateralToPay(
            oTokensToLiquidate,
            Number(1, 0)
        );
        uint256 amtIncentive = calculateCollateralToPay(
            oTokensToLiquidate,
            liquidationIncentive
        );
        uint256 amtCollateralToPay = amtCollateral.add(amtIncentive);

        // calculate the maximum amount of collateral that can be liquidated
        uint256 maxCollateralLiquidatable = vault.collateral.mul(
            liquidationFactor.value
        );

        if (liquidationFactor.exponent > 0) {
            maxCollateralLiquidatable = maxCollateralLiquidatable.mul(
                10**uint256(liquidationFactor.exponent)
            );
        } else {
            maxCollateralLiquidatable = maxCollateralLiquidatable.div(
                10**uint256(-1 * liquidationFactor.exponent)
            );
        }

        require(
            amtCollateralToPay <= maxCollateralLiquidatable,
            "Can only liquidate liquidation factor at any given time"
        );

        // deduct the collateral and oTokensIssued
        vault.collateral = vault.collateral.sub(amtCollateralToPay);
        vault.oTokensIssued = vault.oTokensIssued.sub(oTokensToLiquidate);

        // transfer the collateral and burn the _oTokens
        _burn(msg.sender, oTokensToLiquidate);
        transferCollateral(msg.sender, amtCollateralToPay);

        emit Liquidate(amtCollateralToPay, vaultOwner, msg.sender);
    }

    /**
     * @notice checks if a vault is unsafe. If so, it can be liquidated
     * @param vaultOwner The number of the vault to check
     * @return true or false
     */
    function isUnsafe(address payable vaultOwner) public view returns (bool) {
        bool stillUnsafe = !isSafe(
            getCollateral(vaultOwner),
            getOTokensIssued(vaultOwner)
        );
        return stillUnsafe;
    }

    /**
     * @notice This function returns if an -30 <= exponent <= 30
     */
    function isWithinExponentRange(int32 val) internal pure returns (bool) {
        return ((val <= 30) && (val >= -30));
    }

    /**
     * @notice This function calculates and returns the amount of collateral in the vault
     */
    function getCollateral(address payable vaultOwner)
        internal
        view
        returns (uint256)
    {
        Vault storage vault = vaults[vaultOwner];
        return vault.collateral;
    }

    /**
     * @notice This function calculates and returns the amount of puts issued by the Vault
     */
    function getOTokensIssued(address payable vaultOwner)
        internal
        view
        returns (uint256)
    {
        Vault storage vault = vaults[vaultOwner];
        return vault.oTokensIssued;
    }

    /**
     * @notice Called by anyone holding the oTokens and underlying during the
     * exercise window i.e. from `expiry - windowSize` time to `expiry` time. The caller
     * transfers in their oTokens and corresponding amount of underlying and gets
     * `strikePrice * oTokens` amount of collateral out. The collateral paid out is taken from
     * the specified vault holder. At the end of the expiry window, the vault holder can redeem their balance
     * of collateral. The vault owner can withdraw their underlying at any time.
     * The user has to allow the contract to handle their oTokens and underlying on his behalf before these functions are called.
     * @param oTokensToExercise the number of oTokens being exercised.
     * @param vaultToExerciseFrom the address of the vaultOwner to take collateral from.
     * @dev oTokenExchangeRate is the number of underlying tokens that 1 oToken protects.
     */
    function _exercise(
        uint256 oTokensToExercise,
        address payable vaultToExerciseFrom
    ) internal {
        // 1. before exercise window: revert
        require(
            isExerciseWindow(),
            "Can't exercise outside of the exercise window"
        );

        require(hasVault(vaultToExerciseFrom), "Vault does not exist");

        Vault storage vault = vaults[vaultToExerciseFrom];
        require(oTokensToExercise > 0, "Can't exercise 0 oTokens");
        // Check correct amount of oTokens passed in)
        require(
            oTokensToExercise <= vault.oTokensIssued,
            "Can't exercise more oTokens than the owner has"
        );

        // 1. Check sufficient underlying
        // 1.1 update underlying balances
        uint256 amtUnderlyingToPay = underlyingRequiredToExercise(
            oTokensToExercise
        );
        vault.underlying = vault.underlying.add(amtUnderlyingToPay);

        // 2. Calculate Collateral to pay
        // 2.1 Payout enough collateral to get (strikePrice * oTokens) amount of collateral
        uint256 amtCollateralToPay = calculateCollateralToPay(
            oTokensToExercise,
            Number(1, 0)
        );

        require(
            amtCollateralToPay <= vault.collateral,
            "Vault underwater, can't exercise"
        );

        // 3. Update collateral + oToken balances
        vault.collateral = vault.collateral.sub(amtCollateralToPay);
        vault.oTokensIssued = vault.oTokensIssued.sub(oTokensToExercise);

        // 4. Transfer in underlying, burn oTokens + pay out collateral
        // 4.1 Transfer in underlying
        require(
            underlying.transferFrom(
                msg.sender,
                address(this),
                amtUnderlyingToPay
            ),
            "OptionsContract: Could not transfer in tokens"
        );

        // 4.2 burn oTokens
        _burn(msg.sender, oTokensToExercise);

        // 4.3 Pay out collateral
        transferCollateral(msg.sender, amtCollateralToPay);

        emit Exercise(
            amtUnderlyingToPay,
            amtCollateralToPay,
            msg.sender,
            vaultToExerciseFrom
        );
    }

    /**
     * @notice adds `_amt` collateral to `vaultOwner` and returns the new balance of the vault
     * @param vaultOwner the index of the vault
     * @param amt the amount of collateral to add
     */
    function _addCollateral(address payable vaultOwner, uint256 amt)
        internal
        notExpired
        returns (uint256)
    {
        Vault storage vault = vaults[vaultOwner];
        vault.collateral = vault.collateral.add(amt);

        return vault.collateral;
    }

    /**
     * @notice checks if a hypothetical vault is safe with the given collateralAmt and oTokensIssued
     * @param collateralAmt The amount of collateral the hypothetical vault has
     * @param oTokensIssued The amount of oTokens generated by the hypothetical vault
     * @return true or false
     */
    function isSafe(uint256 collateralAmt, uint256 oTokensIssued)
        internal
        view
        returns (bool)
    {
        // get price from Oracle
        uint256 collateralToEthPrice = 1;
        uint256 strikeToEthPrice = 1;

        if (collateral != strike) {
            collateralToEthPrice = getPrice(address(collateral));
            strikeToEthPrice = getPrice(address(strike));
        }

        // check `oTokensIssued * minCollateralizationRatio * strikePrice <= collAmt * collateralToStrikePrice`
        uint256 leftSideVal = oTokensIssued
            .mul(minCollateralizationRatio.value)
            .mul(strikePrice.value);
        int32 leftSideExp = minCollateralizationRatio.exponent +
            strikePrice.exponent;

        uint256 rightSideVal = (collateralAmt.mul(collateralToEthPrice)).div(
            strikeToEthPrice
        );
        int32 rightSideExp = collateralExp;

        uint256 exp = 0;
        bool stillSafe = false;

        if (rightSideExp < leftSideExp) {
            exp = uint256(leftSideExp - rightSideExp);
            stillSafe = leftSideVal.mul(10**exp) <= rightSideVal;
        } else {
            exp = uint256(rightSideExp - leftSideExp);
            stillSafe = leftSideVal <= rightSideVal.mul(10**exp);
        }

        return stillSafe;
    }

    /**
     * This function returns the maximum amount of oTokens that can safely be issued against the specified amount of collateral.
     * @param collateralAmt The amount of collateral against which oTokens will be issued.
     */
    function maxOTokensIssuable(uint256 collateralAmt)
        external
        view
        returns (uint256)
    {
        return calculateOTokens(collateralAmt, minCollateralizationRatio);
    }

    /**
     * @notice This function is used to calculate the amount of tokens that can be issued.
     * @dev The amount of oTokens is determined by:
     * oTokensIssued  <= collateralAmt * collateralToStrikePrice / (proportion * strikePrice)
     * @param collateralAmt The amount of collateral
     * @param proportion The proportion of the collateral to pay out. If 100% of collateral
     * should be paid out, pass in Number(1, 0). The proportion might be less than 100% if
     * you are calculating fees.
     */
    function calculateOTokens(uint256 collateralAmt, Number memory proportion)
        internal
        view
        returns (uint256)
    {
        // get price from Oracle
        uint256 collateralToEthPrice = 1;
        uint256 strikeToEthPrice = 1;

        if (collateral != strike) {
            collateralToEthPrice = getPrice(address(collateral));
            strikeToEthPrice = getPrice(address(strike));
        }

        // oTokensIssued  <= collAmt * collateralToStrikePrice / (proportion * strikePrice)
        uint256 denomVal = proportion.value.mul(strikePrice.value);
        int32 denomExp = proportion.exponent + strikePrice.exponent;

        uint256 numeratorVal = (collateralAmt.mul(collateralToEthPrice)).div(
            strikeToEthPrice
        );
        int32 numeratorExp = collateralExp;

        uint256 exp = 0;
        uint256 numOptions = 0;

        if (numeratorExp < denomExp) {
            exp = uint256(denomExp - numeratorExp);
            numOptions = numeratorVal.div(denomVal.mul(10**exp));
        } else {
            exp = uint256(numeratorExp - denomExp);
            numOptions = numeratorVal.mul(10**exp).div(denomVal);
        }

        return numOptions;
    }

    /**
     * @notice This function calculates the amount of collateral to be paid out.
     * @dev The amount of collateral to paid out is determined by:
     * (proportion * strikePrice * strikeToCollateralPrice * oTokens) amount of collateral.
     * @param _oTokens The number of oTokens.
     * @param proportion The proportion of the collateral to pay out. If 100% of collateral
     * should be paid out, pass in Number(1, 0). The proportion might be less than 100% if
     * you are calculating fees.
     */
    function calculateCollateralToPay(
        uint256 _oTokens,
        Number memory proportion
    ) internal view returns (uint256) {
        // Get price from oracle
        uint256 collateralToEthPrice = 1;
        uint256 strikeToEthPrice = 1;

        if (collateral != strike) {
            collateralToEthPrice = getPrice(address(collateral));
            strikeToEthPrice = getPrice(address(strike));
        }

        // calculate how much should be paid out
        uint256 amtCollateralToPayInEthNum = _oTokens
            .mul(strikePrice.value)
            .mul(proportion.value)
            .mul(strikeToEthPrice);
        int32 amtCollateralToPayExp = strikePrice.exponent +
            proportion.exponent -
            collateralExp;
        uint256 amtCollateralToPay = 0;
        uint256 exp;
        if (amtCollateralToPayExp > 0) {
            exp = uint256(amtCollateralToPayExp);
            amtCollateralToPay = amtCollateralToPayInEthNum.mul(10**exp).div(
                collateralToEthPrice
            );
        } else {
            exp = uint256(-1 * amtCollateralToPayExp);
            amtCollateralToPay = amtCollateralToPayInEthNum.div(10**exp).div(
                collateralToEthPrice
            );
        }
        require(exp <= 77, "Options Contract: Exponentiation overflowed");

        return amtCollateralToPay;
    }

    /**
     * @notice This function transfers `amt` collateral to `_addr`
     * @param _addr The address to send the collateral to
     * @param _amt The amount of the collateral to pay out.
     */
    function transferCollateral(address payable _addr, uint256 _amt) internal {
        if (isETH(collateral)) {
            _addr.transfer(_amt);
        } else {
            require(
                collateral.transfer(_addr, _amt),
                "OptionsContract: transfer collateral failed."
            );
        }
    }

    /**
     * @notice This function transfers `amt` underlying to `_addr`
     * @param _addr The address to send the underlying to
     * @param _amt The amount of the underlying to pay out.
     */
    function transferUnderlying(address payable _addr, uint256 _amt) internal {
        require(
            underlying.transfer(_addr, _amt),
            "OptionsContract: transfer underlying failed"
        );
    }

    /**
     * @dev internal function to parse token decimals for constructor
     * @param _asset the asset address
     */
    function getAssetExp(address _asset) internal view returns (int32) {
        if (_asset == address(0)) return -18;
        return -1 * int32(ERC20Detailed(_asset).decimals());
    }

    /**
     * @notice This function gets the price ETH (wei) to asset price.
     * @param asset The address of the asset to get the price of
     */
    function getPrice(address asset) internal view returns (uint256) {
        return oracle.getPrice(asset);
    }
}