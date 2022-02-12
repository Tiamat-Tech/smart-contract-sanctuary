// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.9;

import {CrispyStaker} from "../products/CrispyStaker.sol";
import {console} from "hardhat/console.sol";

/**
 * @author Dumonet Distributed Technologies
 */
contract TestCrispyStaker is CrispyStaker {
    event EmptyFunctionEvent();

    mapping(uint256 => uint256) public tokenIdToStakeId;
    mapping(uint256 => bool) public tokenIdAssigned;

    constructor(
        string memory _name,
        string memory _symbol,
        address _hexToken,
        uint256 _startMaxFee,
        uint256 _startCreateFee,
        uint256 _startRolloverFee,
        string memory _contractURI
    )
        CrispyStaker(
            _name,
            _symbol,
            _hexToken,
            _startMaxFee,
            _startCreateFee,
            _startRolloverFee,
            _contractURI
        )
    {}

    function depositFees(uint256 _feeAmount) external {
        _deposit(_feeAmount);
    }

    function emptyFunction() external {
        emit EmptyFunctionEvent();
    }

    function getDelta() external view returns (uint256) {
        return _getFreeBalance();
    }

    function checkCreateFeeEquals(uint256 _expectedCreateFee) external view {
        require(_expectedCreateFee == createFee, "TestCrSt: Unexpected fee");
    }

    function checkRolloverFeeEquals(uint256 _expectedRolloverFee) external view {
        require(_expectedRolloverFee == rolloverFee, "TestCrSt: Unexpected fee");
    }

    function _registerOpenStake(uint256 _tokenId, uint256 _stakeIndex) internal override {
        require(!tokenIdAssigned[_tokenId], "TCH: Token already assigned");
        require(
            _stakeIndex == hexToken().stakeCount(address(this)) - 1,
            "TCH: Invalid stake index"
        );
        tokenIdToStakeId[_tokenId] = _getStakeId(_stakeIndex);
        tokenIdAssigned[_tokenId] = true;
    }

    function _closeStakeCheck(
        uint256 _tokenId,
        uint256 _stakeIndex,
        uint256 _stakeId
    ) internal override {
        if (tokenIdToStakeId[_tokenId] != _stakeId) {
            console.log("_tokenId: ", _tokenId);
            console.log("_stakeId: ", _stakeId);
            revert("TCH: Stake misalignment");
        }
        require(tokenIdAssigned[_tokenId], "TCH: Token not assigned (I)");
        uint256 realStakeId = _getStakeId(_stakeIndex);
        require(realStakeId == _stakeId, "TCH: Invalid stake index");
        tokenIdAssigned[_tokenId] = false;
    }

    function _verifyStakeConnection(uint256 _tokenId, uint256 _stakeIndex) internal view override {
        require(tokenIdAssigned[_tokenId], "TCH: Token not assigned (II)");
        if (tokenIdToStakeId[_tokenId] != _getStakeId(_stakeIndex)) {
            console.log("_tokenId: ", _tokenId);
            console.log("_stakeIndex: ", _stakeIndex);
            console.log("tokenIdToStakeId[_tokenId]: ", tokenIdToStakeId[_tokenId]);
            console.log("_getStakeId(_stakeIndex): ", _getStakeId(_stakeIndex));
            revert("TCH: Wrong stake id");
        }
    }

    function _getStakeId(uint256 _stakeIndex) internal view returns (uint256) {
        (uint256 stakeId, , , , , , ) = hexToken().stakeLists(address(this), _stakeIndex);
        return stakeId;
    }
}