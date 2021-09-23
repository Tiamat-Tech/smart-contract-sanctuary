// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./tokens/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Give is ERC20, ReentrancyGuard {
    using SafeMath for uint;
    /*
    * Token contract
    * Donations.org token contract Give
    * with a total supply of 1.000.000.000 (one billion million) tokens
    */

    address public Governance;
    // There are only 100.000.000 million tokens
    constructor() ERC20("Donations.org", "Give", 100000000) {
        Governance = address(this);
    }

    /**
      * @dev Internal function that burns an amount of the token of a given
      * account.
      * @param amount The amount that will be burnt.
    */
    function burn(uint256 amount) onlyOwner external {
        _burn(Governance, amount);
    }

    function burnGovernance() onlyOwner external{
        Governance = address(0x0);
    }

    /**
     * @dev Purchase GIVE tokens for ETH
    */
    function purchaseTokens(uint _amountOfTokens) nonReentrant external payable {
        // Check if contract has the amount of tokens left in contract
        require(balanceOf(contractAddress) >= _amountOfTokens, "Error: Not enough tokens inside the contract");

        // Add ETH to the Contract balance
        _ethBalance[contractAddress] = _ethBalance[contractAddress].add(msg.value);

        // Send GIVE to the Sender
        transferTokens(contractAddress, _msgSender(), _amountOfTokens);

        // Transfer ETH to Contract
        emit Transfer(_msgSender(), contractAddress, msg.value);
        // Transfer Tokens to Sender
//        emit Transfer(contractAddress, _msgSender(), _amountOfTokens);
    }

    /**
     * @dev Sell GIVE tokens for ETH
    */
    function sellTokens(uint _amountOfTokens, uint _amountOfEth) nonReentrant external payable {
        require(_amountOfTokens > 0, "Error: Token amount has to be larger than 0");
        require(_amountOfEth > 0, "Error: ETH amount has to be larger than 0");
        // Check if contract has the amount of tokens left in contract
        require(balanceOf(_msgSender()) >= _amountOfTokens, "Error: Spend more tokens than user has");
        require(balanceOfEth() >= _amountOfEth, "Error: Not enough ETH in contract");

        // Sub ETH from the Contract balance
        _ethBalance[contractAddress] = _ethBalance[contractAddress].sub(_amountOfEth);

        // Transfer the amount received
        (bool transferEth, ) = _msgSender().call{value: _amountOfEth}(abi.encodeWithSignature("Transfer ETH", _amountOfEth));
        require(transferEth, "Error: Transfer ETH failed");

        // Send GIVE to the Contract
        transferTokens(_msgSender(), contractAddress, _amountOfTokens);

        // Transfer ETH to Sender
        emit Transfer(contractAddress, _msgSender(), _amountOfEth);
        // Transfer Tokens to Contract
        emit Transfer(_msgSender(), contractAddress, _amountOfTokens);
    }

    /**
     * @dev Transfer tokens for a specified address from the contract
     * @param recipient The address to transfer to.
     * @param amount The amount to be transferred.
    */
    function transferTokens(address spender, address recipient, uint256 amount) private returns(bool) {
        _transfer(spender, recipient, amount);
        return true;
    }

    function deposit() onlyOwner external payable {
        _ethBalance[contractAddress] = _ethBalance[contractAddress].add(msg.value);
        emit Transfer(_msgSender(), contractAddress, msg.value);
    }
}