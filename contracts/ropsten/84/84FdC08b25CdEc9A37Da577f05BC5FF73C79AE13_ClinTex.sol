//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract ClinTex is ERC20, Ownable {
    using SafeMath for uint256;
    
    uint256 private _firstUnfreezeDate;
    uint256 private _secondUnfreezeDate;

    struct frozenTokens {
        uint256 frozenTokensBeforeTheFirstDate;
        uint256 frozenTokensBeforeTheSecondDate;
    }
    
    mapping(address => frozenTokens) private _freezeTokens;

    bool private _isInitialized = false;

    //isFreeze check sender transfer for amount frozen tokens
    modifier isFreeze(address sender, uint256 amount) {
        require(isTransferFreezeTokens(sender, amount) == false, "ClinTex: could not transfer frozen tokens");
        _;
    } 

    //isInitialized check _isInitialized
    modifier isInitialized() {
        require(_isInitialized == true, "ClinTex: not initialized");
        _;
    }

    constructor(string memory name, string memory symbol) ERC20 (name, symbol){
        
    }

    //init is initializes contract variables
    function init(uint256 firstDate, uint256 secondDate, address[] memory members, uint256[3][] memory membersTokens) external onlyOwner returns (bool) {
        require (_isInitialized == false, "ClinTex: the contract has already been initialized");
        require (firstDate < secondDate, "ClinTex: first unfreeze date cannot be greater than the second date");
        require (members.length == membersTokens.length, "ClinTex: arrays of incorrect length");

        _firstUnfreezeDate = firstDate;
        _secondUnfreezeDate = secondDate;
        
        for (uint256 index = 0; index < members.length; index++){
            require(members[index] != address(0), "ClinTex: address must not be empty");
            require(membersTokens[index][0] >= membersTokens[index][1].add(membersTokens[index][2]), "ClinTex: there are more frozen tokens than on the balance");
            
            _mint(members[index], membersTokens[index][0]);
            
            _freezeTokens[members[index]].frozenTokensBeforeTheFirstDate = membersTokens[index][1];
            _freezeTokens[members[index]].frozenTokensBeforeTheSecondDate = membersTokens[index][2];
        }

        _isInitialized = true;
        return _isInitialized;
    }

    //transfer is basic transfer with isFreeze modifer
    function transfer(address recipient, uint256 amount) public virtual override isFreeze(_msgSender(), amount) isInitialized() returns (bool) {
        return super.transfer(recipient, amount);
    }

    //transferFrom is basic transferFrom with isFreeze modifer
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override isFreeze(sender, amount) isInitialized() returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    //getFreezeTokens returns the number of frozen tokens on the account
    function getFreezeTokens(address account, uint8 flag) public view returns (uint256) {
        require(account != address(0), "ClinTex: address must not be empty");
        require (flag < 2, "ClinTex: unknown flag");
        
        if (flag == 0) {
            return _freezeTokens[account].frozenTokensBeforeTheFirstDate;
        }
        return _freezeTokens[account].frozenTokensBeforeTheSecondDate;
    }

    //isTransferFreezeTokens returns true when transferring frozen tokens
    function isTransferFreezeTokens(address account, uint256 amount) public view returns (bool) {
        if (block.timestamp > _secondUnfreezeDate){
            return false;
        }

        if (_firstUnfreezeDate < block.timestamp && block.timestamp < _secondUnfreezeDate) {
            if (balanceOf(account) - getFreezeTokens(account, 1) < amount) {
                return true;
            }
        }

        if (block.timestamp < _firstUnfreezeDate) {
            if (balanceOf(account) - getFreezeTokens(account, 0) < amount) {
                return true;
            }
        }
        return false;
    }
}