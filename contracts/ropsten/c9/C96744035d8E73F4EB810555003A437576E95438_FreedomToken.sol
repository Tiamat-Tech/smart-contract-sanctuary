pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract FreedomToken is ERC20("Freedom DAO Token", "FREE"), Ownable {
    mapping(address => bool) _minters;

    modifier onlyMinter() {
        require(_minters[msg.sender] == true, "FreeToken: Not a minter");
        _;
    }

    function mint(address _to, uint256 _amount) public onlyMinter {
        _mint(_to, _amount);
    }

    function addMinter(address minter) public onlyOwner {
        _minters[minter] = true;
    }

    function removeMinter(address minter) public onlyOwner {
        _minters[minter] = false;
    }
}