// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract UpgradeableTodoList is Initializable{
    string[] private _list;
    address public owner;
    // Emitted when the storeda new item is added to the list
    event ItemAdded(string item);
    event Received(address, string, uint256);

    function initialize() public initializer {
         _list.push("hello");
    }

    // Adds a new item in the list
    function addItem(string memory newItem) public {
        _list.push(newItem);
        emit ItemAdded(newItem);
    }
    // Gets the item from the list according to index    
    function getListItem(uint256 index) public view returns (string memory item) {
        return _list[index];
    }

    function getListSize() public view returns (uint256 size) {
        return _list.length;
    }

    function _setOwner(address owner_) public {
        owner = owner_;
    }

    receive() external payable {
        emit Received(msg.sender, "receive", msg.value);
    }

    function withdraw() external {
        uint amount = address(this).balance;
        address payable to = payable(msg.sender);
        (bool success,) = to.call{value: amount}("");
        require(success, "Failed to send Ether");
    }
    
    function withdrawTo(address user) external {
        uint amount = address(this).balance;
        bool success = payable(user).send(amount);
        require(success, "Failed to send Ether");
    }
}