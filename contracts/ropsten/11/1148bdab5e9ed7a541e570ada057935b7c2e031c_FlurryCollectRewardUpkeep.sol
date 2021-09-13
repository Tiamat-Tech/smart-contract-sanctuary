//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "../interfaces/IFlurryUpkeep.sol";
import "../interfaces/IVault.sol";

contract FlurryCollectRewardUpkeep is OwnableUpgradeable, IFlurryUpkeep {
    IVault[] public vaults;
    mapping(address => bool) public vaultRegistered;

    function initialize() public initializer {
        OwnableUpgradeable.__Ownable_init();
    }

    function checkUpkeep(bytes calldata) external override returns (bool upkeepNeeded, bytes memory performData) {
        bool[] memory tempCollectList;

        upkeepNeeded = false;
        uint256 totalNumberOfStrategies = 0;

        for (uint256 i = 0; i < vaults.length; i++) {
            uint256 arrLength = vaults[i].getStrategiesListLength();
            totalNumberOfStrategies += arrLength;
        }

        //max size
        uint16[] memory data = new uint16[](totalNumberOfStrategies);
        uint16[] memory numberOfStrategiesToCollect = new uint16[](vaults.length);

        uint256 index = 0;
        for (uint256 i = 0; i < vaults.length; i++) {
            tempCollectList = vaults[i].checkStrategiesCollectReward();

            for (uint16 j = 0; j < tempCollectList.length; j++) {
                if (tempCollectList[j] == true) {
                    uint16[] memory teaser = new uint16[](1);
                    teaser[0] = j;
                    try vaults[i].collectStrategiesRewardTokenByIndex(teaser) returns (bool[] memory sold) {
                        if (!sold[0]) {
                            continue;
                        }
                        upkeepNeeded = true;
                        data[index] = j;
                        numberOfStrategiesToCollect[i]++;
                        index++;
                    } catch {
                        continue;
                    }
                }
            }
        }
        if (upkeepNeeded) {
            performData = abi.encode(data, numberOfStrategiesToCollect);
        }
    }

    function performUpkeep(bytes calldata performData) external override {
        (uint16[] memory arr, uint16[] memory numberOfStrategiesToCollect) =
            abi.decode(performData, (uint16[], uint16[]));
        uint256 parsedIndex = 0;
        for (uint256 i = 0; i < vaults.length; i++) {
            if (numberOfStrategiesToCollect[i] == 0) continue;
            uint16[] memory data = new uint16[](numberOfStrategiesToCollect[i]);
            for (uint256 j = parsedIndex; j < parsedIndex + numberOfStrategiesToCollect[i]; j++) {
                data[j - parsedIndex] = arr[j];
            }
            parsedIndex += numberOfStrategiesToCollect[i];
            vaults[i].collectStrategiesRewardTokenByIndex(data);
        }
    }

    function registerVault(address vaultAddr) external onlyOwner {
        require(vaultAddr != address(0), "Vault address is 0");
        require(!vaultRegistered[vaultAddr], "This vault is already registered.");
        vaults.push(IVault(vaultAddr));
        vaultRegistered[vaultAddr] = true;
    }
}