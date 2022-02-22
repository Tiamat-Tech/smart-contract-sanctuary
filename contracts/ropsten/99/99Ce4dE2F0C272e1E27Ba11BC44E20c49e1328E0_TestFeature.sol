// SPDX-License-Identifier: Apache-2.0
/*

  Copyright 2020 ZeroEx Intl.

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

*/

pragma solidity 0.8.12;

import "../fixins/FixinCommon.sol";
import "../storage/LibTestStorage.sol";
import "../migrations/LibMigrate.sol";
import "./interfaces/IFeature.sol";
import "./interfaces/ITestFeature.sol";

/// @dev Owner management features.
contract TestFeature is IFeature, ITestFeature, FixinCommon {
    /// @dev Name of this feature.
    string public constant override FEATURE_NAME = "Test";
    /// @dev Version of this feature.
    uint256 public immutable override FEATURE_VERSION = _encodeVersion(1, 0, 1);

    /// @dev Initialize and register this feature.
    ///      Should be delegatecalled by `Migrate.migrate()`.
    /// @return success `LibMigrate.SUCCESS` on success.
    function migrate() external returns (bytes4 success) {
        _registerFeatureFunction(this.setHello.selector);
        _registerFeatureFunction(this.hello.selector);
        _registerFeatureFunction(this.lastSet.selector);
        return LibMigrate.MIGRATE_SUCCESS;
    }

    /// @dev Set your name in this contract.
    /// @param name_ Your name.
    function setHello(string calldata name_) external override {
        LibTestStorage.getStorage().name = name_;
        LibTestStorage.getStorage().lastSetTime = block.timestamp;
    }

    /// @dev Get hello from this contract.
    /// @return hey Greeting.
    function hello() external view override returns (string memory hey) {
        return string.concat("Hello ", LibTestStorage.getStorage().name);
    }

    /// @dev See when you changed your name for the last time.
    /// @return time Time in unix seconds.
    function lastSet() external view override returns (uint256 time) {
        return LibTestStorage.getStorage().lastSetTime;
    }
}