// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "../withdrawable/Withdrawable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../utils/Forwarder.sol";
import "./ISeeder.sol";
import "./ERC20Seed.sol";

/**
 * @title Seeder
 * @notice The Seeder contract is used to issue SEEDs (an ERC20 token) in exchange for fees.
 */
contract Seeder is ISeeder, AccessControlEnumerable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    bytes32 public constant FEE_SETTER = keccak256("FEE_SETTER");

    address private constant NATIVE_TOKEN =
        0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public seedAddress;
    address public collectionAddress;

    mapping(address => uint256) public feePerSeed;

    event FeePerSeedChanged(address token, uint256 feePerSeed);

    constructor(address _seed, address _collection) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(FEE_SETTER, _msgSender());

        seedAddress = _seed;
        collectionAddress = _collection;
    }

    /**
     * @notice Issues SEEDs in exchange for fee collected through ERC20 tokens.
     *
     * @param recipient The recipient of SEEDs.
     * @param feeToken The ERC20 token address that is being exchanged.
     * @param feeAmount The amount of 'feeToken' for which to issue SEEDs.
     *
     * @dev This function only transfers tokens if there are SEEDs to be issued.
     */
    function issueSeedsForErc20(
        address recipient,
        address feeToken,
        uint256 feeAmount
    ) external {
        uint256 seeds = getSeedAmount(feeToken, feeAmount);

        if (seeds > 0) {
            IERC20(feeToken).safeTransferFrom(
                msg.sender,
                collectionAddress,
                feeAmount
            );

            ERC20Seed(seedAddress).mint(recipient, seeds);
        }
    }

    /**
     * @notice Issues SEEDs in exchange for fee collected through ERC20 tokens.
     *
     * @param recipients The recipients of SEEDs.
     * @param feeToken The ERC20 token address that is being exchanged.
     * @param feeAmounts The amounts of 'feeToken' for which to issue SEEDs (in order of 'recipients').
     *
     * @dev This function only transfers tokens if there are SEEDs to be issued. It returns the potential leftovers.
     */
    function issueSeedsForErc20Multiple(
        address[] calldata recipients,
        address feeToken,
        uint256[] calldata feeAmounts
    ) external {
        require(recipients.length == feeAmounts.length, "Length mismatch");

        if (!tokenIssuable(feeToken)) {
            return;
        }

        uint256 feeAmountTotal = 0;

        // Mint amounts
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 feeAmount = feeAmounts[i];
            uint256 seeds = getSeedAmount(feeToken, feeAmount);

            if (seeds > 0) {
                ERC20Seed(seedAddress).mint(recipients[i], seeds);
                feeAmountTotal += feeAmount;
            }
        }

        // Take only what was minted
        IERC20(feeToken).safeTransferFrom(
            msg.sender,
            collectionAddress,
            feeAmountTotal
        );
    }

    /**
     * @notice Issues SEEDs in exchange for ETH.
     *
     * @param recipient The recipient of SEEDs.
     *
     * @dev This function only transfers ETH if there are SEEDs to be issued.
     */
    function issueSeedsForNative(address recipient) external payable {
        uint256 seeds = getSeedAmount(NATIVE_TOKEN, msg.value);

        if (seeds > 0) {
            sendNative(collectionAddress, msg.value);
            ERC20Seed(seedAddress).mint(recipient, seeds);
        } else {
            sendNative(msg.sender, msg.value); // return to sender
        }
    }

    /**
     * @notice Issues SEEDs in exchange for ETH for multiple users.
     *
     * @param recipients The recipients of SEEDs.
     * @param feeAmounts The amounts of ETH.
     *
     * @dev This function only transfers ETH if there are SEEDs to be issued. It returns the potential leftovers.
     */
    function issueSeedsForNativeMultiple(
        address[] calldata recipients,
        uint256[] calldata feeAmounts
    ) external payable {
        require(recipients.length == feeAmounts.length, "Length mismatch");

        if (!tokenIssuable(NATIVE_TOKEN)) {
            return;
        }

        uint256 feeAmountTotal = 0;

        // Mint amounts
        for (uint256 i = 0; i < recipients.length; i++) {
            uint256 feeAmount = feeAmounts[i];
            uint256 seeds = getSeedAmount(NATIVE_TOKEN, feeAmount);

            if (seeds > 0) {
                ERC20Seed(seedAddress).mint(recipients[i], seeds);
                feeAmountTotal += feeAmount;
            }
        }

        sendNative(collectionAddress, feeAmountTotal);

        // Return leftovers to sender
        if (msg.value > feeAmountTotal) {
            sendNative(msg.sender, msg.value - feeAmountTotal);
        }
    }

    /**
     * @notice Returns the number of SEEDs that would be issued for a given token amount.
     *
     * @param token The ERC20 token address (use 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE for ETH).
     * @param amount The amount of 'token' for which to issue SEEDs.
     */
    function getSeedAmount(address token, uint256 amount)
        public
        view
        returns (uint256)
    {
        uint256 price = feePerSeed[token];

        if (price > 0) {
            return amount.mul(10**18).div(price);
        }

        return 0;
    }

    /**
     * Gets the role needed for setting fee for specified token.
     * @param token The ERC20 token address.
     */
    function tokenFeeSetterRole(address token) public pure returns (bytes32) {
        return bytes32(abi.encodePacked("FEE_SETTER", token));
    }

    /**
     * @notice Sets the fee for a given token. Use case: price oracles per specific token.
     *
     * @param token The ERC20 token address.
     * @param feeSetter The address of the account authorised to set fees for this token.
     */
    function setTokenFeeSetterRole(address token, address feeSetter)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(token != address(0), "token address cannot be 0");
        require(feeSetter != address(0), "fee setter address cannot be 0");

        _setupRole(tokenFeeSetterRole(token), feeSetter);
    }

    function removeTokenFeeSetterRole(address token, address feeSetter)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(token != address(0), "token address cannot be 0");
        require(feeSetter != address(0), "fee setter address cannot be 0");

        revokeRole(tokenFeeSetterRole(token), feeSetter);
    }

    /**
     * @notice Sets the amount of a given token that you must supply for 1 SEED.
     *
     * @param token The ERC20 token address.
     * @param price The fee in the token's base unit that would produce 1 SEED.
     *
     * @dev You need permission to set this fee for a token.
     */
    function setFeePerSeed(address token, uint256 price) public {
        require(
            hasRole(tokenFeeSetterRole(token), _msgSender()) ||
                hasRole(FEE_SETTER, _msgSender()),
            "Needs role for setting fee"
        );

        emit FeePerSeedChanged(token, price);
        feePerSeed[token] = price;
    }

    function setFeePerSeedMultiple(
        address[] calldata tokens,
        uint256[] calldata prices
    ) external {
        require(tokens.length == prices.length, "Length mismatch");

        for (uint256 i = 0; i < tokens.length; i++) {
            setFeePerSeed(tokens[i], prices[i]);
        }
    }

    function setCollectionAddress(address _address)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        collectionAddress = _address;
    }

    function tokenIssuable(address token) public view returns (bool) {
        return feePerSeed[token] > 0;
    }

    function sendNative(address _to, uint256 _amount) private {
        (bool sent, ) = payable(_to).call{value: _amount}(""); // solhint-disable-line avoid-low-level-calls
        require(sent, "Failed to send Ether");
    }

    // Utility functions to be able to recover any funds sent directly to the contract
    function emptyTokens(IERC20 _tokenAddress, address _to)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _tokenAddress.safeTransfer(_to, _tokenAddress.balanceOf(address(this)));
    }
}