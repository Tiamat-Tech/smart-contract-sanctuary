// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// mock class using ERC20
contract RBT is ERC20, Ownable {
    using SafeMath for uint256;
    using SafeMath for uint;

    uint256 privInvReleaseRate;
    uint256 teamReleaseRate;
    uint256 privInvTotal;
    uint256 teamInvTotal;
    uint256 currentPrivPer;
    uint256 currentTeamPer;

    uint256 intervalDays = 30 days;

    struct UserInfo {
        uint256 total;
        uint256 used;
        bool existed;
    }

    mapping(address => UserInfo) privs;
    mapping(address => UserInfo) teams;
    uint256 created;

    constructor (
        string memory name,
        string memory symbol,
        uint8 decimals,        
        uint256 initialBalance,
        uint256 privInvPercent_,
        uint256 privInvReleaseRate_,
        uint256 teamPercent_,
        uint256 teamReleaseRate_
    ) public payable ERC20(name, symbol) {
        _setupDecimals(decimals);
        privInvReleaseRate = privInvReleaseRate_;
        teamReleaseRate = teamReleaseRate_;

        created = now;
        uint256 privInv_ = initialBalance.mul(privInvPercent_).div(100);
        uint256 teamInv_ = initialBalance.mul(teamPercent_).div(100);
        privInvTotal = privInv_;
        teamInvTotal = teamInv_;

        _mint(address(this), privInv_.add(teamInv_));
        uint256 leftBalance_ = initialBalance.sub(privInv_).sub(teamInv_);
        _mint(msg.sender, leftBalance_);
    }

    // for dev
    // function setInterval(uint256 inter) public onlyOwner {
    //     intervalDays = inter;
    // }

    function addPrivInvs(address[] memory privs_, uint256[] memory amountsPer_) public onlyOwner {
        require(privs_.length == amountsPer_.length, "pirv invest count mismatch");
        for (uint i; i < privs_.length; i++) {
            addPrivInv(privs_[i], amountsPer_[i]);
        }
    }

    function addPrivInv(address priv, uint256 amountPer_) public onlyOwner {
        require(currentPrivPer.add(amountPer_) <= 100, "exceed investment allowance" );
        UserInfo storage ui = privs[priv];
        if (!ui.existed){
            ui.existed = true;
        }
        uint256 amount = amountPer_.mul(privInvTotal).div(100);
        ui.total = ui.total.add(amount);
        currentPrivPer = currentPrivPer.add(amountPer_);
        // withdraw first step now;
        withdrawInPriv(priv);
    }


    function addTeamInvs(address[] memory teams_, uint256[] memory amountsPer_) public onlyOwner {
        require(teams_.length == amountsPer_.length, "pirv invest count mismatch");
        for (uint i; i < teams_.length; i++) {
            addTeamInv(teams_[i], amountsPer_[i]);
        }
    }

    function addTeamInv(address team, uint256 amountPer_) public onlyOwner {
        require(currentTeamPer.add(amountPer_) <= 100, "exceed investment allowance" );
        UserInfo storage ui = teams[team];
        if (!ui.existed){
            ui.existed = true;
        }
        uint256 amount = amountPer_.mul(teamInvTotal).div(100);
        ui.total = ui.total.add(amount);
        currentTeamPer = currentTeamPer.add(amountPer_);
        // withdraw first step now;
        withdrawInTeam(team);
    }

    function withdrawInPriv(address pri) public {
        UserInfo storage ui = privs[pri];
        require(ui.existed, "not in private investment");
        
        uint256 interval = (now.sub(created)).div(30 days) + 1;
        uint256 ava = ui.total.mul(privInvReleaseRate).mul(interval).div(100);
        uint256 left = ava.sub(ui.used);
        require(left > 0, "have no rbt staked");
        transfer(pri, left);
    }

    function withdrawInTeam(address team) public {
        UserInfo storage ui = teams[team];
        require(ui.existed, "not in team investment");
        
        uint256 interval = (now.sub(created)).div(intervalDays) + 1;
        uint256 ava = ui.total.mul(teamReleaseRate).mul(interval).div(100);
        uint256 left = ava.sub(ui.used);
        require(left > 0, "have no rbt staked");
        transfer(team, left);
    }
}