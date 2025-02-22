// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;
import "../interfaces/IOracle.sol";

// Chainlink Aggregator

interface IAggregator {
    function latestAnswer() external view returns (int256 answer);
}

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

contract sSpellOracle is IOracle {
    IAggregator constant public SPELLUSD = IAggregator(0x8c110B94C5f1d347fAcF5E1E938AB2db60E3c9a8);

    IERC20 public constant SSPELL = IERC20(0x26FA3fFFB6EfE8c1E69103aCb4044C26B9A106a9);
    IERC20 public constant SPELL = IERC20(0x090185f2135308BaD17527004364eBcC2D37e5F6);

    function toSSpell(uint256 amount) internal view returns (uint256) {
        return amount * SPELL.balanceOf(address(SSPELL)) / SSPELL.totalSupply();
    }

    // Calculates the lastest exchange rate
    // Uses both divide and multiply only for tokens not supported directly by Chainlink, for example MKR/USD
    function _get() internal view returns (uint256) {

        return 1e26 / toSSpell(uint256(SPELLUSD.latestAnswer()));
    }

    // Get the latest exchange rate
    /// @inheritdoc IOracle
    function get(bytes calldata) public view override returns (bool, uint256) {
        return (true, _get());
    }

    // Check the last exchange rate without any state changes
    /// @inheritdoc IOracle
    function peek(bytes calldata) public view override returns (bool, uint256) {
        return (true, _get());
    }

    // Check the current spot exchange rate without any state changes
    /// @inheritdoc IOracle
    function peekSpot(bytes calldata data) external view override returns (uint256 rate) {
        (, rate) = peek(data);
    }

    /// @inheritdoc IOracle
    function name(bytes calldata) public pure override returns (string memory) {
        return "Chainlink sSpell";
    }

    /// @inheritdoc IOracle
    function symbol(bytes calldata) public pure override returns (string memory) {
        return "LINK/sSpell";
    }
}