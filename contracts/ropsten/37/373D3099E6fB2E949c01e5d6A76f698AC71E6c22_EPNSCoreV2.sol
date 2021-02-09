pragma solidity >=0.6.0 <0.7.0;
pragma experimental ABIEncoderV2;

import "./EPNSCoreV1.sol";
import "hardhat/console.sol";
import "./VerzionedInitializable.sol";

contract EPNSCoreV2 is EPNSCoreV1, VersionedInitializable {
    function initializeUpgrade() external virtual initializerV {
        console.logAddress(daiAddress);
    }

    function getRevision() internal pure virtual override returns (uint256) {
        return 2;
    }
}