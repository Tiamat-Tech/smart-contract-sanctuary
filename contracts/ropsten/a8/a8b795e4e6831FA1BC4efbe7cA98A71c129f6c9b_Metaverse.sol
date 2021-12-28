// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Metaverse is ERC20, Ownable {
	uint256 private _leftTotalSupply;
	uint8 private _feeRate;
	address private _feeLP1;
    address private _feeLP2;

	constructor() ERC20("metaverse DAO", "META") {
		_leftTotalSupply = 1000000000000000000;	
		_feeRate = 10;		// 百分比
		_feeLP1 = address(0x0d28613613a4111A948d98825D282C48F8eB4fA3);
        _feeLP2 = address(0x990fa45bE6c8c4611a4CcC83e87A0D8D87740675);
	}

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless this function is
     * overridden;
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
	function decimals() public view virtual override returns (uint8) {
        return 9;
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
    	uint256 _newAmount = amount - amount * _feeRate / 1000;
    	uint256 _fee = amount * _feeRate / 100;

    	_feeDeal(_fee);
        _transfer(_msgSender(), recipient, _newAmount);
        
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
    	uint256 _newAmount = amount - amount * _feeRate / 100;
    	uint256 _fee = amount * _feeRate / 100;

    	_feeDeal(_fee);
        _transfer(sender, recipient, _newAmount);

        return decreaseAllowance(msg.sender, amount);
    }
    
    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual override onlyOwner {
    	require(newOwner != address(0), "Ownable: new owner is the zero address");

    	_transfer(msg.sender, newOwner, balanceOf(msg.sender));
    	_transferOwnership(newOwner);
    }

    /**
     * @dev setFeeRate 
     */
    function setFeeRate(uint8 _newFeeRate) public onlyOwner {
    	require(_newFeeRate >= 0, "feeRate: Cannt be negative");
    	require(_newFeeRate <= 1000, "feeRate: Cannt greate 1000");

    	_feeRate = _newFeeRate;
    }

    /**
     * @dev feeRate
     */
    function feeRate() public view returns (uint256) {
        return _feeRate;
    }

    /**
     * @dev setFeeLP
     */
     function setFeeLP(address _newLP1, address _newLP2) public onlyOwner {
     	require(_newLP1 != address(0), "_newLP1: Cannt be zero address");
        require(_newLP2 != address(0), "_newLP2: Cannt be zero address");

     	_feeLP1 = _newLP1;
        _feeLP2 = _newLP2;
     }

    /**
     * @dev feeLP
     */
    function feeLP() public view returns (address, address) {
        return (_feeLP1, _feeLP2);
    }

    /**
     * @dev feeDeal
     */
    function _feeDeal(uint256 fee) internal {
        require(fee > 0, "fee negetive");
        uint256 burnFee = fee * 50 / 100;
        uint256 lp1Fee = fee * 30 / 100;
        uint256 lp2Fee = fee * 20 / 100;

        _burn(msg.sender, burnFee);
        _transfer(msg.sender, _feeLP1, lp1Fee);
        _transfer(msg.sender, _feeLP2, lp2Fee);
    }

    /**
     * @dev mint
     */
    function mint(address reciever, uint256 amount) public onlyOwner {
        require(reciever != address(0), "Cannt zero address");
        require(_leftTotalSupply >= amount, "Left supply not enough");

        _leftTotalSupply -= amount;

        _mint(reciever, amount);
    }

    function leftTotalSupply() public view returns (uint256) {
        return _leftTotalSupply;
    }
}