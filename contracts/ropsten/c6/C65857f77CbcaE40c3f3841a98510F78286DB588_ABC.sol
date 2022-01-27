//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
* @title ABC token
* @author Denis L.
* @notice This is ERC20 token with time contraints
* @dev All function calls are currently implemented without side effects
*/
contract ABC is ERC20, Ownable {

    // initial supply
    uint256 public constant INITIAL_SUPPLY = 1000000 ether;

    // maps address to last transfer time
    mapping(address => uint256) public lastTransferTime; //Track last transfer time per address

    constructor() ERC20("ABC", "ABC") {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /**
    * @notice Check if block timestamp has passed the time limit
    */
    modifier checkTime(address actor) {
        require(block.timestamp >= lastTransferTime[actor] + 5 minutes, "Cant transfer now");
        _;
    }

    /**
    * @notice Transfers $ABC to the recipient
    * @dev Override transfer function of Openzepplin ERC20 Token Standard with modifier 'checkTime'
    * @param to the recipient of the $ABC
    * @param amount the amount of $ABC to transfer
    */
    function transfer(address to, uint256 amount) public override checkTime(_msgSender()) returns (bool) {
        lastTransferTime[_msgSender()] = block.timestamp;
        return super.transfer(to, amount);
    }

    /**
    * @notice Transfers $ABC from the sender to the recipient
    * @dev Override transferFrom function of Openzepplin ERC20 Token Standard with modifier 'checkTime'
    * @param from the sender of the $ABC
    * @param to the recipient of the $ABC
    * @param amount the amount of $ABC to transfer
    */
    function transferFrom(address from, address to, uint256 amount) public override checkTime(from) returns (bool) {
        lastTransferTime[from] = block.timestamp;
        return super.transferFrom(from, to, amount);
    }

}