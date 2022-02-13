// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// Librarires
import "./libraries/SharedStructs.sol";

// @openzeppelin/contracts-upgradeable
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

// @openzeppelin/contracts
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

contract PartyFactory is UUPSUpgradeable, OwnableUpgradeable {
    address private partyBeacon;

    // Set Platform Collector
    address private PLATFORM_ADDRESS;
    uint256 private PLATFORM_FEE;

    // Store created parties
    address[] public parties;

    // Events
    event PartyCreated(address partyAddress);

    /**
     * @dev Initialize the PartyFactory
     * @param _implementation Party implementation address
     * @param _platform Platform address
     * @param _fee Platform fee in bps
     */
    function initialize(address _implementation, address _platform, uint256 _fee) external initializer {
        __UUPSUpgradeable_init();
        __Ownable_init();
        setPlatformAddress(_platform);
        setPlatformFee(_fee);
        UpgradeableBeacon _partyBeacon = new UpgradeableBeacon(
            _implementation
        );
        partyBeacon = address(_partyBeacon);
    }

    /**
     * @dev Get platform address
     * Retrieves the current platform address
     */
    function getPlatformAddress() external view returns (address) {
        return PLATFORM_ADDRESS;
    }

    /**
     * @dev Set platform address
     * Lets the PartyFactory owner to change the Platform address
     */
    function setPlatformAddress(address _platform) public onlyOwner {
        PLATFORM_ADDRESS = _platform;
    }

    /**
     * @dev Get platform fee
     */
    function getPlatformFee() external view returns (uint256) {
        return PLATFORM_FEE;
    }

    /**
     * @dev Set platform fee
     * Lets the PartyFactory owner to change the Platform fee
     */
    function setPlatformFee(uint256 _fee) public onlyOwner {
        PLATFORM_FEE = _fee;
    }

    /**
     * @dev Get PartyBeacon
     */
    function getPartyBeacon() external view returns (address) {
        return address(partyBeacon);
    }

    /**
     * @dev Get PartyBeacon
     */
    function upgradePartyBeacon(address _implementation) external onlyOwner {
        UpgradeableBeacon(partyBeacon).upgradeTo(_implementation);
    }

    /**
     * @dev Create Party
     * Deploys a new Party Contract
     */
    function createParty(
        SharedStructs.PartyInfo memory partyInfo,
        uint256 initialDeposit,
        address dAsset,
        uint256 dAssetDecimals
    ) external payable returns (address) {
        // Deploy the party
        BeaconProxy party = new BeaconProxy(
            partyBeacon,
            abi.encodeWithSignature(
                "initialize(address,(string,string,string,string,string,bool,uint256,uint256),uint256,address,uint256,address,uint256)",
                msg.sender,
                partyInfo,
                initialDeposit,
                dAsset,
                dAssetDecimals,
                PLATFORM_ADDRESS,
                PLATFORM_FEE
            )
        );

        // Collect fees and transfer funds to party
        uint256 fee = (initialDeposit * PLATFORM_FEE) / 10000;
        IERC20Upgradeable(dAsset).transferFrom(
            msg.sender,
            address(this),
            initialDeposit + fee
        );
        IERC20Upgradeable(dAsset).transfer(PLATFORM_ADDRESS, fee);
        IERC20Upgradeable(dAsset).transfer(address(party), initialDeposit);

        // Add created Party to PartyFactory
        parties.push(address(party));

        // Emit party creation event;
        emit PartyCreated(address(party));

        // Return new party address
        return address(party);
    }

    /**
     * @dev Get Parties
     * Returns the deployed Party contracts by the Factory
     */
    function getParties() external view returns (address[] memory) {
        return parties;
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}