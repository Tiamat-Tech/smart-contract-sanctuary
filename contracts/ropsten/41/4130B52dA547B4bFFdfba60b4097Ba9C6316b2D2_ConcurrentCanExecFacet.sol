// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import {BFacetOwner} from "./base/BFacetOwner.sol";
import {LibConcurrentCanExec} from "../libraries/LibConcurrentCanExec.sol";

contract ConcurrentCanExecFacet is BFacetOwner {
    using LibConcurrentCanExec for address;

    function setSlotLength(uint256 _slotLength) external onlyOwner {
        LibConcurrentCanExec.setSlotLength(_slotLength);
    }

    function slotLength() public view returns (uint256) {
        return LibConcurrentCanExec.slotLength();
    }

    function concurrentCanExec(address _service, uint256 _buffer)
        public
        view
        returns (bool)
    {
        return _service.concurrentCanExec(_buffer);
    }

    function getCurrentExecutorIndex()
        public
        view
        returns (uint256 executorIndex, uint256 remainingBlocksInSlot)
    {
        return LibConcurrentCanExec.getCurrentExecutorIndex();
    }

    function currentExecutor()
        public
        view
        returns (
            address executor,
            uint256 executorIndex,
            uint256 remainingBlocksInSlot
        )
    {
        return LibConcurrentCanExec.currentExecutor();
    }

    function mySlotStatus(uint256 _buffer)
        public
        view
        returns (LibConcurrentCanExec.SlotStatus)
    {
        return LibConcurrentCanExec.mySlotStatus(_buffer);
    }

    function calcExecutorIndex(
        uint256 _currentBlock,
        uint256 _blocksPerSlot,
        uint256 _numberOfExecutors
    )
        public
        pure
        returns (uint256 executorIndex, uint256 remainingBlocksInSlot)
    {
        return
            LibConcurrentCanExec.calcExecutorIndex(
                _currentBlock,
                _blocksPerSlot,
                _numberOfExecutors
            );
    }
}