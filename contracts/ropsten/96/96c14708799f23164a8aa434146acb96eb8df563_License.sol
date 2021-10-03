// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC1155/ERC1155.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import './Factory.sol';

// @author Julian Peters
// @title License
contract License is Ownable, ERC1155, ReentrancyGuard {
    uint256 constant totalSupply = 1000000000000000000; // 10^18

    address public immutable factory;
    address public creator;
    address public USDC;

    bytes32 public ipfsHash;
    mapping(uint256 => bool) public licenseTypeExists;
    mapping(uint256 => uint256) public licenseTypeToPrice;
    mapping(uint256 => uint256) public licenseTypeToLimitRemaining; // @dev Introduces scarcity. 0 means no limit, 1 means none remaining
    bytes32[] public pastIpfsHashes;
    uint256[] public changedInBlock;

    uint256 private usdcBalance = 0;

    uint256[] public blocksWithEarnings;
    mapping(uint256 => uint256) public earnedFees; // maps block number to fees
    mapping(address => uint256) public lastClaimBlock;

    event LicenseMint(
        bytes32 ipfsHash,
        uint256 licenseType,
        uint256 licensePrice
    );

    // @dev Ideally, this should link directly to the ipfs:// protocol for full decentralization, but currently this doesn't work great with the ERC1155 standard and converting the IPFS hash from bytes32 to a valid IPFS string is tricky 
    constructor()
        ERC1155('https://licensing-protocol.vercel.app/api/license/{id}')
    {
        factory = msg.sender;
    }

    // @dev Enable a new standard license type (as defined in Factory) for licensing
    // @param _licenseType The type of license to enable
    // @param _licensePrice The price of the license in USDC
    // @param _licenseSupply The total number of licenses of this type that can be issued
    function addAvailableLicenseType(
        uint256 _licenseType,
        uint256 _licensePrice,
        uint256 _licenseSupply
    ) public onlyOwner {
        require(_licenseType != 0, 'INVALID LICENSE TYPE');
        require(
            licenseTypeExists[_licenseType] == false,
            'LICENSE TYPE ALREADY EXISTS'
        );
        // @dev uint can never be negative, so no separate check necessary. Free licenses are possible.

        // @dev: Get valid license types from factory
        uint256 licenseCount = Factory(factory).availableLicenseTypesLength();

        require(_licenseType <= licenseCount, 'INVALID LICENSE TYPE');

        licenseTypeExists[_licenseType] = true;
        licenseTypeToPrice[_licenseType] = _licensePrice;
        if (_licenseSupply > 0)
            licenseTypeToLimitRemaining[_licenseType] = _licenseSupply + 1;
    }

    function _setIpfsHash(bytes32 _ipfsHash) private {
        // @dev Require valid hash (not empty string)
        require(_ipfsHash[0] != 0, 'HASH CANNOT BE NULL');
        ipfsHash = _ipfsHash;
    }

    // @dev Called by Factory at time of deployment
    function initialize(
        bytes32 _ipfsHash,
        uint256[] calldata _licenseTypes,
        uint256[] calldata _licensePrices,
        uint256[] calldata _licenseSupply,
        address sender,
        address _USDC
    ) external {
        // @dev Prevent re-initialization (only factory contract can call this function, it does not have a function to re-initialize/re-create the same license)
        require(msg.sender == factory, 'FORBIDDEN');

        USDC = _USDC;

        // @dev: Make sure that every license has a price and supply
        require(
            _licenseTypes.length == _licensePrices.length &&
                _licenseTypes.length == _licenseSupply.length,
            'LENGTH MISMATCH'
        );

        for (uint256 i = 0; i < _licenseTypes.length; i++) {
            addAvailableLicenseType(
                _licenseTypes[i],
                _licensePrices[i],
                _licenseSupply[i]
            );
        }
        _setIpfsHash(_ipfsHash);

        // @dev Mint to sender. Mints 1 token with 18 decimals. After inital mint, token can not be minted anymore (supply is fixed)
        _mint(sender, 0, totalSupply, '');
        // @dev Transfer ownership to sender. Would be better to initialize sender as owner, but this is not yet possible https://github.com/OpenZeppelin/openzeppelin-contracts/issues/2639
        transferOwnership(sender);
        // @dev Store original creator! => Owner can be changed through functions that come with Ownable
        creator = sender;
    }

    function editIpfsHash(bytes32 _ipfsHash) external onlyOwner {
        _setIpfsHash(_ipfsHash);
        // @dev Remember old hash and block number where change occured
        pastIpfsHashes.push(ipfsHash);
        changedInBlock.push(block.number);
    }

    // @dev This function should not be called directly, but from a contract after transfering the necessary funds
    // @param buyer Address of the contract caller passed by Market. Does not use tx.origin to follow best practice avoiding vulnerabilities.
    // @param licenseType Type of license to buy
    // @param referrerWallet Wallet that receives the referrer commission (usually the frontend). Set to 0x0 for none.
    function buyLicense(
        address buyer,
        uint256 licenseType,
        address referrerWallet
    ) external {
        require(licenseTypeExists[licenseType] == true, 'INVALID LICENSE TYPE');
        require(
            licenseTypeToLimitRemaining[licenseType] != 1,
            'MINT LIMIT EXCEEDED'
        );
        uint256 cost = licenseTypeToPrice[licenseType];

        // @dev Get current USDC balance and compare with previously stored balance to verify that cost has been paid
        uint256 newUsdcBalance = IERC20(USDC).balanceOf(address(this));
        require(
            newUsdcBalance - cost >= usdcBalance,
            'INSUFFICIENT PAYMENT SENT'
        );

        // @dev Transfer fees to treasury and referrer
        if (cost > 0) {
            uint8 treasuryFee = Factory(factory).treasuryFee();
            address treasuryWallet = Factory(factory).treasuryWallet();
            uint256 treasuryReward = 0;
            if (treasuryFee > 0) {
                treasuryReward = (cost * uint256(treasuryFee)) / 100;
                TransferHelper.safeTransfer(
                    USDC,
                    treasuryWallet,
                    treasuryReward
                );
            }

            uint256 referrerFee = uint256(Factory(factory).referrerFee());
            uint256 referrerReward = 0;
            if (referrerWallet != address(0) && referrerFee > 0) {
                referrerReward = (cost * referrerFee) / 100;
                TransferHelper.safeTransfer(
                    USDC,
                    referrerWallet,
                    referrerReward
                );
            }

            earnedFees[block.number] += cost - treasuryReward - referrerReward;
            blocksWithEarnings.push(block.number);
        }

        // @dev Issue 1 token with license type as id
        _mint(buyer, licenseType, 1, '');

        // @dev If supply is limited: Decrease by 1
        if (licenseTypeToLimitRemaining[licenseType] > 0)
            licenseTypeToLimitRemaining[licenseType] -= 1;

        emit LicenseMint(ipfsHash, licenseType, cost);

        // @dev Update balance
        usdcBalance = IERC20(USDC).balanceOf(address(this));
    }

    // @dev Check if address has claimable license fees
    // @param address The address to check for claimable license fees
    // @return Claimable USDC amount
    function _claimable(address user)
        private
        view
        returns (uint256 totalClaimable)
    {
        // @dev Require token 0 balance
        uint256 balance = balanceOf(user, 0);
        require(balance > 0, 'NO RIGHT TO CLAIM');
        uint256 totalFeesEarnedInTimespan = 0;
        for (uint256 i = 0; i < blocksWithEarnings.length; i++) {
            if (
                blocksWithEarnings[i] > lastClaimBlock[user] &&
                blocksWithEarnings[i] < block.number
            ) {
                // @dev Using the current block -1 prevents that a license is bought in the same block as the claim transaction after the claim transaction, in which case the claimer would not get a share of the license fees
                totalFeesEarnedInTimespan += earnedFees[blocksWithEarnings[i]];
            }
        }

        uint256 balanceShare = (totalSupply / balance);

        totalClaimable = (totalFeesEarnedInTimespan / balanceShare);

        return totalClaimable;
    }

    function claimable() public view returns (uint256 totalClaimable) {
        return _claimable(msg.sender);
    }

    // @dev Send claimable license fees to address and record the claim
    // @param address The address to claim for
    function _claim(address user) private nonReentrant {
        uint256 claimableUsdc = _claimable(user);
        require(claimableUsdc > 0, 'NO FEES TO CLAIM');
        // @dev Transfer USDC to user
        TransferHelper.safeTransfer(USDC, user, claimableUsdc);
        // @dev Update USDC balance
        usdcBalance = IERC20(USDC).balanceOf(address(this));
        // @dev Update last claim block
        lastClaimBlock[user] = block.number - 1;
    }

    function claim() external {
        _claim(msg.sender);
    }

    // @dev Modify ERC1155 transfer function to execute _claim() on every transfer for the sender as well as the recipient for token 0 transfers => prevents that a user can claim rewards multiple times by claiming, then transferring the owner token to another wallet and then claiming again
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        for (uint256 i = 0; i < ids.length; i++) {
            if (ids[i] == 0) {
                if (blocksWithEarnings.length > 0) {
                    uint256 senderClaimableBalance = _claimable(from);
                    if (senderClaimableBalance > 0) _claim(from);
                    if (balanceOf(to, 0) > 0) {
                        uint256 recipientClaimableBalance = _claimable(to);
                        if (recipientClaimableBalance > 0) _claim(to);
                    } else lastClaimBlock[to] = block.number - 1;
                }
            }
        }
    }
}