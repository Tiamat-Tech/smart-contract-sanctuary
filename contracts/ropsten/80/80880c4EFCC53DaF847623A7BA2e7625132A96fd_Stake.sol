// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;
import "./@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Ownable.sol";

contract Stake is Ownable {
    receive() external payable {}
    event UserDepositEvent(address indexed Stacker, uint indexed StackID);
    event UserWithdrawEvent(address indexed receiver, uint256 indexed amount, uint indexed stackPlanNumber);

    struct UserStackInfo {
        uint StackID;
        uint StackPlan;
        uint AvailableWithdrawTime;
        uint256 Amount;
    }

    struct StackPlan {
        address ERC20ContractAddress; //ERC20 token address
        uint StackTime;  // How long for this stacking
        uint APY; //Percent(need div 100)
    }

    uint public StackPlanCount;
    uint internal StackID;
    IERC20 private _token;

    address public GasFeePool;

    mapping(address => UserStackInfo[]) public mappingUserStacking ;
    mapping(uint => StackPlan)  public  mappingStackPlan;

    function addStackPlan(address ERC20 , uint StackTime, uint APY) public onlyOwner {
        require(ERC20 != address(0) && StackTime > 0, "Please input correct params.");
        mappingStackPlan[StackPlanCount].ERC20ContractAddress = ERC20;
        mappingStackPlan[StackPlanCount].StackTime = StackTime;
        mappingStackPlan[StackPlanCount].APY = APY;
        StackPlanCount+=1;
    }

    function deposit(uint stackPlanNumber, uint256 amount) public {
        _token = IERC20(mappingStackPlan[stackPlanNumber].ERC20ContractAddress);
        require(_token.transferFrom(msg.sender, address(this), amount) == true, "Fail to transfer");

        UserStackInfo memory UserStackInfoStructData;
        UserStackInfoStructData.StackID = StackID;
        UserStackInfoStructData.Amount = amount;
        UserStackInfoStructData.StackPlan = stackPlanNumber;
        UserStackInfoStructData.AvailableWithdrawTime = block.timestamp + mappingStackPlan[stackPlanNumber].StackTime;
        mappingUserStacking[msg.sender].push(UserStackInfoStructData);
        emit UserDepositEvent(msg.sender , StackID);
        StackID += 1;
    }

    function withdrawRequest(uint256 amount, uint stackPlanNumber) public payable {
        require(msg.value > 0, "You must pay the gas fee");
        address payable receiver = payable(GasFeePool);
        receiver.transfer(msg.value);
        emit UserWithdrawEvent(msg.sender, amount, stackPlanNumber);
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

    function setGasFeePool(address poolAddress) onlyOwner public {
        GasFeePool = poolAddress;
    }

    function withdraw(address receiver, uint256 amount, uint stackPlanNumber) public onlyOperators {
        _token = IERC20(mappingStackPlan[stackPlanNumber].ERC20ContractAddress);
        require(_token.transfer(receiver,amount) == true,"Fail to transfer");
    }



    //        function checkAvailableWithdraw(address receiver) public view returns(uint256) {
    //            uint256 AvailableWithdraw = 0;
    //            for(uint i = 0;i < mappingUserStacking[receiver].length; i++) {
    //                if (block.timestamp >= mappingUserStacking[receiver][i].WithdrawTime) {
    //                    avaliableWithdraw += mappingUserStacking[receiver][i].Amount;
    //                }
    //            }
    //            return AvailableWithdraw;
    //        }


}