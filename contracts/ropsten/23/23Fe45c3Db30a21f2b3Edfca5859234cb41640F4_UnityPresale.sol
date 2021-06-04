// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
//-------------------------|| UnityFund.finance ||----------------------------\\
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
//\\//\\//\\//\\//\\//\\//\/\/\/\\//\\//\\//\\//\\//\\//\\/\/\/\/\/\/\/\/\/\/\\\
//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import "@openzeppelin/contracts/access/Ownable.sol";

contract UnityPresale is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    // Presale state
    bool private _isActive;

    // The token being sold
    IERC20 public _token;

    // Address where funds are collected
    address payable private _wallet;

    // How many token units a buyer gets per wei.
    // The rate is the conversion between wei and the smallest and indivisible token unit.
    // So, if you are using a rate of 1 with a ERC20Detailed token with 3 decimals called TOK
    // 1 wei will give you 1 unit, or 0.001 TOK.
    uint256 private _rate;

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param beneficiary who got the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokensPurchased(address indexed purchaser, address indexed beneficiary, uint256 value, uint256 amount);

    /**
     * @param token_rate Number of token units a buyer gets per wei
     * @param recieve_address Address where collected funds will be forwarded to
     * @param token_addr Address of the token being sold
     */
    constructor (uint256 token_rate, address payable recieve_address, address token_addr) {
        require(token_rate > 0, "Presale: invalid rate");
        require(recieve_address != address(0), "Presale: wallet is the zero address");
        require(address(token_addr) != address(0), "Presale: token is the zero address");

        _rate = token_rate;
        _wallet = recieve_address;
        _token = IERC20(token_addr);
    }


    /**
     * @return the token being sold.
     */
    function token() public view returns (IERC20) {
        return _token;
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
     *  Buy tokens by calling this function
     */
    function buyTokens(address beneficiary) public nonReentrant payable {
        uint256 weiAmount = msg.value;
        _preValidatePurchase(beneficiary, weiAmount);

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(weiAmount);

        _processPurchase(beneficiary, tokens);
        emit TokensPurchased(msg.sender, beneficiary, weiAmount, tokens);


        _forwardFunds();
    }

    function _preValidatePurchase(address beneficiary, uint256 weiAmount) internal view {
        require(_isActive == true, "Presale: is not active");
        require(beneficiary != address(0), "Presale: beneficiary is the zero address");
        require(weiAmount >= 10**17, "Presale: minimum amount is 0.1 BNB");
        require(weiAmount <= 10**18, "Presale: maximum amount is 1 BNB");
    }

    function _activatePresale() public onlyOwner {
        _isActive = true;
    }

    function _pausePresale() public onlyOwner {
        _isActive = false;
    }

    /**
     * Used to burn the remaining tokens when the presale is finished
     */
    function burn(uint256 tokenAmount) public onlyOwner {
        require(_isActive == false, "Presale: is active");
        _deliverTokens(0x000000000000000000000000000000000000dEaD, tokenAmount);
    }

    // internal functions

    /**
     * @param beneficiary Address performing the token purchase
     * @param tokenAmount Number of tokens to be emitted
     */
    function _deliverTokens(address beneficiary, uint256 tokenAmount) internal {
        _token.safeTransfer(beneficiary, tokenAmount);
    }

    /**
    * @param beneficiary Address receiving the tokens
    * @param tokenAmount Number of tokens to be purchased
    */
    function _processPurchase(address beneficiary, uint256 tokenAmount) internal {
        _deliverTokens(beneficiary, tokenAmount);
    }

    /**
     * @param weiAmount Value in wei to be converted into tokens
     * @return Number of tokens that can be purchased with the specified _weiAmount
     */
    function _getTokenAmount(uint256 weiAmount) internal view returns (uint256) {
        return (weiAmount * _rate)/1000;
    }

    function _forwardFunds() internal {
        _wallet.transfer(msg.value);
    }
}