// SPDX-License-Identifier: GPL-3.0
/*
 *     Copyright (C) 2021 TART K.K.
 *
 *     This program is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     This program is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see https://www.gnu.org/licenses/.
 */

pragma solidity =0.7.6;

import "@iroiro/merkle-distributor/contracts/MerkleDistributorManager.sol";
import "../interfaces/DistributorInterfaceV1.sol";

contract WalletDistributor is DistributorInterfaceV1, MerkleDistributorManager {
    constructor (string memory _distributorInfoCid)
    DistributorInterfaceV1(_distributorInfoCid) {}

    function createCampaign(
        bytes32 merkleRoot,
        address payable token,
        string calldata merkleTreeCid,
        string calldata campaignInfoCid,
        uint256 allowance
    ) external override {
        emit CreateCampaign(
            nextDistributionId,
            token,
            msg.sender,
            merkleTreeCid,
            campaignInfoCid
        );

        addDistribution(token, merkleRoot, allowance);
    }
}