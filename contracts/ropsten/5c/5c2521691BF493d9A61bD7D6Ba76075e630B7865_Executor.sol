// SPDX-License-Identifier: GPL-3.0-only
pragma solidity =0.8.10;

import "./Config.sol";
import "./Registry.sol";
import "./dapphub/DSProxyFactory.sol";
import "./CentralLogger.sol";
import "./interfaces/IBorrowerOperations.sol";
import "./interfaces/ITroveManager.sol";
import "./interfaces/ICollSurplusPool.sol";
import "./interfaces/ILUSDToken.sol";
import "./LiquityMath.sol";

/// @title APUS execution logic
/// @dev Should be called as delegatecall from APUS smart account proxy
contract Executor is LiquityMath{

	// ================================================================================
	// WARNING!!!!
	// Executor must not have or store any stored variables (constant and immutable variables are not stored).
	// It could conflict with proxy storage as it is called via delegatecall from proxy.
	// ================================================================================

	/// @notice Registry's contracts IDs
	bytes32 private constant PROXY_FACTORY_ID = keccak256("ProxyFactory");
	bytes32 private constant CONFIG_ID = keccak256("Config");
	bytes32 private constant CENTRAL_LOGGER_ID = keccak256("CentralLogger");

	/// @notice APUS registry address
	address internal immutable registry;


	/// @notice Modifier will fail if function is not called within Apus proxy contract
	/// @dev Mofifier gets proxy factory address from Apus registry and checks if current address is valid Apus proxy
	modifier onlyProxy() {
		address proxyFactory = Registry(registry).getAddress(PROXY_FACTORY_ID);
		require(DSProxyFactory(proxyFactory).isProxy(address(this)), "Executor has to be called within valid Proxy");
		_;
	}

	/* solhint-disable-next-line func-visibility */
	constructor(address _registry) {
		registry = _registry;
	}

	// ------------------------------------------ Liquity functions ------------------------------------------

	// L1 Liquity deployed contracts addresses
	// see https://docs.liquity.org/documentation/resources#contract-addresses
	/* solhint-disable const-name-snakecase */
	IBorrowerOperations constant private BorrowerOperations = IBorrowerOperations(0x24179CD81c9e782A4096035f7eC97fB8B783e007);
	ITroveManager constant private TroveManager = ITroveManager(0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2);
	ICollSurplusPool constant private CollSurplusPool = ICollSurplusPool(0x3D32e8b97Ed5881324241Cf03b2DA5E2EBcE5521);
    address internal constant LUSDTokenAddr = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0;
	/* solhint-enable const-name-snakecase */

	/// @notice Sends LUSD amount from Smart Account to _LUSDTo account. Sends total balance if uint256.max is given as the amount.
	/* solhint-disable-next-line var-name-mixedcase */
	function sendLUSD(address _LUSDTo, uint256 _amount) internal {
		if (_amount == type(uint256).max) {
            _amount = getLUSDBalance(address(this));
        }
		// Do not transfer from Smart Account to itself, silently pass such case.
        if (_LUSDTo != address(this) && _amount != 0) {
			// LUSDToken.transfer reverts on recipient == adress(0) or == liquity contracts.
			// Overall either reverts or procedes returning true. Never returns false.
            ILUSDToken(LUSDTokenAddr).transfer(_LUSDTo, _amount);
		}
	}

	/// @notice Pulls LUSD amount from `_from` address to Smart Account. Pulls total balance if uint256.max is given as the amount.
	function pullLUSDFrom(address _from, uint256 _amount) internal {
		if (_amount == type(uint256).max) {
            _amount = getLUSDBalance(_from);
        }
		// Do not transfer from Smart Account to itself, silently pass such case.
		if (_from != address(this) && _amount != 0) {
			// function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
			// LUSDToken.transfer reverts on allowance issue, recipient == adress(0) or == liquity contracts.
			// Overall either reverts or procedes returning true. Never returns false.
			ILUSDToken(LUSDTokenAddr).transferFrom(_from, address(this), _amount);
		}
	}

	/// @notice Gets the LUSD balance of the account
	function getLUSDBalance(address _acc) internal view returns (uint256) {
		return ILUSDToken(LUSDTokenAddr).balanceOf(_acc);
	}


	/// @notice Open a new credit line using Liquity protocol by depositing ETH collateral and borrowing LUSD.
	/// @dev Value is amount of ETH to deposit into Liquity Trove
	/// @param _LUSDRequestedDebt Amount of LUSD caller wants to borrow and withdraw.
	/// @param _LUSDTo Address that will receive the generated LUSD.
	/// @param _upperHint For gas optimalisation. Referring to the prevId of the two adjacent nodes in the linked list that are (or would become) the neighbors of the given Liquity Trove.
	/// @param _lowerHint For gas optimalisation. Referring to the nextId of the two adjacent nodes in the linked list that are (or would become) the neighbors of the given Liquity Trove.
	/// @param _caller msg.sender in the gatekeeper
	/// @dev Hints explained: https://github.com/liquity/dev#supplying-hints-to-trove-operations
	/// @dev Hints should reflect calculated neededLUSDAmount instead of _LUSDRequestedDebt
	/* solhint-disable-next-line var-name-mixedcase */
	function openCreditLineLiquity(uint256 _LUSDRequestedDebt, address _LUSDTo, address _upperHint, address _lowerHint, address _caller) external payable onlyProxy {

		// Assertions and relevant reverts are done within Liquity protocol
		// Re-entrancy is avoided by calling the openTrove (cannot open the additional trove for the same smart account)
		
		Config config = Config(Registry(registry).getAddress(CONFIG_ID));

		uint256 mintedLUSD;
		uint256 neededLUSDAmount;
		uint256 expectedLiquityProtocolRate;

		{ // scope to avoid stack too deep errors
			uint16 acr = config.adoptionContributionRate();

			expectedLiquityProtocolRate = TroveManager.getBorrowingRateWithDecay();

			neededLUSDAmount = calcNeededLiquityLUSDAmount(_LUSDRequestedDebt, expectedLiquityProtocolRate, acr );

			uint256 previousLUSDBalance = getLUSDBalance(address(this));

			BorrowerOperations.openTrove{value: msg.value}(
				LIQUITY_PROTOCOL_MAX_BORROWING_FEE,
				neededLUSDAmount,
				_upperHint,
				_lowerHint
			);

			mintedLUSD = getLUSDBalance(address(this)) - previousLUSDBalance;
		}

		// Can send only what was minted
		// assert (_LUSDRequestedDebt <= mintedLUSD); // asserts in adoptionContributionLUSD calculation by avoiding underflow
		uint256 adoptionContributionLUSD = mintedLUSD - _LUSDRequestedDebt;

		CentralLogger logger = CentralLogger(Registry(registry).getAddress(CENTRAL_LOGGER_ID));
		logger.log(
			address(this), _caller, "openCreditLineLiquity",
			abi.encode(_LUSDRequestedDebt, _LUSDTo, _upperHint, _lowerHint, neededLUSDAmount, mintedLUSD, expectedLiquityProtocolRate)
		);

		// Send LUSD to the Adoption DAO
		sendLUSD(config.adoptionDAOAddress(), adoptionContributionLUSD);

		// Send LUSD to the requested address
		// Must be located at the end to avoid withdrawal by re-entrancy into potential LUSD withdrawal function
		sendLUSD(_LUSDTo, _LUSDRequestedDebt);
	}


	/// @notice Closes the Liquity trove
	/// @param _LUSDfrom Address where the LUSD is being pulled from to repay debt.
	/// @param _collateralTo Address that will receive the withdrawn collateral ETH.
	/// @param _caller msg.sender in the gatekeeper
	/// @dev Closinf trove pulls required LUSD and therefore requires approval on LUSD spending
	/// @dev TODO elaborate potential use of EIP 2612 permit, which LUSD implemented
	/* solhint-disable-next-line var-name-mixedcase */
	function closeCreditLineLiquity(address _LUSDfrom, address payable _collateralTo, address _caller) external onlyProxy {

		uint256 collateral = TroveManager.getTroveColl(address(this));

		// getTroveDebt returns composite debt including 200 LUSD gas compensation
		// Liquity Trove cannot have less than 2000 LUSD total composite debt
		// @dev Substraction is safe since solidity 0.8 reverts on underflow
		uint256 debtToRepay = TroveManager.getTroveDebt(address(this)) - LIQUITY_LUSD_GAS_COMPENSATION;

		// Liquity requires to have LUSD on the msg.sender, i.e. on Smart Account proxy
		// Pull LUSD from _from (typically EOA) to Smart Account proxy
		pullLUSDFrom(_LUSDfrom, debtToRepay);

		// Closing trove results in ETH to be stored on Smart Account proxy
		BorrowerOperations.closeTrove(); 

		CentralLogger logger = CentralLogger(Registry(registry).getAddress(CENTRAL_LOGGER_ID));
		logger.log(
			address(this), _caller, "closeCreditLineLiquity",
			abi.encode(_LUSDfrom, _collateralTo, debtToRepay, collateral)
		);

		// Must be last to avoid re-entrancy attack
		// In fact BorrowerOperations.closeTrove() fails on re-entrancy since Trove would be closed in re-entrancy
		// solhint-disable-next-line avoid-low-level-calls
		(bool success, ) = _collateralTo.call{ value: collateral }("");
		require(success, "Sending collateral ETH failed");

	}

	/// @notice Claims remaining collateral from the user's closed Liquity Trove due to a redemption or a liquidation with ICR > MCR in Recovery Mode
	/// @param _collateralTo Address that will receive the claimed collateral ETH.
	/// @param _caller msg.sender in the gatekeeper
	function claimRemainingCollateralLiquity(address payable _collateralTo, address _caller) external onlyProxy {
		
		uint256 remainingCollateral = CollSurplusPool.getCollateral(address(this));

		// Reverts if there is no collateral to claim 
		BorrowerOperations.claimCollateral();

		CentralLogger logger = CentralLogger(Registry(registry).getAddress(CENTRAL_LOGGER_ID));
		logger.log(
			address(this), _caller, "claimRemainingCollateralLiquity",
			abi.encode(_collateralTo, remainingCollateral)
		);

		// Send claimed ETH
		// Must be last to avoid re-entrancy attack
		// In fact BorrowerOperations.claimCollateral() reverts on re-entrancy since there will be no residual collateral to claim
		// solhint-disable-next-line avoid-low-level-calls
		(bool success, ) = _collateralTo.call{ value: remainingCollateral }("");
		require(success, "Sending of claimed collateral failed.");
	}

	/// @notice Allows to add ETH collateral to borrower's Credit line (Liquity Trove) and thus increase CR (decrease LTV ratio).
	/// @param _upperHint For gas optimalisation. Referring to the prevId of the two adjacent nodes in the linked list that are (or would become) the neighbors of the given Liquity Trove.
	/// @param _lowerHint For gas optimalisation. Referring to the nextId of the two adjacent nodes in the linked list that are (or would become) the neighbors of the given Liquity Trove.
	/// @dev Hints explained: https://github.com/liquity/dev#supplying-hints-to-trove-operations
	function addCollateralLiquity(address _upperHint, address _lowerHint) external payable onlyProxy {
		BorrowerOperations.addColl{value: msg.value}(_upperHint, _lowerHint);
	}



}