pragma solidity 0.7.5;
// solhint-disable-next-line compiler-version
pragma abicoder v2;

import "./BasicNFTBridge.sol";
import "./modules/gas_limit/SelectorTokenGasLimitConnector.sol";

/**
 * @title HomeNFTBridge
 * @dev Home side implementation for multi-token ERC721 mediator intended to work on top of AMB bridge.
 * It is designed to be used as an implementation contract of EternalStorageProxy contract.
 */
contract HomeNFTBridge is BasicNFTBridge, SelectorTokenGasLimitConnector {
    constructor(string memory _suffix) BasicNFTBridge(_suffix) {}

    /**
     * @dev Stores the initial parameters of the mediator.
     * @param _bridgeContract the address of the AMB bridge contract.
     * @param _mediatorContract the address of the mediator contract on the other network.
     * @param _gasLimitManager the gas limit manager contract address.
     * @param _owner address of the owner of the mediator contract.
     */
    function initialize(
        address _bridgeContract,
        address _mediatorContract,
        address _gasLimitManager,
        address _owner
    ) external onlyRelevantSender initializer {
        _setBridgeContract(_bridgeContract);
        _setMediatorContractOnOtherSide(_mediatorContract);
        _setGasLimitManager(_gasLimitManager);
        _setOwner(_owner);
    }

    /**
     * @dev Internal function for sending an AMB message to the mediator on the other side.
     * @param _data data to be sent to the other side of the bridge.
     * @param _useOracleLane true, if the message should be sent to the oracle driven lane.
     * @return id of the sent message.
     */
    function _passMessage(bytes memory _data, bool _useOracleLane) internal override returns (bytes32) {
        address executor = mediatorContractOnOtherSide();
        uint256 gasLimit = _chooseRequestGasLimit(_data);
        IAMB bridge = bridgeContract();

        return
        _useOracleLane
        ? bridge.requireToPassMessage(executor, _data, gasLimit)
        : bridge.requireToConfirmMessage(executor, _data, gasLimit);
    }


    function isHomeBridge() public override view returns (bool){
        return true;
    }
}