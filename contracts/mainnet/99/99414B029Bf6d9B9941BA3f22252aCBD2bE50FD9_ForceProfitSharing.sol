pragma solidity 0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/ERC20Detailed.sol";

contract ForceProfitSharing is ERC20, ERC20Detailed {
    using SafeMath for uint256;
    IERC20 public force;

    // Define the Force token contract
    constructor(address _underlying) public {
        force = IERC20(_underlying);
        ERC20Detailed.initialize(
            "xFORCE",
            "xFORCE",
            ERC20Detailed(_underlying).decimals()
        );
    }

    function deposit(uint256 amount) external {
        // Gets the amount of Force locked in the contract
        uint256 totalForce = force.balanceOf(address(this));
        // Gets the amount of dForce in existence
        uint256 totalShares = totalSupply();
        // If no dForce exists, mint it 1:1 to the amount put in
        if (totalShares == 0 || totalForce == 0) {
            _mint(msg.sender, amount);
        }
        // Calculate and mint the amount of dForce the Force is worth. The ratio will change overtime, as dForce is burned/minted and Force deposited + gained from fees / withdrawn.
        else {
            uint256 what = amount.mul(totalShares).div(totalForce);
            _mint(msg.sender, what);
        }
        // Lock the Force in the contract
        force.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 numberOfShares) external {
        // Gets the amount of dForce in existence
        uint256 totalShares = totalSupply();
        // Calculates the amount of Force the dForce is worth
        uint256 what =
            numberOfShares.mul(force.balanceOf(address(this))).div(totalShares);
        _burn(msg.sender, numberOfShares);
        force.transfer(msg.sender, what);
    }
}