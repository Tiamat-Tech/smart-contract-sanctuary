import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "hardhat/console.sol";

library SafeMath {
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }
}

contract Hoge2 is ERC20 {
	using SafeMath for uint256;
	IERC20 HOGE = IERC20(0xfAd45E47083e4607302aa43c65fB3106F1cd7607);
	constructor() ERC20("Hoge2.0", "HOGE2") {}

	function decimals() public view virtual override returns (uint8) {
	    return 9;
	}

	function wrap(uint256 hogeAmount) public {
		require(HOGE.balanceOf(msg.sender) >= hogeAmount, "Insufficient HOGE balance.");
		HOGE.transferFrom(msg.sender, address(this), hogeAmount);
		_mint(msg.sender, hogeAmount.mul(98) / 100);
	}

	function unwrap(uint256 hoge2Amount) public {
		require(balanceOf(msg.sender) >= hoge2Amount, "Insufficient HOGE2 balance.");
		HOGE.transfer(msg.sender, hoge2Amount);
		_burn(msg.sender, hoge2Amount);
	}

	function burnableHoge() public view returns (uint256) {
		return HOGE.balanceOf(address(this)).sub(this.totalSupply());
	}

	function burnHoge() public returns (uint256) {
		//Burn off excess reflected HOGE
		uint256 burnable = this.burnableHoge();
		HOGE.transfer(0x000000000000000000000000000000000000dEaD, burnable);
		return burnable;
	}
}