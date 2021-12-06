// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../utils/Forwarder.sol";
import "./ISeeder.sol";
import "./ERC20Seed.sol";

/* This is a barebones implementation only.
 * It should not be used yet in production.
 */
contract Seeder is Ownable, ISeeder {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address public seedAddress;
    address public collectionAddress;
    address public forwarderAddress;

    mapping(address => uint256) public seedPerFee;

    constructor(
        address _seed,
        address _collection,
        address _forwarder
    ) {
        seedAddress = _seed;
        collectionAddress = _collection;
        forwarderAddress = _forwarder;
    }

    function issueSeedsForErc20(
        address recipient,
        address feeToken,
        uint256 feeAmount
    ) external {
        uint256 price = seedPerFee[feeToken];

        if (price > 0) {
            uint256 seeds = price.mul(feeAmount);

            IERC20(feeToken).transferFrom(
                msg.sender,
                collectionAddress,
                feeAmount
            );

            ERC20Seed(seedAddress).mint(recipient, seeds);
        }
    }

    function issueSeedsForNative(
        address recipient,
        address feeToken,
        uint256 feeAmount
    ) external payable {
        require(msg.value >= feeAmount, "low amount of native token");

        uint256 price = seedPerFee[feeToken];

        if (price > 0) {
            uint256 seeds = price.mul(feeAmount);

            Forwarder(forwarderAddress).forward{value: feeAmount}(
                payable(collectionAddress)
            );

            ERC20Seed(seedAddress).mint(recipient, seeds);
        }
    }

    function setSeedPerFee(address[] calldata tokens, uint256[] calldata prices)
        external
        onlyOwner
    {
        require(tokens.length == prices.length, "Length mismatch");
        for (uint256 i = 0; i < tokens.length; i++) {
            seedPerFee[tokens[i]] = prices[i];
        }
    }

    function setCollectionAddress(address _address) external onlyOwner {
        collectionAddress = _address;
    }

    function tokenIssuable(address token) external view returns (bool) {
        return seedPerFee[token] > 0;
    }
}