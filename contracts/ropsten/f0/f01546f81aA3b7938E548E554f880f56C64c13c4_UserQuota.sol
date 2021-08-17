pragma solidity ^0.8.0;

import "../Ownable.sol";

interface IQuota {
    function getUserQuota(address user) external view returns (int256);
}

contract UserQuota is Ownable, IQuota {
    mapping(address => uint256) public userQuota;
    uint256 public quota = 100 * 10**6; //100u
    event SetQuota(address user, uint256 amount);

    function setUserQuota(address[] memory users, uint256[] memory quotas)
        external
        onlyOwner
    {
        require(users.length == quotas.length, "PARAMS_LENGTH_NOT_MATCH");
        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "USER_INVALID");
            userQuota[users[i]] = quotas[i];
            emit SetQuota(users[i], quotas[i]);
        }
    }

    function setUserQuota(address[] memory users) external onlyOwner {
        require(quota != 0, "QUOTA_IS_ZERO");
        for (uint256 i = 0; i < users.length; i++) {
            require(users[i] != address(0), "USER_INVALID");
            userQuota[users[i]] = quota;
            emit SetQuota(users[i], quota);
        }
    }

    function setQuota(uint256 _quota) external {
        require(_quota != 0, "QUOTA_IS_ZERO");
        quota = _quota;
    }

    function getUserQuota(address user)
        external
        view
        override
        returns (int256)
    {
        return int256(userQuota[user]);
    }
}