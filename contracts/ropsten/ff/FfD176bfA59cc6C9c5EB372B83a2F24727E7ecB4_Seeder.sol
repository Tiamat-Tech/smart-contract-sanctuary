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

    mapping(address => uint256) public feePerSeed;

    constructor(address _seed, address _collection) {
        seedAddress = _seed;
        collectionAddress = _collection;
    }

    function issueSeedsForErc20(
        address recipient,
        address feeToken,
        uint256 feeAmount
    ) external {
        uint256 seeds = getSeedAmount(feeToken, feeAmount);

        if (seeds > 0) {
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
        require(msg.value == feeAmount, "low amount of native token");

        uint256 seeds = getSeedAmount(feeToken, feeAmount);

        if (seeds > 0) {
            (bool sent, ) = payable(collectionAddress).call{value: msg.value}( // solhint-disable-line avoid-low-level-calls
                ""
            );
            require(sent, "Failed to send Ether");

            ERC20Seed(seedAddress).mint(recipient, seeds);
        }
    }

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

    function setFeePerSeed(address[] calldata tokens, uint256[] calldata prices)
        external
        onlyOwner
    {
        require(tokens.length == prices.length, "Length mismatch");
        for (uint256 i = 0; i < tokens.length; i++) {
            feePerSeed[tokens[i]] = prices[i];
        }
    }

    function setCollectionAddress(address _address) external onlyOwner {
        collectionAddress = _address;
    }

    function tokenIssuable(address token) external view returns (bool) {
        return feePerSeed[token] > 0;
    }
}