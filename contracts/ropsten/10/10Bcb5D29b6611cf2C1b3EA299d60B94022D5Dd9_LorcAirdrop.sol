pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./access/Ownable.sol";

contract LorcAirdrop is Ownable {

    IERC20 public token;

    /// constructor function to set token address
    constructor(address _tokenAddress) public {
        token = IERC20(_tokenAddress);
    }

    /// @dev Airdrop function which take up a array of address and LORC amount
    function airDrop(address _from, address[] memory _address, uint256 _amount) external onlyOwner returns (bool) {
        uint256 count = _address.length;
        require(count * _amount <= token.allowance(_from, address(this)), "LorcAirdrop: insufficient balance");

        for (uint256 i = 0; i < count; i++){
           require(token.transferFrom(_from, _address[i],_amount), "LorcAirdrop: transfer failed");
        }
        return true;
    }

    /// @dev Distribute bonus to multiple address with multiple LORC amount
    function bonus(address _from, address[] memory _address, uint256[] memory _amount) external onlyOwner returns (bool) {
        require(_address.length == _amount.length, "LorcAirdrop: address and amounts length must be same");

        for (uint256 i = 0; i < _address.length; i++){
           require(token.transferFrom(_from, _address[i], _amount[i]), "LorcAirdrop: transfer failed");
        }
        return true;
    }

    // /// @notice Withdraw ERC20 from contract
    // function withdrawLorc(uint amount) external onlyOwner {
    //     require(amount > 0, "LorcAirdrop: invalid amount");
    //     require(token.balanceOf(address(this)) >= amount, "LorcAirdrop: insufficient ERC20 balance");
    //     require(token.transfer(msg.sender, amount), "LorcAirdrop: transfer failed");
    // }
}