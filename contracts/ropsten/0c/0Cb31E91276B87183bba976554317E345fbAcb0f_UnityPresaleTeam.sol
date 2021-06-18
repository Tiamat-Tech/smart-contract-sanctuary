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

contract UnityPresaleTeam is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Presale state
    bool private _isActive;

    // The token being sold
    IERC20 public _token;

    // Address where funds are collected
    address payable private _wallet;

    // Address to withdraw remaining tokens
    address payable private _withdraw;

    // Owners who can whitelist
    address[] private owners;
    mapping(address => bool) public isOwner;
    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
        _;
    }

    // Team addresses
    mapping (address => bool) _isTeam;
    mapping (address => uint256) totalPurchased;

    // How many token units a buyer gets per wei.
    // The rate is the conversion between wei and the smallest and indivisible token unit.
    // So, if you are using a rate of 1 with a ERC20Detailed token with 3 decimals called TOK
    // 1 wei will give you 1 unit, or 0.001 TOK.
    uint256 private _rate;

    /**
     * Event for token purchase logging
     * @param purchaser who paid for the tokens
     * @param value weis paid for purchase
     * @param amount amount of tokens purchased
     */
    event TokensPurchased(address indexed purchaser, uint256 value, uint256 amount);

    /**
     * @param token_rate Number of token units a buyer gets per wei
     * @param receive_address Address where collected funds will be forwarded to
     * @param token_addr Address of the token being sold
     */
    constructor (uint256 token_rate, address payable receive_address, address token_addr, address payable withdraw_addr, address[] memory team_addresses, address[] memory _owners) {
        require(token_rate > 0, "Presale: invalid rate");
        require(receive_address != address(0), "Presale: wallet is the zero address");
        require(address(token_addr) != address(0), "Presale: token is the zero address");

        _rate = token_rate;
        _wallet = receive_address;
        _token = IERC20(token_addr);
        _withdraw = withdraw_addr;

        for (uint i = 0; i < _owners.length; i++) {
            address owner = _owners[i];

            require(owner != address(0), "invalid owner");
            require(!isOwner[owner], "owner not unique");

            isOwner[owner] = true;
            owners.push(owner);
        }

        uint256 length = team_addresses.length;
        for (uint256 i = 0; i < length; i++)
            _isTeam[team_addresses[i]] = true;
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
    function buyTokens() public nonReentrant payable {
        uint256 weiAmount = msg.value;
        address buyer = msg.sender;
        _preValidatePurchase(buyer, weiAmount);
        totalPurchased[buyer] = totalPurchased[buyer] + weiAmount;

        // calculate token amount to be created
        uint256 tokens = _getTokenAmount(weiAmount);

        _processPurchase(buyer, tokens);
        emit TokensPurchased(buyer, weiAmount, tokens);


        _forwardFunds();
    }

    function _preValidatePurchase(address buyer, uint256 weiAmount) internal view {
        require(_isActive == true, "Presale: is not active");
        require(buyer != address(0), "Presale: beneficiary is the zero address");
        require(_isTeam[buyer] == true, "Presale: Unrecognized address");
        require(totalPurchased[buyer] + weiAmount <= 2 * 10**18, "Presale: Cannot buy more than 2BNB");
        require(weiAmount >= 10**17, "Presale: minimum amount is 0.1 BNB");
        require(weiAmount <= 2 * 10**18, "Presale: maximum amount is 2 BNB");
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
    function withdraw(uint256 tokenAmount) public onlyOwner {
        require(_isActive == false, "Presale: is active");
        _deliverTokens(_withdraw, tokenAmount);
    }

    function _addToTeam(address addressToAdd) public onlyOwner {
        _isTeam[addressToAdd] = true;
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