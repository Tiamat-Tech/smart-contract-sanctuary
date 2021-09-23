//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract FrozenSTARX {
    using SafeERC20 for IERC20;

    // ERC20 basic token contract being held
    IERC20 private _token;

    // contract owner address
    address private _owner;

    struct Frozen {
        address beneficiary;
        uint256 balance;
        uint256 releaseTime;
    }

    // creates an array with all Frozen token
    mapping(address => Frozen) frozens;

    // Called when tokens are frozen
    event Freeze(address sender, address beneficiary, uint256 amount, uint256 releaseTime);

    // Called when tokens are released
    event Release(address receiver, uint256 amount);

    constructor(address __token) {
        _token = IERC20(__token);
        _owner = msg.sender;
    }

    /**
      * @dev Throws if called by any account other than the owner.
      */
    modifier ownerOnly(){
        require(_owner == msg.sender, "caller is not the owner");
        _;
    }

    /**
    * @return the token being held.
    */
    function token() public view virtual returns (IERC20) {
        return _token;
    }


    /**
    * @dev froze token for a specified address
    * @param beneficiary The address to transfer token when released.
    * @param amount The frozen amount.
    * @param releaseTime The release time of frozen token.
    */
    function freeze(address beneficiary, uint256 amount, uint256 releaseTime) public {
        token().safeTransferFrom(msg.sender, address(this), amount);
        frozens[beneficiary].beneficiary = beneficiary;
        frozens[beneficiary].balance = frozens[beneficiary].balance + amount;
        frozens[beneficiary].releaseTime = releaseTime;
        emit Freeze(msg.sender, beneficiary, amount, releaseTime);
    }

    /**
    * @dev release frozen token for specified address
    * @param beneficiary The address to transfer to.
    */
    function release(address beneficiary) public {
        require(frozens[beneficiary].balance > 0, "no tokens to release");
        require(block.timestamp >= frozens[beneficiary].releaseTime, "current time is before release time");
        token().safeTransfer(beneficiary, frozens[beneficiary].balance);
        emit Release(beneficiary, frozens[beneficiary].balance);
        frozens[beneficiary].balance = 0;
    }

    /**
    * @dev update release time of the frozen token for a specified address
    * @param beneficiary The address to transfer token when released.
    * @param releaseTime The release time of frozen token.
    */
    function updateReleaseTime(address beneficiary, uint256 releaseTime) public ownerOnly {
        require(frozens[beneficiary].balance > 0, "address doesn't have frozen balance");
        require(frozens[beneficiary].releaseTime > block.timestamp, "release time is before current time");
        frozens[beneficiary].releaseTime = releaseTime;
    }
    
    /**
    * @dev get data of frozen token for a specified address
    * @param beneficiary The address to check.
    */
    function frozenOf(address beneficiary) public view returns(Frozen memory){
        require(frozens[beneficiary].balance > 0, "address doesn't have frozen balance");
        return frozens[beneficiary];
    }

}