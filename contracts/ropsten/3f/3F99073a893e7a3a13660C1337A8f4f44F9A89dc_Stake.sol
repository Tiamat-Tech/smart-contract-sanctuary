// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Ownable.sol";

contract Stake is Ownable{
    event UserDepositEvent(address indexed Stacker, uint indexed StackID);
    event UserWithdrawEvent(address indexed receiver, uint256 indexed amount);

    struct UserStackInfo {
        uint StackID;
        address Stacker;
        uint StackPlan;
        uint AvailableWithdrawTime;
        uint256 Amount;
    }

    struct StackPlan {
        address ERC20ContractAddress; //ERC20 token address
        uint StackTime;  // How long for this stacking
    }

    uint public StackPlanCount;
    uint internal StackID;

    mapping(address => UserStackInfo[]) public mappingUserStacking ;
    mapping(uint => StackPlan)  public  mappingStackPlan;

    function addStackPlan(address ERC20 , uint StackTime) public onlyOwner {
        require(ERC20 != address(0) && StackTime > 0, "Please input correct params.");
        mappingStackPlan[StackPlanCount].ERC20ContractAddress = ERC20;
        mappingStackPlan[StackPlanCount].StackTime = StackTime;
        StackPlanCount+=1;
    }


    function deposit(uint stackPlanNumber, uint256 amount) public {
         address contractAddress = mappingStackPlan[stackPlanNumber].ERC20ContractAddress;
         IERC20 erc20 = IERC20(contractAddress);
         require(erc20.transferFrom(msg.sender, address(this), amount) == true, "Fail to transfer");

        UserStackInfo memory UserStackInfoStructData;
        UserStackInfoStructData.Stacker = msg.sender;
        UserStackInfoStructData.StackID = StackID;
        UserStackInfoStructData.Amount = amount;
        UserStackInfoStructData.StackPlan = stackPlanNumber;
        UserStackInfoStructData.AvailableWithdrawTime = block.timestamp + mappingStackPlan[stackPlanNumber].StackTime;
        mappingUserStacking[msg.sender].push(UserStackInfoStructData);
        emit UserDepositEvent(msg.sender , StackID);
        StackID += 1;
    }

    function withdraw(address receiver, uint256 amount,uint stackPlanNumber) public onlyOwner {
        IERC20 erc20 = IERC20(mappingStackPlan[stackPlanNumber].ERC20ContractAddress);
        erc20.transfer(receiver,amount);
        emit UserWithdrawEvent(receiver, amount);
    }

    function checkAllValidDeposit(address stacker) public view returns(UserStackInfo[] memory) {
        if (msg.sender != owner) {
            require(msg.sender == stacker, "Only can check yourself.");
        }
        UserStackInfo[] memory data = new UserStackInfo[](mappingUserStacking[stacker].length);
        for (uint i = 0; i < mappingUserStacking[stacker].length; i++) {
            UserStackInfo memory Temp = mappingUserStacking[stacker][i];
            data[i] = Temp;
        }
        return data;
    }

//    function checkAvailableWithdraw(address receiver) public view returns(uint256) {
//        uint256 AvailableWithdraw = 0;
//        for(uint i = 0;i < mappingUserStacking[receiver].length; i++) {
//            if (block.timestamp >= mappingUserStacking[receiver][i].WithdrawTime) {
//                avaliableWithdraw += mappingUserStacking[receiver][i].Amount;
//            }
//        }
//        return AvailableWithdraw;
//    }

}