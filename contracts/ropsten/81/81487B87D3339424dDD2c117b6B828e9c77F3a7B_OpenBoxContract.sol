// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "./UintArrayLib.sol";

contract OpenBoxContract is AccessControl {
    using UintArrayLib for uint256[];

    string public constant name = "PlanetSandbox Open Box";
    address public rewardAddress;
    address public rewardWallet;

    uint256[] private _rewards;

    event OpenBox(address userId, uint256 rewardId);
    event Test(address operator,
        address from,
        uint256 id,
        uint256 value);

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Error: Admin role required");
        _;
    }

    constructor(address _multiSigAccount) {
        renounceRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, _multiSigAccount);
    }

    function setRewardAddress(address _rewardAddress) external onlyAdmin {
        rewardAddress = _rewardAddress;
    }

    function setRewardWallet(address _wallet) external onlyAdmin {
        rewardWallet = _wallet;
    }

    function addRewards(uint256[] memory _rewardIds) external onlyAdmin {
        for (uint256 i = 0; i < _rewardIds.length; i++) {
            _rewards.push(_rewardIds[i]);
        }
    }

    function addRewards(uint256 _rewardIdStart, uint256 _rewardIdEnd) external onlyAdmin {
        for (uint256 rewardId = _rewardIdStart; rewardId <= _rewardIdEnd; rewardId++) {
            _rewards.push(rewardId);
        }
    }

    function removeRewards(uint256[] memory _rewardIds) external onlyAdmin {
        for (uint256 i = 0; i < _rewardIds.length; i++) {
            _rewards.remove(_rewardIds[i]);
        }
    }

    function getRewards() external view returns (uint256[] memory ids) {
        return _rewards;
    }

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        require(value == 1, "Error: amount must equal 1");

        emit Test(operator, from, id, value);

        if (operator == rewardAddress) {
            uint256 rewardIndex = uint256(blockhash(block.number + block.timestamp)) % _rewards.length;
            _rewards.shuffle();

            uint256 rewardId = _rewards[rewardIndex];

            IERC721(rewardAddress).transferFrom(rewardWallet, from, rewardId);

            _rewards.removeAt(rewardIndex);

            emit OpenBox(from, rewardId);
        }

        return bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"));
    }

    function withdrawERC20(address token) external onlyAdmin {
        require(IERC20(token).transfer(_msgSender(), IERC20(token).balanceOf(address(this))), "Transfer failed");
    }
}