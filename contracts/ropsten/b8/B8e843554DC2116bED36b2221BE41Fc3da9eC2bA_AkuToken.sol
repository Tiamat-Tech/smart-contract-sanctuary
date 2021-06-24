//"SPDX-License-Identifier: UNLICENSED"

pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AkuToken is ERC20, ERC20Burnable, Ownable {

    address public minter;

    event NewMinter(address indexed setter, address indexed newMinter);
    event MinterRemoved(address indexed setter, address indexed removedMinter);
    event ERC20Returned(address indexed token, address indexed receiver, uint amount);

    modifier onlyMinter() {
        require(msg.sender == minter, "MINTER: only minter can do this");
        _;
    }

    constructor(uint _initialSupply) ERC20("Aku Token", "AKU") {
        _mint(msg.sender, _initialSupply);
    }

    function setMinter(address _minter) external onlyOwner() {
        require(minter != _minter, "ERC20: already minter");
        minter = _minter;
        emit NewMinter(_msgSender(), _minter);
    }

    function renounceMinter() external onlyOwner() {
        require(minter != address(0), "ERC20: no minter to renounce");
        minter = address(0);
        emit MinterRemoved(_msgSender(), address(0));
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override(ERC20) {
        super._beforeTokenTransfer(from, to, amount);
        require(amount > 0, "ERC20: invalid amount input");
    }

    function mint(address _to, uint256 _amount) external onlyMinter() {
        _mint(_to, _amount);
    }

    function returnERC20(
        address _token, 
        address _to, 
        uint _amount
    ) external onlyOwner() {
        require(_token != address(0), "ERC20: invalid _token address");
        require(_to != address(0), "ERC20: invalid _to address");
        require(
            IERC20(_token).balanceOf(address(this)) >= _amount, 
            "ERC20: insufficient token balance"
        );
        IERC20(_token).transfer(_to, _amount);      
        emit ERC20Returned(_token, _to, _amount);
    }

}