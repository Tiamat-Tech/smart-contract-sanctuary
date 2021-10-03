// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import '@openzeppelin/contracts/utils/Create2.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './License.sol';
import './interfaces/ILicense.sol';

// @author Julian Peters
// @title Factory
contract Factory is Ownable {
    event LicenseCreated(
        bytes32 ipfsHash,
        uint256[] licenseTypes,
        uint256[] licensePrices,
        uint256[] licenseSupply,
        address licenseContract,
        address creator
    );

    uint8 public treasuryFee = 10;
    uint8 public referrerFee = 10;

    address public treasuryWallet;
    address public immutable USDC;

    // @param _USDC Address of the USDC contract
    constructor(address _USDC) {
        treasuryWallet = msg.sender;
        USDC = _USDC;
    }

    bytes32[] public availableLicenseTypes;

    address[] public allLicenses;
    mapping(address => uint256) public licensePosition;

    function availableLicenseTypesLength() external view returns (uint256) {
        return availableLicenseTypes.length;
    }

    function allLicensesLength() external view returns (uint256) {
        return allLicenses.length;
    }

    // @dev Create new Licene.sol smart contract
    // @param ipfsHash - IPFS hash of the content to license
    // @param licenseTypes - array of available license types
    // @param licensePrices - array of license prices in USDC for each license type
    // @param licenseSupply - array of max. available amount of each license type
    // @return Address of the created license contract
    function createLicense(
        bytes32 ipfsHash,
        uint256[] calldata licenseTypes,
        uint256[] calldata licensePrices,
        uint256[] calldata licenseSupply
    ) external returns (address licenseContract) {
        // @dev Deterministic address
        bytes memory bytecode = type(License).creationCode;
        licenseContract = Create2.deploy(0, ipfsHash, bytecode);
        // @dev Require that license with identical ipfsHash does not exist yet
        require(licensePosition[licenseContract] == 0, 'LICENSE EXISTS');
        ILicense(licenseContract).initialize(
            ipfsHash,
            licenseTypes,
            licensePrices,
            licenseSupply,
            msg.sender,
            USDC
        );
        // @dev Save license contract address
        allLicenses.push(licenseContract);
        licensePosition[licenseContract] = allLicenses.length;
        emit LicenseCreated(
            ipfsHash,
            licenseTypes,
            licensePrices,
            licenseSupply,
            licenseContract,
            msg.sender
        );
        return licenseContract;
    }

    function setTreasuryFee(uint8 _treasuryFee) external onlyOwner {
        // @notice Fee can be set to a max. of 15
        require(_treasuryFee <= 15, 'FEE CANNOT BE HIGHER THAN 15');
        treasuryFee = _treasuryFee;
    }

    function setReferrerFee(uint8 _referrerFee) external onlyOwner {
        // @notice Fee can be set to a max. of 15
        require(_referrerFee <= 15, 'FEE CANNOT BE HIGHER THAN 15');
        referrerFee = _referrerFee;
    }

    function setTreasuryWallet(address _treasuryWallet) external onlyOwner {
        treasuryWallet = _treasuryWallet;
    }

    // @param ipfsHash IPFS hash with the content of the standard license to add
    function addLicenseType(bytes32 ipfsHash) external onlyOwner {
        availableLicenseTypes.push(ipfsHash);
    }
}