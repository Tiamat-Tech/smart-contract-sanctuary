pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AkuToken is ERC20, ERC20Burnable, Ownable {

    mapping(address => bool) public isMinter;

    event NewMinter(address indexed setter, address indexed newMinter);
    event MinterRemoved(address indexed setter, address indexed removedMinter);
    event ERC20Returned(address indexed token, address indexed receiver, uint amount);

    modifier onlyMinter() {
        require(isMinter[_msgSender()], "MINTER: only a minter can do this");
        _;
    }

    constructor(uint _initialSupply) ERC20("Aku Token", "AKUT") {
        _mint(msg.sender, _initialSupply);
    }

    function addMinter(address _minter) external onlyOwner() {
        require(!isMinter[_msgSender()], "ERC20: already a minter");
        isMinter[_msgSender()] = true;
        emit NewMinter(_msgSender(), _minter);
    }

    function removeMinter(address _minter) external onlyOwner() {
        require(isMinter[_msgSender()], "ERC20: not a minter");
        isMinter[_msgSender()] = false;
        emit MinterRemoved(_msgSender(), _minter);
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