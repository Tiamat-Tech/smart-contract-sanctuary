/**
 *Submitted for verification at Etherscan.io on 2021-09-24
*/

// File: @openzeppelin/contracts/token/ERC20/IERC20.sol



pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

// File: DEX/Atransfer_token_test.sol

pragma solidity ^0.8.0;

//import "./IERC20.sol";
//import "./IBEP20.sol";


/*
interface IERC20 {

    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
}
*/

contract Atransfertoken{
    address public token_address = 0x817c4Ccfe27B655b45018a1febCF8565663c896f;
    uint256 public allw = 999;
    uint256 public allw2 = 111;
    bool public apprx = false;

    event allwox(uint256 amountx );

    constructor() public{
    }

    IERC20 tokenx = IERC20(address(token_address));

    function appr(uint256 amount) public returns(bool) {
       apprx = tokenx.approve(address(this), amount);
      // allw =  tokenx.allowance(msg.sender, address(this));
     //  emit allwox(allw);
        if(apprx){
            allwo();
        }
        return apprx; 
    }
    
    function allwo() public returns(uint256){
        allw = tokenx.allowance(msg.sender, address(this));
         allw2 = tokenx.allowance(address(this), msg.sender);
        emit allwox(allw);
        return allw;
    }

    function transferx(uint256 amount) public{
        require(tokenx.approve(msg.sender, amount));
        tokenx.transferFrom(msg.sender, address(this), amount);
     //   tokenx.transfer(address(this),amount);
    }


    function withdrawErc20(IERC20 token) public {
        require(token.transfer(msg.sender, token.balanceOf(address(this))), "Transfer failed");
    
    }

    function WithdrawToOwner() public returns(address) {

        payable(msg.sender).transfer(address(this).balance);
        return msg.sender;
  }

}