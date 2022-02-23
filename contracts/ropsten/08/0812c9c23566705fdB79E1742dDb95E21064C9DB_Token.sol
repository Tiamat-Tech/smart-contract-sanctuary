pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC777/ERC777.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is ERC777, Ownable {
    address public imx;

    event TokenMinted(address to, uint256 quantity);

    constructor(        
        address _owner,
        string memory _name,
        string memory _symbol,
        address _imx
    ) ERC777(_name, _symbol, addressArray(_owner, _imx)) {
        imx = _imx;
        require(_owner != address(0), "Owner must not be empty");
        transferOwnership(_owner);
    }
   
    modifier onlyOwnerOrIMX() {
        require(msg.sender == imx || msg.sender == owner(), "Function can only be called by owner or IMX");
        _;
    }

    function mintFor(
        address user,
        uint256 quantity
    ) external onlyOwnerOrIMX {
        require(quantity > 0, "Invalid quanitity");
        _mint(user, quantity, "", "");
        emit TokenMinted(user, quantity);
    }

    function addressArray(address owner, address imx) internal returns (address[] memory)
    {
        address[] memory a = new address[](2);
        a[0] = owner;
        a[1] = imx;
        return a;
    }

}