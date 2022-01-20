// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol"; // required for modifier
import "./Registry.sol";
import "./dapphub/DSProxyFactory.sol";
import "./dapphub/DSProxy.sol";
import "./Config.sol";
import "./LiquityMath.sol";
import "./interfaces/ITroveManager.sol";
import "./interfaces/IHintHelpers.sol";
import "./interfaces/ISortedTroves.sol";
import "./interfaces/ICollSurplusPool.sol";

/// @title Gatekeeper contract works as a gatekeeper into APUS protocol ecosystem
/// @notice The main motivation of gatekeeper is to give user understandable transaction to sign and to chain common sequence of transactions thus saving gas.
/// @dev It encodes all arguments and calls given user's smart account proxy with any additional arguments
contract Gatekeeper is Ownable, LiquityMath {

	/* solhint-disable var-name-mixedcase */

	/// @notice Registry's contracts IDs
	bytes32 private constant EXECUTOR_ID = keccak256("Executor");
	bytes32 private constant CONFIG_ID = keccak256("Config");
	bytes32 private constant AUTHORITY_ID = keccak256("Authority");
	bytes32 private constant PROXY_FACTORY_ID = keccak256("ProxyFactory");

	/// @notice APUS registry address
	address internal immutable registry;


	/// @notice Event raised when a new Smart Account is created. 
	event SmartAccountCreated(
		address owner,
		address smartAccountAddress
	);


	/// @notice Modifier will fail if message sender is not proxy owner
	/// @param _proxy Proxy address that should be owned
	modifier onlyProxyOwner(address payable _proxy) {
		require(DSProxy(_proxy).owner() == msg.sender, "Sender has to be proxy owner");
		_;
	}

	/* solhint-disable-next-line func-visibility */
	constructor(address _registry) Ownable() {
		registry = _registry;
	}

	/// @notice Execute proxy call with encoded transaction data
	/// @dev Proxy delegates call to executor address which is obtained from registry contract
	/// @param _proxy Proxy address to execute encoded transaction
	/// @param _data Transaction data to execute
	function _execute(address payable _proxy, bytes memory _data) internal onlyProxyOwner(_proxy) {
		_execute(_proxy, 0, _data);
	}

	/// @notice Execute proxy call with encoded transaction data and eth value
	/// @dev Proxy delegates call to executor address which is obtained from registry contract
	/// @param _proxy Proxy address to execute encoded transaction
	/// @param _value Value of eth to transfer with function call
	/// @param _data Transaction data to execute
	function _execute(address payable _proxy, uint256 _value, bytes memory _data) internal onlyProxyOwner(_proxy) {
		DSProxy(_proxy).execute{ value: _value }(Registry(registry).getAddress(EXECUTOR_ID), _data);
	}

	/// @notice Execute proxy call with encoded transaction data and eth value by anyone
	/** 
	 * @dev Proxy delegates call to executor address which is obtained from registry contract
	 *
	 * This is the DANGEROUS version as it enables the proxy call to be performed by anyone!
	 *
	 * However suitable for cases when user wants to provide ETH from other (proxy non-owning) accounts.
	 */
	/// @param _proxy Proxy address to execute encoded transaction
	/// @param _value Value of eth to transfer with function call
	/// @param _data Transaction data to execute
	function _executeByAnyone(address payable _proxy, uint256 _value, bytes memory _data) internal {
		DSProxy(_proxy).execute{ value: _value }(Registry(registry).getAddress(EXECUTOR_ID), _data);
	}

	// Gatekeeper MUST NOT be able to receive ETH from sender to itself
	// in 0.8.x function() is split to receive() and fallback(); if both are undefined -> tx reverts

	// ------------------------------------------ User functions ------------------------------------------


	/// @notice Creates the Smart Account directly. Its new address is emitted to the event.
	/// It is cheaper to open Smart Account while opening Credit Line.
	function openSmartAccount() external {
		_openSmartAccount();
	}

	/// @notice Builds the new MakerDAO's proxy aka Smart Account with enabled calls from this Gatekeeper
	function _openSmartAccount() internal returns(address payable newSmartAccountAddress) {

		// Use MakerDAO's proxy factory
		// DSProxyFactory constant internal DSProxyFactory = IDSProxyFactory(0xA26e15C895EFc0616177B7c1e7270A4C7D51C997);
		address proxyFactory = Registry(registry).getAddress(PROXY_FACTORY_ID);
		
		// Deploy a new MakerDAO's proxy onto blockchain
		DSProxy smartAccount = DSProxyFactory(proxyFactory).build();

		// Enable gatekeeper's user functions to call the Smart Account	
		DSAuthority gatekeeperAuthority = DSAuthority(Registry(registry).getAddress(AUTHORITY_ID));
		smartAccount.setAuthority(gatekeeperAuthority); 

		// Set owner of MakerDAO's proxy aka Smart Account to be the user
		smartAccount.setOwner(msg.sender);

		// Emit centraly at this contract
		emit SmartAccountCreated(msg.sender, address(smartAccount));
				
		return payable(smartAccount);
	}


	// L1 Liquity deployed contracts addresses
	// see https://docs.liquity.org/documentation/resources#contract-addresses
	/* solhint-disable const-name-snakecase */
//	IBorrowerOperations constant private BorrowerOperations = IBorrowerOperations(0x24179CD81c9e782A4096035f7eC97fB8B783e007);
	ITroveManager constant private TroveManager = ITroveManager(0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2);
	IHintHelpers constant private HintHelpers = IHintHelpers(0xE84251b93D9524E0d2e621Ba7dc7cb3579F997C0);
	ISortedTroves constant private SortedTroves = ISortedTroves(0x8FdD3fbFEb32b28fb73555518f8b361bCeA741A6);
	ICollSurplusPool constant private CollSurplusPool = ICollSurplusPool(0x3D32e8b97Ed5881324241Cf03b2DA5E2EBcE5521);
	/* solhint-enable const-name-snakecase */

	// TODO Liquity contracts on Rinkeby are on different addresses !!!!


	/// @notice Calculates Liquity sorting hints based on the provided NICR
	function getLiquityHints(uint256 NICR) internal view returns (
		address upperHint,
		address lowerHint
	){
		// Get an approximate address hint from the deployed HintHelper contract.
		uint256 numTroves = SortedTroves.getSize();
		uint256 numTrials = sqrt(numTroves) * 15;
		(address approxHint, , ) = HintHelpers.getApproxHint(NICR, numTrials, 0x41505553);

		// Use the approximate hint to get the exact upper and lower hints from the deployed SortedTroves contract
		(upperHint, lowerHint) = SortedTroves.findInsertPosition(NICR, approxHint, approxHint);
	}

	/// @notice Calculates LUSD expected debt to repay (includes _LUSDRequested, Adoption Contribution, Liquity protocol fee)
	function getLiquityExpectedDebtToRepay(uint256 _LUSDRequested) internal view returns (uint256 expectedDebtToRepay) {
		Config config = Config(Registry(registry).getAddress(CONFIG_ID));
		uint16 acr = config.adoptionContributionRate();

		uint256 expectedLiquityProtocolRate = TroveManager.getBorrowingRateWithDecay();

		uint256 neededLUSDAmount = calcNeededLiquityLUSDAmount(_LUSDRequested, expectedLiquityProtocolRate, acr );

		uint256 expectedLiquityProtocolFee = TroveManager.getBorrowingFeeWithDecay(neededLUSDAmount);

		expectedDebtToRepay = neededLUSDAmount + expectedLiquityProtocolFee;
	}

	/// @notice Makes a gasless calculation to get the data for the Credit Line's initial setup on Liquity protocol
    /// @param _LUSDRequested Requested LUSD amount to be taken by borrower. In e18 (1 LUSD = 1e18).
    /// @param _collateralAmount Amount of ETH to be deposited into the Credit Line. In wei (1 ETH = 1e18).
	/// @return expectedDebtToRepay Total amount of LUSD needed to close the Credit Line (exluding the 200 LUSD liquidation reserve).
	/// @return liquidationReserve Liquidation gas reserve required by the Liquity protocol.
	/// @return expectedCompositeDebtLiquity Total debt of the new Credit Line including the liquidation reserve. Valid for LTV (CR) calculations.
	/// @return NICR Nominal Individual Collateral Ratio for this calculation as defined and used by Liquity protocol.
	/// @return upperHint Calculated hint for gas optimalization of the Liquity protocol when opening new Credit Line with openCreditLineLiquity.
	/// @return lowerHint Calculated hint for gas optimalization of the Liquity protocol when opening new Credit Line with openCreditLineLiquity.
    function calculateInitialLiquityParameters(uint256 _LUSDRequested, uint256 _collateralAmount) public view returns(
		uint256 expectedDebtToRepay,
		uint256 liquidationReserve,
		uint256 expectedCompositeDebtLiquity,
        uint256 NICR,
		address upperHint,
		address lowerHint
    ){
		liquidationReserve = LIQUITY_LUSD_GAS_COMPENSATION;

		expectedDebtToRepay = getLiquityExpectedDebtToRepay(_LUSDRequested);

		expectedCompositeDebtLiquity = expectedDebtToRepay + LIQUITY_LUSD_GAS_COMPENSATION;

		// Get the nominal NICR of the new Liquity's trove
		NICR = _collateralAmount * 1e20 / expectedCompositeDebtLiquity;

		(upperHint, lowerHint) = getLiquityHints(NICR);
    }

	/// @notice Makes a gasless calculation to get the data for the Credit Line's adjustement on Liquity protocol
	/// @param _isDebtIncrease Indication whether _LUSDRequestedChange increases debt (true), decreases debt(false) or does not impact debt (false).
	/// @param _LUSDRequestedChange Amount of LUSD to be returned or further borrowed. The increase or decrease is indicated by _isDebtIncrease.
	///			Adoption Contribution and protocol's fees are applied in the form of additional debt in case of requested debt increase.
	/// @param _isCollateralIncrease Indication whether _LUSDRequestedChange increases debt (true), decreases debt(false) or does not impact debt (false).
	/// @param _collateralChange Amount of ETH collateral to be withdrawn or added. The increase or decrease is indicated by _isCollateralIncrease.
	/// @return newCollateral Calculated future collateral.
	/// @return expectedDebtToRepay Total future amount of LUSD needed to close the Credit Line (exluding the 200 LUSD liquidation reserve).
	/// @return liquidationReserve Liquidation gas reserve required by the Liquity protocol.
	/// @return expectedCompositeDebtLiquity Total future debt of the new Credit Line including the liquidation reserve. Valid for LTV (CR) calculations.
	/// @return NICR Nominal Individual Collateral Ratio for this calculation as defined and used by Liquity protocol.
	/// @return upperHint Calculated hint for gas optimalization of the Liquity protocol when opening new Credit Line with openCreditLineLiquity.
	/// @return lowerHint Calculated hint for gas optimalization of the Liquity protocol when opening new Credit Line with openCreditLineLiquity.
	/// @dev bools and uints are used to avoid typecasting and overflow issues and to explicitely signal the direction
	function calculateChangedLiquityParameters(
		bool _isDebtIncrease,
		uint256 _LUSDRequestedChange,
		bool _isCollateralIncrease,
		uint256 _collateralChange,
		address payable _smartAccount
	)  public view returns(
		uint256 newCollateral,
		uint256 expectedDebtToRepay,
		uint256 liquidationReserve,
		uint256 expectedCompositeDebtLiquity,
        uint256 NICR,
		address upperHint,
		address lowerHint
    ){
		liquidationReserve = LIQUITY_LUSD_GAS_COMPENSATION;

		// Get the current LUSD debt and ETH collateral
		(uint256 currentCompositeDebt, uint256 currentCollateral, , ) = TroveManager.getEntireDebtAndColl(_smartAccount);

		uint256 currentDebtToRepay = currentCompositeDebt - LIQUITY_LUSD_GAS_COMPENSATION;

		if (_isCollateralIncrease) {
			newCollateral = currentCollateral + _collateralChange;
		} else {
			newCollateral = currentCollateral - _collateralChange;
		}

		if (_isDebtIncrease) {
			uint256 additionalDebtToRepay = getLiquityExpectedDebtToRepay(_LUSDRequestedChange);
			expectedDebtToRepay = currentDebtToRepay + additionalDebtToRepay;
		} else {
			expectedDebtToRepay = currentDebtToRepay - _LUSDRequestedChange;
		}

		expectedCompositeDebtLiquity = expectedDebtToRepay + LIQUITY_LUSD_GAS_COMPENSATION;

		// Get the nominal NICR of the new Liquity's trove
		NICR = newCollateral * 1e20 / expectedCompositeDebtLiquity;

		(upperHint, lowerHint) = getLiquityHints(NICR);

	}

	/// @notice Opens a new Credit Line using Liquity protocol by depositing ETH collateral and borrowing LUSD.
	/// Creates the new Smart Account (MakerDAO's proxy) if requested.
	/// Use calculateInitialLiquityParameters for gasless calculation of proper Hints for _LUSDRequested.
	/// @param _LUSDRequested Amount of LUSD caller wants to borrow and withdraw. In e18 (1 LUSD = 1e18).
	/// @param _LUSDTo Address that will receive the generated LUSD. Can be different to save gas on transfer.
	/// @param _upperHint For gas optimalisation when using Liquity protocol. Use calculateInitialLiquityParameters for gasless calculation of proper Hints for _LUSDRequested.
	/// @param _lowerHint For gas optimalisation when using Liquity protocol. Use calculateInitialLiquityParameters for gasless calculation of proper Hints for _LUSDRequested.
	/// @param _smartAccount Smart Account address. When 0x0000...00 sender requests to open a new Smart Account.
	/// @dev Hints explained: https://github.com/liquity/dev#supplying-hints-to-trove-operations
	/// @dev Value is amount of ETH to deposit into Liquity protocol.
	function openCreditLineLiquity(uint256 _LUSDRequested, address _LUSDTo, address _upperHint, address _lowerHint, address payable _smartAccount) external payable {

		// By submitting 0x00..0 as the smartAccount address the caller wants to open a new Smart Account during this 1 transaction and thus saving gas.
		_smartAccount = (_smartAccount == address(0)) ? _openSmartAccount() : _smartAccount;

		_execute(_smartAccount, msg.value, abi.encodeWithSignature(
			"openCreditLineLiquity(uint256,address,address,address,address)",
			_LUSDRequested, _LUSDTo, _upperHint, _lowerHint, msg.sender
		));

	}

	/// @notice Allows a borrower to repay all LUSD debt, withdraw all their ETH collateral, and close their Credit Line on Liquity protocol.
	/// @param _LUSDFrom Address where the LUSD is being pulled from to repay debt.
	/// @param _collateralTo Address that will receive the withdrawn ETH.
	/// @param _smartAccount Smart Account address
	function closeCreditLineLiquity(address _LUSDFrom, address payable _collateralTo, address payable _smartAccount) public {

		_execute(_smartAccount, 
			abi.encodeWithSignature(
				"closeCreditLineLiquity(address,address payable,address)",
				_LUSDFrom,
				_collateralTo, 
				msg.sender
		));

	}

	/// @notice Allows a borrower to repay all LUSD debt, withdraw all their ETH collateral, and close their Credit Line on Liquity protocol.
	/// @param _smartAccount Smart Account address
	/// @dev This is a convenient facade function for borrower to avoid sending ETH to invalid address by mistake. Use the one with all parameters.
	function closeCreditLineLiquity(address payable _smartAccount) external {
		closeCreditLineLiquity(msg.sender, payable(msg.sender), _smartAccount);
	}

	/// @notice Enables a borrower to simultaneously change both their collateral and debt.
	/// Use calculateChangedLiquityParameters for gasless calculation of proper Hints for _LUSDRequestedChange.
	/// @param _isDebtIncrease Indication whether _LUSDRequestedChange increases debt (true), decreases debt(false) or does not impact debt (false).
	/// @param _LUSDRequestedChange Amount of LUSD to be returned or further borrowed.
	///			The increase or decrease is indicated by _isDebtIncrease.
	///			Adoption Contribution and protocol's fees are applied in the form of additional debt in case of requested debt increase.
	/// @param _LUSDFrom Address where the LUSD is being pulled from in case of to repaying debt.
	/// 		Approval of LUSD transfers for given Smart Account is required.
	/// @param _LUSDTo Address that will receive the generated LUSD.
	/// @param _collWithdrawal Amount of ETH collateral to withdraw. MUST be 0 if ETH is provided to increase collateral.
	/// @param _collateralTo Address that will receive the withdrawn collateral ETH.
	/// @param _upperHint For gas optimalisation when using Liquity protocol. Use calculateChangedLiquityParameters for gasless calculation of proper Hints for _LUSDRequestedChange.
	/// @param _lowerHint For gas optimalisation when using Liquity protocol. Use calculateChangedLiquityParameters for gasless calculation of proper Hints for _LUSDRequestedChange.
	/// @param _smartAccount Smart Account address
	/// @dev Hints explained: https://github.com/liquity/dev#supplying-hints-to-trove-operations
	/// @dev Hints should reflect calculated neededLUSDAmount instead of _LUSDRequestedAdditionally
	/// @dev Value is amount of ETH to deposit into Liquity protocol
	function adjustCreditLineLiquity(
		bool _isDebtIncrease,
		uint256 _LUSDRequestedChange,
		address _LUSDFrom,
		address _LUSDTo,
		uint256 _collWithdrawal,
		address payable _collateralTo,
		address _upperHint, address _lowerHint,
		address payable _smartAccount) external payable {

		_execute(_smartAccount, msg.value, abi.encodeWithSignature(
			"adjustCreditLineLiquity(bool,uint256,address,address,uint256,address payable,address,address,address)",
			_isDebtIncrease, _LUSDRequestedChange, _LUSDFrom, _LUSDTo, _collWithdrawal, _collateralTo, _upperHint, _lowerHint, msg.sender
		));

	}

	/// @notice Gasless check if there is anything to be claimed after the forced closure of the Liquity Credit Line
	function checkClaimableCollateralLiquity(address _smartAccount) external view returns (uint256){
		return CollSurplusPool.getCollateral(_smartAccount);
	}

	/// @notice Claims remaining collateral from the user's closed Credit Line (Liquity protocol) due to a redemption or a liquidation.
	/// @param _collateralTo Address that will receive the claimed collateral ETH.
	/// @param _smartAccount Smart Account address
	function claimRemainingCollateralLiquity(address payable _collateralTo, address payable _smartAccount) external {
		_execute(_smartAccount, abi.encodeWithSignature(
			"claimRemainingCollateralLiquity(address payable,address)",
			_collateralTo,
			msg.sender
		));
	}


	/// @notice Allows ANY ADDRESS (calling and paying) to add ETH collateral to borrower's Credit Line (Liquity protocol) and thus increase CR (decrease LTV ratio).
	/// @param _upperHint For gas optimalisation when using Liquity protocol. Use calculateChangedLiquityParameters for gasless calculation of proper Hints.
	/// @param _lowerHint For gas optimalisation when using Liquity protocol. Use calculateChangedLiquityParameters for gasless calculation of proper Hints.
	/// @param _smartAccount Smart Account address
	/// @dev Hints explained: https://github.com/liquity/dev#supplying-hints-to-trove-operations
	function addCollateralLiquity(address _upperHint, address _lowerHint, address payable _smartAccount) external payable {

		// Must be executable by anyone in order to be able to provide ETH by addresses, which do not own smart account proxy
		_executeByAnyone(_smartAccount, msg.value, abi.encodeWithSignature(
			"addCollateralLiquity(address,address,address)",
			_upperHint, _lowerHint, msg.sender
		));
	}

	/// @notice Withdraws amount of ETH collateral from the Credit Line and transfer to _collateralTo address.
	/// @param _collWithdrawal Amount of ETH collateral to withdraw
	/// @param _collateralTo Address that will receive the withdrawn collateral ETH
	/// @param _upperHint For gas optimalisation when using Liquity protocol. Use calculateChangedLiquityParameters for gasless calculation of proper Hints.
	/// @param _lowerHint For gas optimalisation when using Liquity protocol. Use calculateChangedLiquityParameters for gasless calculation of proper Hints.
	/// @param _smartAccount Smart Account address
	/// @dev Hints explained: https://github.com/liquity/dev#supplying-hints-to-trove-operations
	function withdrawCollateralLiquity(uint256 _collWithdrawal, address payable _collateralTo, address _upperHint, address _lowerHint, address payable _smartAccount) external {

		_execute(_smartAccount, abi.encodeWithSignature(
			"withdrawCollateralLiquity(uint256,address payable,address,address,address)",
			_collWithdrawal, _collateralTo, _upperHint, _lowerHint, msg.sender
		));

	}

	/// @notice Issues amount of LUSD from the liquity's protocol to the provided address.
	/// This increases the debt on the Credit Line, decreases CR (increases LTV).
	/// @param _LUSDRequestedChange Amount of LUSD to further borrow.
	/// @param _LUSDTo Address that will receive the generated LUSD. When 0 msg.sender is used.
	/// @param _upperHint For gas optimalisation when using Liquity protocol. Use calculateChangedLiquityParameters for gasless calculation of proper Hints for _LUSDRequestedChange.
	/// @param _lowerHint For gas optimalisation when using Liquity protocol. Use calculateChangedLiquityParameters for gasless calculation of proper Hints for _LUSDRequestedChange.
	/// @param _smartAccount Smart Account address
	/// @dev Hints explained: https://github.com/liquity/dev#supplying-hints-to-trove-operations
	/// @dev Hints should reflect calculated new debt instead of _LUSDRequestedChange
	function borrowLUSDLiquity(uint256 _LUSDRequestedChange, address _LUSDTo, address _upperHint, address _lowerHint, address payable _smartAccount) external {

		_execute(_smartAccount, abi.encodeWithSignature(
			"borrowLUSDLiquity(uint256,address,address,address,address)",
			_LUSDRequestedChange, _LUSDTo, _upperHint, _lowerHint, msg.sender
		));

	}

	/// @notice Enables ANYONE (calling and repaying) to partially repay the debt by the given amount of LUSD.
	/// Approval of LUSD transfers for given Smart Account is required.
	/// Use closeCreditLineLiquity to repay whole debt.
	/// @param _LUSDRequestedChange Amount of LUSD to be repaid. Repaying is subject to leaving 2000 LUSD min. debt in the Liquity protocol.
	/// @param _LUSDFrom Address where the LUSD is being pulled from to repay debt.
	/// @param _upperHint For gas optimalisation when using Liquity protocol. Use calculateChangedLiquityParameters for gasless calculation of proper Hints for _LUSDRequestedChange.
	/// @param _lowerHint For gas optimalisation when using Liquity protocol. Use calculateChangedLiquityParameters for gasless calculation of proper Hints for _LUSDRequestedChange.
	/// @param _smartAccount Smart Account address.
	/// @dev Hints explained: https://github.com/liquity/dev#supplying-hints-to-trove-operations
	/// @dev Hints should reflect calculated new debt instead of _LUSDRequestedChange
	function repayLUSDLiquity(uint256 _LUSDRequestedChange, address _LUSDFrom, address _upperHint, address _lowerHint, address payable _smartAccount) external {

		_executeByAnyone(_smartAccount, 0, abi.encodeWithSignature(
			"repayLUSDLiquity(uint256,address,address,address,address)",
			_LUSDRequestedChange, _LUSDFrom, _upperHint, _lowerHint, msg.sender
		));

	}

}