//SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";

contract PNLStacking is Ownable {
    event Stacked(uint256 id, uint256 PNLamount, uint256 PNLgAmount, address User);

    struct StackEntry {
        uint256 PNLamount;
        uint256 stackedAt;
        uint256 StackingTypeID;
        bool withdrawn;
    }

    struct StackingType {
        uint256 duration;
        uint256 apy;
        uint256 bonusMultiplier;
    }

    StackingType[] public stackingTypes;

    mapping(address => uint256) private _stackesCount;
    mapping(uint256 => address) private _stackOwners;

    mapping(address => StackEntry[]) public stackingData;

    IERC20 public PNL;
    uint256 public stackedAmount;
    uint256 public paidAmount;

    uint256 public stackingID;

    uint256 internal _multiplierDivider = 10;
    uint256 internal _apyDivider = 1000;

    uint256 internal _minStackAmount = 1000 ether;

    constructor(address _pnlAddress) {
        stackingTypes.push(StackingType(91 days, 20, 10));
        stackingTypes.push(StackingType(182 days, 30, 15));
        stackingTypes.push(StackingType(365 days, 40, 20));
        stackingTypes.push(StackingType(730 days, 60, 30));

        PNL = IERC20(_pnlAddress);
    }

    function getStackingOptionInfo(uint256 id)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        StackingType memory stackingType = stackingTypes[id];
        return (stackingType.duration, stackingType.apy, stackingType.bonusMultiplier);
    }

    function calculateAPY(
        uint256 amount,
        uint256 apy,
        uint256 duration
    ) public view returns (uint256) {
        return (((amount * apy)) * duration) / _apyDivider / 365 days;
    }

    function stack(uint256 PNLAmount, uint256 StackingTypeID) external {
        require(StackingTypeID < stackingTypes.length, "Stacking type isnt found");
        require(PNLAmount >= _minStackAmount, "You cant stack that few tokens");
        (uint256 duration, , uint256 bonusMultiplier) = getStackingOptionInfo(StackingTypeID);
        uint256 PNLgAmount = ((((PNLAmount * duration) / 1 days)) * bonusMultiplier) / _multiplierDivider / 1 ether;
        PNL.transferFrom(msg.sender, address(this), PNLAmount);

        stackingID++;

        stackingData[msg.sender].push(StackEntry(PNLAmount, block.timestamp, StackingTypeID, false));
        _stackesCount[msg.sender] += 1;
        _stackOwners[stackingID] = msg.sender;
        stackedAmount += PNLAmount;

        emit Stacked(stackingID, PNLAmount, PNLgAmount, msg.sender);
    }

    function unstack(uint256 id) external {
        require(id < getStackesCount(msg.sender), "Stacking data isnt found");
        StackEntry storage stacking = stackingData[msg.sender][id];

        (uint256 duration, uint256 apy, ) = getStackingOptionInfo(stacking.StackingTypeID);

        require(!stacking.withdrawn, "Already withdrawn");
        require(block.timestamp > stacking.stackedAt + duration, "Too early to withdraw");

        stacking.withdrawn = true;
        uint256 withdrawAmnt = stacking.PNLamount + calculateAPY(stacking.PNLamount, apy, duration);

        PNL.transfer(msg.sender, withdrawAmnt);
        paidAmount += withdrawAmnt;
        stackedAmount -= stacking.PNLamount;
    }

    function getStackesCount(address user) public view returns (uint256) {
        return _stackesCount[user];
    }

    function getStackOwner(uint256 ID) public view returns (address) {
        return _stackOwners[ID];
    }

    function emergencyWithdrawn() external onlyOwner {
        PNL.transfer(msg.sender, PNL.balanceOf(address(this)));
    }

    function emergencyWithdrawnValue() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
}