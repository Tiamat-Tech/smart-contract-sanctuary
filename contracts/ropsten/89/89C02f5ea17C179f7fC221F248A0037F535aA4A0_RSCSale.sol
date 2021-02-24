// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <=0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";


/**
 *
 * @title RSCSale token selling contract
 * @dev This crowdsale will serve as the primary method for users
 * to purchase RESCUE ERC20 tokens
 *
 * Contract is Admin Pausable, where buyTokens() will only be allowed
 * while unpaused. Only accepts ethereum.
 *      
 */
contract RSCSale is Context, ReentrancyGuard, Ownable, Pausable{
	using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // The token being sold
    IERC20 public RSC;

    // Address where funds are collected
    address payable private _wallet;

    // How many token units a buyer gets per wei.
    // The rate is the conversion between wei and the smallest and indivisible token unit.
    // So, if you are using a rate of 1 with a ERC20Detailed token with 3 decimals called TOK
    // 1 wei will give you 1 unit, or 0.001 TOK.
    uint256 private _rate;

    // Amount of wei raised
    uint256 private _weiRaised;
    
    //set the decimals constant
    uint256 private constant DECIMALS = 1e18;

    // Amount of tokens sold
    uint256 private _tokensSold;

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokensPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);
    event AdminRescueTokens(address token, address recipient, uint256 amount);

    constructor(uint256 rate, address payable wallet, IERC20 token) public{
	    _rate = rate;
	    _wallet = wallet;
	    RSC = token;
    }
    	
    /**
     * @dev fallback function ***DO NOT OVERRIDE***
     * Note that other contracts will transfer funds with a base gas stipend
     * of 2300, which is not enough to call buyTokens. Consider calling
     * buyTokens directly when purchasing tokens from a contract.
     */
    receive () external payable {
        buyTokens(_msgSender());
    }

    /**
     * @return the token being sold.
     */
    function token() public view returns (IERC20) {
        return RSC;
    }

    /**
     * @return the address where funds are collected.
     */
    function wallet() public view returns (address payable) {
        return _wallet;
    }

    /**
     * @return the number of token units a buyer gets per wei.
     */
    function rate() public view returns (uint256) {
        return _rate;
    }

    /**
     * @return the amount of wei raised.
     */
    function weiRaised() public view returns (uint256) {
        return _weiRaised;
    }

    /**
    * @return the amount of tokens sold
    */
    function tokensSold() public view returns(uint256){
        return _tokensSold;
    }

    /**
     * @dev low level token purchase ***DO NOT OVERRIDE***
     * This function has a non-reentrancy guard, so it shouldn't be called by
     * another `nonReentrant` function.
     * @param beneficiary Recipient of the token purchase
     */
    function buyTokens(address beneficiary) public nonReentrant whenNotPaused payable {
        uint256 weiAmount = msg.value;

        _preValidatePurchase(beneficiary, weiAmount);

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(weiAmount);

        // update state
        _tokensSold = _tokensSold.add(tokens);
        _weiRaised = _weiRaised.add(weiAmount);

        _processPurchase(beneficiary, tokens);

        emit TokensPurchased(_msgSender(), beneficiary, weiAmount, tokens);

        _forwardFunds();
    }


    /* ===== Internal Helpers ===== */

    /**
     * @dev Validation of an incoming purchase. Use require statements to revert state when conditions are not met.
     * Use `super` in contracts that inherit from Crowdsale to extend their validations.
     * @param beneficiary Address performing the token purchase
     * @param weiAmount Value in wei involved in the purchase
     */
    function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal virtual view {
        require(beneficiary != address(0), "Crowdsale: beneficiary is the zero address");
        require(weiAmount > 1e10, "Crowdsale: Minimum 10 gwei");
        this; // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
    }


    /**
     * @dev Source of tokens. Override this method to modify the way in which the crowdsale ultimately gets and sends
     * its tokens.
     * @param beneficiary Address performing the token purchase
     * @param tokenAmount Number of tokens to be emitted
     */
    function _deliverTokens(address beneficiary, uint256 tokenAmount) internal virtual {
        RSC.safeTransfer(beneficiary, tokenAmount);
    }

    /**
     * @dev Executed when a purchase has been validated and is ready to be executed. Doesn't necessarily emit/send
     * tokens.
     * @param beneficiary Address receiving the tokens
     * @param tokenAmount Number of tokens to be purchased
     */
    function _processPurchase(address beneficiary, uint256 tokenAmount) internal {
        // deliver
        _deliverTokens(beneficiary, tokenAmount);
    }


    /**
     * @dev Override to extend the way in which ether is converted to tokens.
     * @param weiAmount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
        return weiAmount.mul(_rate).div(1e9);
    }


    /**
     * @dev Determines how ETH is stored/forwarded on purchases.
     */
    function _forwardFunds() internal {
        _wallet.transfer(msg.value);
    }


    /* ====== owner only ====== */

    // Rate changing -- only when paused
    function changeRate(uint256 _weiRate) external whenPaused onlyOwner{
        _rate = _weiRate;
    }
    
    // Pause/Unpase functionality
    function pause() public onlyOwner{
        _pause();
    }


    function _pause() internal override {
        super._pause();
    }


    function unpause() public onlyOwner{
        _unpause();
    }


    function _unpause() internal override{
        super._unpause();
    }

    /**
     * @notice Allows the admin to withdraw tokens mistakenly sent into the contract.
     * @param rescuedToken The address of the token to rescue.
     * @param recipient The recipient that the tokens will be sent to.
     * @param amount How many tokens to rescue.
     */
    function adminRescueTokens(address rescuedToken, address recipient, uint256 amount) external onlyOwner {
        require(rescuedToken != address(0x0), "zero address");
        require(recipient != address(0x0), "bad recipient");
        require(amount > 0, "zero amount");

        bool ok = IERC20(rescuedToken).transfer(recipient, amount);
        require(ok, "transfer");

        emit AdminRescueTokens(rescuedToken, recipient, amount);
    }

}