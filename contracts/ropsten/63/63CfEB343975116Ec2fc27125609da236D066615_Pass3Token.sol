// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./IPass3Registrar.sol";
import "./EIP2612.sol";
import "./TwoStepOwnable.sol";
import "./StringUtils.sol";

interface IPass3 {
    function RegistreForOtherTerminated() external view returns (bool);

    function REGISTRATION_COST() external pure returns (uint256);

    function register(string calldata label) external;

    function registerForOther(string calldata label, address owner) external;

}

contract Pass3Token is TwoStepOwnable, IPass3, EIP2612  {

    using StringUtils for *;

    // ============ Immutable Registration Configuration ============

    uint256 public override constant REGISTRATION_COST = 1e18;


    // ============ Mutable Registration Configuration ============
    bool public  registrable = true;
    
    bool public override RegistreForOtherTerminated = false;

    address private _registerRole;

    address public _pass3Registrar;


    // ============ Events ============

    event Registered(string label, address owner);
    event Mint(address indexed to, uint256 amount); 

    // ============ Modifiers ============

    modifier canRegister() {
        require(registrable, "Pass3Token: registration is closed.");
        _;
    }

    modifier onlyRegisterRole() {
        require(
            _registerRole == msg.sender,
            "Pass3Token: missing register role."
        );
        _;
    }

    constructor() EIP2612("Pass3 Token", "PASS") {}

    // ============ Minting ============

    /**
     * @dev Function to mint tokens
     * @param to The address that will receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);

        emit Mint(to, amount);
    }

    // ============ Registration ============

    function valid(string memory name) public pure returns(bool) {
        return name.strlen() >= 3 && name.strlen() <= 15;
    }
    
    function register(string calldata label)
        external
        override
        canRegister
    {
        require(valid(label), "Pass3Token: Registered label is supposed to be greater than 2 and less than 16.");
        _burn(msg.sender, REGISTRATION_COST);

        emit Registered(label, msg.sender);

        IPass3Registrar(_pass3Registrar).register(label, msg.sender);
    }

    function registerForOther(string calldata label, address owner_)
        external
        override
        onlyRegisterRole
        canRegister
    {
        require(valid(label), "Pass3Token: Registered label is supposed to be greater than 2 and less than 16.");
        _burn(msg.sender, REGISTRATION_COST);

        emit Registered(label, owner_);

        IPass3Registrar(_pass3Registrar).register(label, owner_);
    }

    // ============ Configuration Management ============

    /**
     * Allows the owner to change the ENS Registrar address.
     */
    function setENSRegistrar(address _pass3Registrar_) external onlyOwner {
        _pass3Registrar = _pass3Registrar_;
    }

    /**
     * Allows the owner to pause registration.
     */
    function setRegistrable(bool registrable_) external onlyOwner {
        registrable = registrable_;
    }

    function setRegisterRole(address addr) external onlyOwner {
        require(RegistreForOtherTerminated == false, "Pass3Token: Register for others has been deprecated.");
        if (addr == address(0)) {
            RegistreForOtherTerminated = true;
        }
        // If we set register role as the 0x0, then register for others will be terminated forever.
        _registerRole = addr;
    }

}