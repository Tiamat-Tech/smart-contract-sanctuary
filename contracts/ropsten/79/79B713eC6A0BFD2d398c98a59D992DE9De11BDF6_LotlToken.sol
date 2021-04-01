pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//import "./libs/BEP20.sol";




// LotlToken
contract LotlToken is ERC20('Axolotl', 'LOTL') {

    address master;

    constructor( address _master ) public { master = _master; }

    // After initial minting of ICO set to MasterChef address.
    function setMaster(address _master) public {
        require(msg.sender == master, "You are not my Master.");
        master = _master;
        emit SetMasterAddress(msg.sender, _master);
    }

    event SetMasterAddress(address indexed user, address indexed newAddress);


    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public {
        require(msg.sender == master, "dev: wut?");
        _mint(_to, _amount);
    }

}