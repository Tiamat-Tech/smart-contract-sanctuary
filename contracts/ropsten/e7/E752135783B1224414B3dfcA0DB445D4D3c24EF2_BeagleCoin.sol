// SPDX-License-Identifier: MIT
pragma solidity >=0.5.0 <0.9.0;

//import "@openzeppelin/upgrades-core/contracts/Initializable.sol";
//import "@openzeppelin/contracts-upgradeable/token/ERC777/ERC777Upgradeable.sol";

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//import "./SafeMath.sol";

contract BeagleCoin is ERC777, Ownable {
    /* Public variables of the token */
    //string private _name; //fancy name: eg Simon Bucks
    //uint8 private _decimals; //How many decimals to show. ie. There could 1000 base units with 3 decimals. Meaning 0.980 SBX = 980 base units. It's like comparing 1 wei to 1 ether.
    //string private _symbol; //An identifier: eg BEAGLE
    string public version; //Just an arbitrary versioning scheme.
    address private _owner;

    //donation account - account where 2% of transaction token goes
    //gas account - 1% of trasaction token goes
    //burn account - 1 % of transaction token goes
    //lottery account - 1% of transaction token goes
    //function initialize(address poolAddr) public {
    constructor()
        ERC777("Beagle", "BEAGLE", new address[](0))
        Ownable()
    {
        _owner = tx.origin; //set the owner of the contract
        //_poolAddr = 0xaa51546B5286500a698CcEcC0D09605054c43B17;
        //_poolAddr = poolAddr;

        //ERC20(owner, _poolAddr);

        //string memory _name = "Beagle";
        //string memory _symbol = "BEAGLE";
        version = "1.0";

        uint256 totalSupply = 10**10 * 10**uint256(decimals()); //10 billion tokens with 8 decimal places
        //_feesPercent = 4;

        //balances[tx.origin] = _totalSupply;

        //address[] memory defaultOperators;
        //__ERC777_init(_name, _symbol, defaultOperators);

        mint(msg.sender, totalSupply);
    }

    /* function owner() public view returns (address) {
        return _owner;
    } */

    /* modifier onlyOwner {
        require(_msgSender() == owner(), "BEAGLE: Only allowed by the Owner");
        _;
    } */

    /**
     * @dev [OnlyOwner - can call this]
     * Creates new token and sends them to account
     * @param account The address to send the minted tokens to
     * @param amount Amounts to tokens to generate
     */
    function mint(address account, uint256 amount) public onlyOwner {
        super._mint(account, amount, "", "");
    }

    

    // removed custom burn, everyone is allowed to burn their assets
    /**
     * dev [OnlyOwner - can call this]
     * Reservoir Burn - Burns token from owner's account
     * param amount Amounts to tokens to burn
     * param data Data for registered hook
     */
    /* function burn(uint256 amount, bytes memory data) public override onlyOwner {
        super.burn(amount, data);
    } */
}