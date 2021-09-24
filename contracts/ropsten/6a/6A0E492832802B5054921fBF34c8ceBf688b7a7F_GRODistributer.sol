// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IToken {
    function mint(address _receiver, uint256 _amount) external;

    function burn(address _receiver, uint256 _amount) external;
}

contract GRODistributer is Ownable {
    uint256 public immutable LBP_QUOTA;
    uint256 public immutable INVESTOR_QUOTA;
    uint256 public immutable TEAM_QUOTA;
    uint256 public immutable COMMUNITY_QUOTA;

    IToken public immutable govToken; // 0x44e9EDA64DA8f61C68c7322E8Ee3F14c73DbFb29
    mapping(address => bool) public vesters;
    mapping(address => uint256) public mintedAmount;

    constructor(
        address token,
        uint256 lbpQuota,
        uint256 communityQuota,
        uint256 investorQuota,
        uint256 teamQuota,
        address dao
    ) {
        govToken = IToken(token);
        LBP_QUOTA = lbpQuota;
        COMMUNITY_QUOTA = communityQuota;
        INVESTOR_QUOTA = investorQuota;
        TEAM_QUOTA = teamQuota;
        IToken(token).mint(dao, lbpQuota);
    }

    function setVester(address vester, bool status) external onlyOwner {
        vesters[vester] = status;
    }

    function mint(address account, uint256 amount) external {
        require(vesters[msg.sender], "mint: !caller");
        govToken.mint(account, amount);
        mintedAmount[msg.sender] = mintedAmount[msg.sender] + amount;
    }

    function burn(address account, uint256 amount) external {
        require(vesters[msg.sender], "mint: !caller");
        govToken.burn(account, amount);
        mintedAmount[msg.sender] = mintedAmount[msg.sender] - amount;
    }
}