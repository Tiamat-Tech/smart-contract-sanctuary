// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
import "./@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Ownable.sol";

contract Stake is Ownable {
    receive() external payable {}
    event UserDepositEvent(address indexed Stakeer, uint indexed StakeID);
    event UserWithdrawEvent(address indexed receiver, uint256 indexed amount, uint[] stakePlanNumber);

    struct UserStakeInfo {
        uint StakeID;
        uint StakePlan;
        uint AvailableWithdrawTime;
        uint256 Amount;
    }

    struct StakePlan {
        address ERC20ContractAddress; //ERC20 token address
        uint StakeTime;  // How long for this stakeing
        uint APY; //Percent(need div 100)
    }

    uint public StakePlanCount;
    uint internal StakeID;
    IERC20 private _token;

    address public GasFeePool;

    mapping(address => UserStakeInfo[]) public mappingUserStaking ;
    mapping(uint => StakePlan)  public  mappingStakePlan;

    function addStakePlan(address ERC20 , uint StakeTime, uint APY) public onlyOwner {
        require(ERC20 != address(0) && StakeTime > 0, "Please input correct params.");
        mappingStakePlan[StakePlanCount].ERC20ContractAddress = ERC20;
        mappingStakePlan[StakePlanCount].StakeTime = StakeTime;
        mappingStakePlan[StakePlanCount].APY = APY;
        StakePlanCount+=1;
    }

    function deposit(uint stakePlanNumber, uint256 amount) public {
        _token = IERC20(mappingStakePlan[stakePlanNumber].ERC20ContractAddress);
        require(_token.transferFrom(msg.sender, address(this), amount) == true, "Fail to transfer");

        UserStakeInfo memory UserStakeInfoStructData;
        UserStakeInfoStructData.StakeID = StakeID;
        UserStakeInfoStructData.Amount = amount;
        UserStakeInfoStructData.StakePlan = stakePlanNumber;
        UserStakeInfoStructData.AvailableWithdrawTime = block.timestamp + mappingStakePlan[stakePlanNumber].StakeTime;
        mappingUserStaking[msg.sender].push(UserStakeInfoStructData);
        emit UserDepositEvent(msg.sender , StakeID);
        StakeID += 1;
    }

    function withdrawRequest(uint256 amount, uint[] memory stakePlanNumber) public payable {
        require(msg.value > 0, "You must pay the gas fee");
        address payable receiver = payable(GasFeePool);
        receiver.transfer(msg.value);
        emit UserWithdrawEvent(msg.sender, amount, stakePlanNumber);
    }


    function checkAllValidDeposit(address stakeUser) public view returns(UserStakeInfo[] memory) {
        UserStakeInfo[] memory data = new UserStakeInfo[](mappingUserStaking[stakeUser].length);
        for (uint i = 0; i < mappingUserStaking[stakeUser].length; i++) {
            UserStakeInfo memory Temp = mappingUserStaking[stakeUser][i];
            data[i] = Temp;
        }
        return data;
    }

    function checkDepositByStakeID(address stakeUser, uint StakeStakeID) public view returns(UserStakeInfo memory) {
        UserStakeInfo memory data;
        for (uint i = 0; i < mappingUserStaking[stakeUser].length; i++) {
            if (mappingUserStaking[stakeUser][i].StakeID == StakeStakeID) {
                data = mappingUserStaking[stakeUser][i];
                break;
            }
        }
        return data;
    }


    function setGasFeePool(address poolAddress) onlyOwner public {
        GasFeePool = poolAddress;
    }

    function withdraw(address receiver, uint256 amount, uint stakePlanNumber) public onlyOperators {
        _token = IERC20(mappingStakePlan[stakePlanNumber].ERC20ContractAddress);
        require(_token.transfer(receiver,amount) == true,"Fail to transfer");
    }



    //        function checkAvailableWithdraw(address receiver) public view returns(uint256) {
    //            uint256 AvailableWithdraw = 0;
    //            for(uint i = 0;i < mappingUserStakeing[receiver].length; i++) {
    //                if (block.timestamp >= mappingUserStakeing[receiver][i].WithdrawTime) {
    //                    avaliableWithdraw += mappingUserStakeing[receiver][i].Amount;
    //                }
    //            }
    //            return AvailableWithdraw;
    //        }


}