/**
 *Submitted for verification at Etherscan.io on 2022-01-17
*/

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

contract TodoList {
    uint public taskCount =0 ;
    // constructor() public {
    //     createTask("Check out dapp university.com");
    // }
    struct Task{
        uint id ;
        string content ;
        bool completed ;
    }
    mapping (uint => Task) public tasks;
    event TaskCreated(
        uint id ,
        string content ,
        bool completed
    );
    event TaskCompleted(
        uint id ,
        bool completed
    );
    function getTaskCount() external view returns(uint){
        return taskCount;
    }
    function createTask(string memory _content) public {
        taskCount ++;
        tasks[taskCount] = Task(taskCount , _content , false);
        emit TaskCreated(taskCount, _content, false);
    }
    function toggleCompleted(uint _id) public {
        Task memory _task = tasks[_id];
        _task.completed = !_task.completed;
        tasks[_id] = _task;
        emit TaskCompleted(_id, _task.completed);
    }
}