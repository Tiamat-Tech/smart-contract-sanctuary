pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
//CHANGE FOR BSC
//import "./libs/BEP20.sol";




// LotlToken
contract LotlToken is ERC20('Axolotl', 'LOTL') {

    address public master;

    constructor( address _master ) public { master = _master; }

    // After initial minting of ICO set to MasterChef address.
    // After it has been set it is not changeable. 
    // Owner of the Token will be the MasterChef contract and thus only the MasterChef contract is able to mint Lotl.
    // We do not see need for a community governed Token. 

    function setMaster(address _master) public {
        require(msg.sender == master, "You are not my Master.");
        master = _master;
        emit SetMasterAddress(msg.sender, _master);
    }

    event SetMasterAddress(address indexed user, address indexed newAddress);


    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (MasterChef).
    function mint(address _to, uint256 _amount) public {
        require(msg.sender == master, "master: nani!?");
        _mint(_to, _amount);
    }

}