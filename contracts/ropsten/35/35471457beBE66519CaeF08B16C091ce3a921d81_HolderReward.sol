// SPDX-License-Identifier: MIT // TBC
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
 
contract A999Token is ERC20, Pausable, ReentrancyGuard, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using Address for address;

    // ------------------- constants  -------------------

    uint256 private constant _initialSupply = 300000000 * 1e18;         // mint 300M of tokens on day-0
        
    // ------------------- managable attributes -------------------

    uint8 private _feeBurnPerMille = 10;                        // %% of a transfer thet gets burned until _minimumSupply is reached; e.g. 10 == 1%
    uint256 private _minimumSupply = 100000000 * 1e18;          // stop burning when supply reaches 100M
    
    uint8 private _feeRewardPerMille = 10;                       // %% of a transfer that goes to rewarding wallet (and eventually will be distributed among holders); e.g. 10 == 1%
    address private _walletReward = address(0);                  // the contract address has to be set for the rewarding to take place. [TBD: vs wallet adress - to be designed]
    
    uint8 private _whaleThresholdPerMille = 10;                 // %% of curent supply that makes sender of a transfer a whale

    EnumerableSet.AddressSet private _accountsExcludedFromFee;  // the set should be used to manage exchange liquidity pool wallets etc. ; contract owner is also added here during deployment.

    // ------------------- non-managable attributes -------------------

    EnumerableSet.AddressSet private _potentialHolders;
    address[] private _holders;

    // ------------------- generated events  -------------------

    event AccountAddedToFeeExclusionList(address indexed account);        
    event AccountRemovedFromFeeExclusionList(address indexed account);    
    event WalletRewardUpdatedTo(address indexed newWalletReward);
    event MinimumSupplyUpdatedTo (uint256 newMinimumSupply);
    event FeeBurnPerMilleUpdatedTo (uint8 newFeeBurnPerMille);
    event FeeRewardPerMilleUpdatedTo (uint8 newFeeRewardPerMille);
    event WhaleThresholdPerMilleUpdatedTo (uint8 newWhaleThresholdPerMille);

    // ------------------- deployment logic  -------------------

    constructor() ERC20("A999 Token", "A999") {
        _mint(address(this), _initialSupply);
        _approve(address(this), _msgSender(), _initialSupply);
        addAddressToFeeExclusionList (_msgSender());            // exclude owner from fees
        addAddressToFeeExclusionList (address(this));            // exclude contract from fees
    }

    // ------------------- getters and setters  -------------------

    // --- initial supply

    function initialSupply() public pure returns (uint256) {
        return _initialSupply;
    }

    // --- fee burn per mille

    function feeBurnPerMille() public view returns (uint8) {
        return _feeBurnPerMille;
    }
    function setFeeBurnPerMille(uint8 newFeeBurnPerMille) public onlyOwner {
        require (newFeeBurnPerMille >= 0 && newFeeBurnPerMille <= 1000, 'A999Token: fee burn per-mille outside of <0;1000> range');
        _feeBurnPerMille = newFeeBurnPerMille;
        emit FeeBurnPerMilleUpdatedTo(newFeeBurnPerMille);
    }

    // --- fee reward per mille

    function feeRewardPerMille() public view returns (uint8) {        
        return _feeRewardPerMille;
    }
    function setFeeRewardPerMille(uint8 newFeeRewardPerMille) public onlyOwner {
        require (newFeeRewardPerMille >= 0 && newFeeRewardPerMille <= 1000, 'A999Token: fee reward per-mille outside of <0;1000> range');
        _feeRewardPerMille = newFeeRewardPerMille;
        emit FeeRewardPerMilleUpdatedTo(newFeeRewardPerMille);
    }

    // --- whale threshold per mille

    function whaleThresholdPerMille() public view returns (uint8) {        
        return _whaleThresholdPerMille;
    }
    function setWhaleThresholdPerMille(uint8 newWhaleThresholdPerMille) public onlyOwner {
        require (newWhaleThresholdPerMille >= 0 && newWhaleThresholdPerMille <= 1000, 'A999Token: whale threshold per-mille outside of <0;1000> range');
        _whaleThresholdPerMille = newWhaleThresholdPerMille;
        emit WhaleThresholdPerMilleUpdatedTo(newWhaleThresholdPerMille);
    }    

    // --- minimum supply

    function minimumSupply() public view returns (uint256) {
        return _minimumSupply;
    }    
    function setMinimumSupply(uint256 newMinimumSupply) public onlyOwner {
        require (totalSupply() >= newMinimumSupply, "A999Token: minimum supply greater than total supply");
        _minimumSupply = newMinimumSupply;
        emit MinimumSupplyUpdatedTo(newMinimumSupply);
    }

    // --- wallet reward

    function walletReward() public view returns (address) {
        return _walletReward;
    }
    function setWalletReward(address newWalletReward) public onlyOwner {
        if (_walletReward != address(0)) {
            removeAddressFromFeeExclusionList (_walletReward);
        }
        if (newWalletReward != address(0)) {
            addAddressToFeeExclusionList (newWalletReward);
        }
        _walletReward = newWalletReward;        
        emit WalletRewardUpdatedTo(newWalletReward);
    }

    // ------------------- manage account exclusion list  -------------------

    function _isSenderOrRecipientExcludedFromTransferFee (address sender, address recipient) internal view returns (bool) {
        return _accountsExcludedFromFee.contains(sender) || _accountsExcludedFromFee.contains(recipient);
    }

    function isExcludedFromTransferFee (address account) public view returns (bool) {
        return _accountsExcludedFromFee.contains(account);
    }

    function addAddressToFeeExclusionList (address addressExcluded) public onlyOwner {
        bool added = _accountsExcludedFromFee.add (addressExcluded);
        if (added)
            emit AccountAddedToFeeExclusionList (addressExcluded);            
    }

    function removeAddressFromFeeExclusionList (address addressIncluded) public onlyOwner {
        bool removed = _accountsExcludedFromFee.remove (addressIncluded);
        if (removed)
            emit AccountRemovedFromFeeExclusionList (addressIncluded);            
    }

    // ------------------- transfer custom logic -------------------

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override whenNotPaused {        
        _potentialHolders.add(to);
        super._beforeTokenTransfer(from, to, amount);
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override nonReentrant whenNotPaused {        
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(balanceOf(sender) >= amount, "ERC20: transfer amount exceeds balance");

        require(!isWhaleTransfer(sender, recipient, amount), "Whales are not welcome by 3TON community!");

        uint256 adjustedAmount = _processTransferFee(sender, recipient, amount);

        super._transfer(sender, recipient, adjustedAmount);

        // --- ensure that tokens booked in contract address will be available
        if (recipient == address(this)) {
            _approve(recipient, owner(), adjustedAmount);
        }
    }

    function _processTransferFee(address sender, address recipient, uint256 amount) internal whenNotPaused returns (uint256) {                
        // --- mind exclusion list
        if (_isSenderOrRecipientExcludedFromTransferFee (sender, recipient)) 
            return amount;

        uint256 burnAmount = amount * _feeBurnPerMille / 1000;
        uint256 rewardAmount = amount * _feeRewardPerMille / 1000;
        uint256 adjustedAmount = amount;

        // --- burn ---
        if (canBurn(burnAmount)) {
            _burn(sender, burnAmount);
            adjustedAmount -= burnAmount;
        }

        // --- reward ---
        if (_walletReward != address(0)) {                       // if the rewarding wallet is not set, the rewarding fee will not be taken from the transfer.
            super._transfer(sender, _walletReward, rewardAmount);
            adjustedAmount -= rewardAmount;
        }

        // --- amount left for the recipient
        return adjustedAmount;
    }

    function isWhaleTransfer(address sender, address recipient, uint256 amount) internal view returns (bool) {
        // accounts listed on exclusion list can't be considered as whales.
        if (_isSenderOrRecipientExcludedFromTransferFee (sender, recipient)) {
            return false;
        }         
        return amount >= totalSupply() * _whaleThresholdPerMille / 1000;
    }

    // ------------------- arsonist alley -------------------
    
    function burn(uint256 amount) external nonReentrant whenNotPaused {
        require (isBurningAllowed(), "A999Token: the total supply has already reached its minimum");
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) public whenNotPaused {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "A999Token: burn amount exceeds allowance");
        _approve(account, _msgSender(), currentAllowance - amount);
        _burn(account, amount);
    }

    function _burn(address account, uint256 amount) internal override whenNotPaused {        
        require (canBurn(amount), "A999Token: buring this amount would decrease the total supply below defined minimum");
        super._burn(account, amount);
    }

    function applyPhoenixProtocol (uint256 amount) public nonReentrant onlyOwner whenNotPaused {
        require (totalSupply() + amount > _initialSupply, "A999Token: cannot exceed initial supply");
        _mint(address(this), amount);
        _approve(address(this), owner(), amount);
    }

    function _maxBurningAmount() internal view returns (uint256){
        return totalSupply() - _minimumSupply;
    }

    function isBurningAllowed() public view returns (bool){
        return _maxBurningAmount() > 0;
    }

    function canBurn(uint256 amount) public view returns (bool){
        return _maxBurningAmount() >= amount;
    }
    
    // ------------------- emergency - pause / unpase the contract  -------------------

    // the pausing affects only methods with whenNotPaused / whenPaused modifiers:
    // transfers, burning, minting

    function emergencyPause() public onlyOwner {
        _pause();
    }

    function emergencyUnpause() public onlyOwner {
        _unpause();
    }

    // ------------------- bulk tokens distribution -------------------

    function distributeContractTokens(address[] memory receivers, uint256[] memory amounts) public onlyOwner whenNotPaused {
        _distribute (address(this), receivers, amounts);
    }

    function distributeMyTokens(address[] memory receivers, uint256[] memory amounts) public whenNotPaused {
        _distribute (_msgSender(), receivers, amounts);
    }

    function _distribute(address source, address[] memory receivers, uint256[] memory amounts) internal whenNotPaused {
        for(uint8 i = 0; i < receivers.length; i++) {
            super._transfer(source, receivers[i], amounts[i]);
        }
    }
    
    // ------------------- retrieve holders eligible for reward -------------------

    function getHolders (uint256 minimalHoldings) public returns (address[] memory) {
        delete _holders;
        for (uint256 i = 0; i < _potentialHolders.length(); i++) {
            address potentialHolder = _potentialHolders.at(i);
            if (balanceOf(potentialHolder) >= minimalHoldings) {
                _holders.push(potentialHolder);
            }
        }
        return _holders;
    }
}