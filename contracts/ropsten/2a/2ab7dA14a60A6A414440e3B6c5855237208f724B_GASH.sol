// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IGASH.sol";

contract GASH is IGASH, ERC20, Ownable { //0x2ab7dA14a60A6A414440e3B6c5855237208f724B
    /** devs from Wnd clearly wanted to be protected from that kind of problems,
       so do we.
       Tracks the last block that a caller has written to state.
       Disallow some access to functions if they occur while a change is being written
     */
    mapping(address => uint256) private lastWrite;

    mapping(address => bool) private adminList;

    constructor() ERC20("GASH", "GASH") { }
    /**
    * creates an admin
    * @param admin - address of the admin
    */
    function createAdmin(address admin) external onlyOwner {
        adminList[admin] = true;
    }

    /**
     * disables an admin
     * @param admin - address of the admin
    */
    function deleteAdmin(address admin) external onlyOwner {
        adminList[admin] = false;
    }

    function mint(address to, uint256 amount) external override {
        require(adminList[msg.sender], "Only admins can mint");
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external override {
        require(adminList[msg.sender], "Only admins can burn");
        _burn(from, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override(ERC20, IGASH) disallowIfStateIsChanging returns (bool) {

        require(adminList[_msgSender()] || lastWrite[sender] < block.number , "hmmmm what doing?");
        // If the entity invoking this transfer is an admin (i.e. the gameContract)
        // allow the transfer without approval. This saves gas and a transaction.
        // The sender address will still need to actually have the amount being attempted to send.
        if(adminList[_msgSender()]) {
            // NOTE: This will omit any events from being written. This saves additional gas,
            // and the event emission is not a requirement by the EIP
            // (read this function summary / ERC20 summary for more details)
            _transfer(sender, recipient, amount);
            return true;
        }

        // If it's not an admin entity (game contract, tower, etc)
        // The entity will need to be given permission to transfer these funds
        // For instance, someone can't just make a contract and siphon $GP from every account
        return super.transferFrom(sender, recipient, amount);
    }

    /** SECURITEEEEEEEEEEEEEEEEE */

    modifier disallowIfStateIsChanging() {
        // frens can always call whenever they want :)
        require(adminList[_msgSender()] || lastWrite[tx.origin] < block.number, "hmmmm what doing?");
        _;
    }

    function updateOriginAccess() external override {
        require(adminList[_msgSender()], "Only admins can call this");
        lastWrite[tx.origin] = block.number;
    }

    function balanceOf(address account) public view virtual override disallowIfStateIsChanging returns (uint256) {
        // Y U checking on this address in the same block it's being modified... hmmmm
        require(adminList[_msgSender()] || lastWrite[account] < block.number, "hmmmm what doing?");
        return super.balanceOf(account);
    }

    function transfer(address recipient, uint256 amount) public virtual override disallowIfStateIsChanging returns (bool) {
        // NICE TRY MOUSE DRAGON
        require(adminList[_msgSender()] || lastWrite[_msgSender()] < block.number, "hmmmm what doing?");
        return super.transfer(recipient, amount);
    }

    // Not ensuring state changed in this block as it would needlessly increase gas
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return super.allowance(owner, spender);
    }

    // Not ensuring state changed in this block as it would needlessly increase gas
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        return super.approve(spender, amount);
    }

    // Not ensuring state changed in this block as it would needlessly increase gas
    function increaseAllowance(address spender, uint256 addedValue) public virtual override returns (bool) {
        return super.increaseAllowance(spender, addedValue);
    }

    // Not ensuring state changed in this block as it would needlessly increase gas
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual override returns (bool) {
        return super.decreaseAllowance(spender, subtractedValue);
    }

}