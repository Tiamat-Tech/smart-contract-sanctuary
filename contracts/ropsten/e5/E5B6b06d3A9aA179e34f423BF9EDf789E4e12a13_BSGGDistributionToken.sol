// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BSGGDistributionToken is ERC721, ERC721Enumerable, Pausable, Ownable {
    uint32 public ticketCounter;
    uint32 public ticketTypeCounter;
    bool public fireAlarm;
    IERC20 public immutable BSGG;

    struct Ticket {
        uint32 id;
        uint32 ticketType;
        uint32 mintTimestamp;
        uint32 lockedToTimestamp;
        uint128 amountLocked;
        uint128 amountToGain;
    }

    struct TicketType {
        uint32 id;
        bool active;
        uint128 minLockAmount;
        uint32 lockDuration;
        uint32 gainMultiplier;
        uint128 BSGGAllocation;
        uint128 BSGGAllTimeAllocation;
        uint128 BSGGTotalTokensLocked;
        uint128 APR;
    }

    struct UserInfoFrontend {
        Ticket[] userTickets;
        uint allocatedBSGG;
        uint pendingBSGGEarning;
    }

    mapping(uint => Ticket) public tickets;
    mapping(uint => TicketType) public ticketTypes;
    
    event TicketBought(address owner, uint ticketId, uint stakeAmount, uint gainAmount, uint lockDuration);
    event TicketRedeemed(address owner, uint ticketId);
    event AllocatedNewBSGG(uint amount, uint ticketTypeId);

    modifier allGood(){
        require(!fireAlarm, "Fire alarm activated. Use emergency withdraw");
        _;
    }

    modifier alarmed(){
        require(fireAlarm, "Fire alarm not activated");
        _;
    }

    constructor(IERC20 _BSGG) ERC721("BSGGDistributionToken", "BSGGDist") {
        BSGG = _BSGG;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /** @dev Allows to fund BSGG to this contract
        as reward allocation (for cetain ticket type).
    */
    function allocateBSGG(uint128 _amount, uint _ticketTypeId) external onlyOwner allGood {
        require(_ticketTypeId < ticketTypeCounter, "Bad ticket type");
        ticketTypes[_ticketTypeId].BSGGAllocation += _amount;
        ticketTypes[_ticketTypeId].BSGGAllTimeAllocation += _amount;
        BSGG.transferFrom(msg.sender, address(this), _amount);
        emit AllocatedNewBSGG(_amount, _ticketTypeId);
    }

    /// @dev Creates a new ticket type.
    function addTicketType(
        uint128 _minLockAmount,
        uint32 _lockDuration,
        uint32 _gainMultiplier
    ) external onlyOwner allGood{
        require(_minLockAmount >= 1 ether, "Bad minimum lock amount");
        require(_lockDuration >= 1 hours, "Lock duration too short");
        require(_gainMultiplier > 0, "Gain multiplier lower or equal to base");

        ticketTypes[ticketTypeCounter].id               = ticketTypeCounter;
        ticketTypes[ticketTypeCounter].active           = true;
        ticketTypes[ticketTypeCounter].minLockAmount    = _minLockAmount;
        ticketTypes[ticketTypeCounter].lockDuration     = _lockDuration;
        ticketTypes[ticketTypeCounter].gainMultiplier   = _gainMultiplier;
        ticketTypes[ticketTypeCounter].APR              = _gainMultiplier * (365 * 86400 / _lockDuration);

        ticketTypeCounter++;
    }

    /// @dev Update ticket type. Not affect already bought tickets.
    function updateTicketType(
        uint32 _id,
        uint32 _minLockAmount,
        uint32 _lockDuration,
        uint32 _gainMultiplier
    ) external onlyOwner allGood{
        require(_minLockAmount >= 1 ether, "Bad minimum lock amount");
        require(_lockDuration >= 1 hours, "Lock duration too short");
        require(_gainMultiplier > 0, "Gain multiplier lower or equal to base");

        TicketType storage currentTicket = ticketTypes[_id];

        currentTicket.minLockAmount    = _minLockAmount;
        currentTicket.lockDuration     = _lockDuration;
        currentTicket.gainMultiplier   = _gainMultiplier;
        currentTicket.APR              = _gainMultiplier * (365 * 86400) / _lockDuration;
    }

    /// @dev Deactivates a selected ticket type.
    function deactivateTicketType(uint _ticketTypeId) external onlyOwner allGood{
        ticketTypes[_ticketTypeId].active = false;
    }

    /// @dev Activates a selected ticket type.
    function activateTicketType(uint _ticketTypeId) external onlyOwner allGood{
        require( _ticketTypeId < ticketTypeCounter, "Non existent ticket type id");
        ticketTypes[_ticketTypeId].active = true;
    }

    /// @notice Stakes and locks BSGG
    function buyTicket(
        uint128 _amount, 
        uint32 _ticketTypeId, 
        address _to
    ) external whenNotPaused allGood{
        TicketType memory currentTicketType = ticketTypes[_ticketTypeId];
        require(currentTicketType.active, "Bad ticket");
        require(_amount >= currentTicketType.minLockAmount, "Too small stake amount");
        require(BSGG.transferFrom(msg.sender, address(this), _amount), "Tokens not transferred");
        uint32 ticketId = ++ticketCounter;

        tickets[ticketId].id                 = ticketId;
        tickets[ticketId].ticketType         = _ticketTypeId;
        tickets[ticketId].mintTimestamp      = uint32(block.timestamp);
        tickets[ticketId].lockedToTimestamp  = uint32(block.timestamp + currentTicketType.lockDuration);
        tickets[ticketId].amountLocked       = _amount;
        tickets[ticketId].amountToGain       = _amount * currentTicketType.gainMultiplier / 1e6;

        require(tickets[ticketId].amountToGain <= ticketTypes[_ticketTypeId].BSGGAllocation, "Sold out");

        ticketTypes[_ticketTypeId].BSGGTotalTokensLocked += _amount;
        ticketTypes[_ticketTypeId].BSGGAllocation -= tickets[ticketId].amountToGain;

        _safeMint(_to, ticketId);

        emit TicketBought(
            _to, 
            ticketId, 
            _amount,
            tickets[ticketId].amountToGain, 
            currentTicketType.lockDuration
        );
    }

    /** @notice Unlocks and sends staked tokens and rewards to staker
        (with or without penalties depending on the time passed).
    */
    function redeemTicket(uint _ticketId) external allGood{
        require( ownerOf(_ticketId) == msg.sender, "Not token owner");
        Ticket memory currentTicket = tickets[_ticketId];
        (uint pendingStakeAmountToWithdraw, uint pendingRewardTokensToClaim) = getPendingTokens(_ticketId);
        uint totalAmountToWithdraw = pendingStakeAmountToWithdraw + pendingRewardTokensToClaim;
        uint totalAmountToReAllocate = currentTicket.amountLocked + currentTicket.amountToGain - totalAmountToWithdraw;

        ticketTypes[currentTicket.ticketType].BSGGAllocation += uint128(totalAmountToReAllocate);
        ticketTypes[currentTicket.ticketType].BSGGTotalTokensLocked -= currentTicket.amountLocked;

        delete tickets[_ticketId];
        _burn(_ticketId);

        BSGG.transfer(msg.sender, totalAmountToWithdraw);
        emit TicketRedeemed(msg.sender, _ticketId);
    }

    /// @dev returns amount of stake and reward tokens that the user receives in case of unlocking.
    function getPendingTokens(uint _ticketId) public view returns (uint stakeAmount, uint rewardAmount) {
        Ticket memory currentTicket = tickets[_ticketId];
        uint lockDuration = currentTicket.lockedToTimestamp - currentTicket.mintTimestamp;
        uint halfPeriodTimestamp = currentTicket.lockedToTimestamp - lockDuration / 2;

        if (block.timestamp < currentTicket.lockedToTimestamp){
            stakeAmount = currentTicket.amountLocked * 950000 / 1e6; // 5% penalty applied to staked amount
            if (block.timestamp >= halfPeriodTimestamp){
                uint pendingReward = _calculatePendingRewards(
                    block.timestamp,
                    currentTicket.mintTimestamp,
                    currentTicket.lockedToTimestamp,
                    currentTicket.amountToGain
                );
                rewardAmount = pendingReward / 2; // The user can get 50% of pending rewards
            }
        }else{
            // Lock period is over. The user can receive all staked and reward tokens.
            stakeAmount = currentTicket.amountLocked;
            rewardAmount = currentTicket.amountToGain;
        }
    }

    /// @dev Checks pending rewards by the date. Returns 0 in deleted ticket Id
    function getPendingRewards(uint _ticketId) public view returns (uint amount){
        Ticket memory currentTicket = tickets[_ticketId];
        amount = _calculatePendingRewards(
            block.timestamp < currentTicket.lockedToTimestamp ? block.timestamp : currentTicket.lockedToTimestamp,
            currentTicket.mintTimestamp,
            currentTicket.lockedToTimestamp,
            currentTicket.amountToGain
        );
    }

    /// @dev Outputs parameters of all user tickets 
    function getUserInfo(address _user) external view returns(UserInfoFrontend memory userInfo){
        uint countOfTicket = balanceOf(_user);
        Ticket[] memory userTickets = new Ticket[](countOfTicket);
        uint allocatedBSGG;
        uint pendingBSGGEarning;

        for (uint i = 0; i < countOfTicket; i++){
            uint ticketId = tokenOfOwnerByIndex(_user, i);
            Ticket memory currentTicket = tickets[ticketId];
            userTickets[i] = currentTicket;
            allocatedBSGG += currentTicket.amountLocked;
            pendingBSGGEarning += getPendingRewards(ticketId);
        }

        userInfo.userTickets = userTickets;
        userInfo.allocatedBSGG = allocatedBSGG;
        userInfo.pendingBSGGEarning = pendingBSGGEarning;
    }

    /// @dev Returns all available tickets and their parameters 
    function getTicketTypes() external view returns(TicketType[] memory allTicketTypes){
        allTicketTypes = new TicketType[](ticketTypeCounter);
        for (uint i = 0; i < ticketTypeCounter; i++) {
            allTicketTypes[i] = ticketTypes[i];
        }
    }

    /// @dev TVL across all pools
    function getTotalTokensLocked() public view returns(uint TVL){
        for (uint i = 0; i < ticketTypeCounter; i++) {
            TVL += ticketTypes[i].BSGGTotalTokensLocked;
        }
    }

    /// @dev Sets emergency state
    /// 'code' requiered in case of unaccidentaly calling this function
    function triggerFireAlarm(uint code) external onlyOwner{
        require(code == 111000111, "You need write 111000111");

        uint availableBalance = BSGG.balanceOf(address(this)); 
        uint withdrawAmount = getTotalTokensLocked() > availableBalance ? 0 : availableBalance - getTotalTokensLocked();
        if (withdrawAmount > 0) BSGG.transfer(msg.sender, withdrawAmount);
        
        fireAlarm = true;
        _pause();
    }
    
    /// @notice Redeem tokens without penalties
    function emergencyWithdraw() external alarmed{
        uint userTicketsCount = balanceOf(msg.sender);
        
        for(uint i = 0; i < userTicketsCount; i++){
            uint ticketId = tokenOfOwnerByIndex(msg.sender, i);
            uint availableBalance = BSGG.balanceOf(address(this));
            uint withdrawAmountPossible = tickets[ticketId].amountLocked > availableBalance ? availableBalance : tickets[ticketId].amountLocked;
            BSGG.transfer(msg.sender, withdrawAmountPossible);
        }
    }

    /// @dev Calculates pending rewards 
    function _calculatePendingRewards(
        uint timestamp,
        uint mintTimestamp,
        uint lockedToTimestamp,
        uint amountToGain
    ) pure internal returns (uint amount){
        return amountToGain * (timestamp - mintTimestamp) / (lockedToTimestamp - mintTimestamp);
    }

    /// @dev Allows Owner to withdraw a ticket's BSGG allocation excluding staker rewards 
    function withdrawNonReservedBSGG(uint128 _amount, uint _ticketTypeId) external onlyOwner{
        TicketType storage currentTicketType = ticketTypes[_ticketTypeId];
        uint128 withdrawAmount = currentTicketType.BSGGAllocation >= _amount ? _amount : currentTicketType.BSGGAllocation;
        currentTicketType.BSGGAllTimeAllocation -= withdrawAmount;
        currentTicketType.BSGGAllocation -= withdrawAmount;
        BSGG.transfer(msg.sender, withdrawAmount);
    }
    
    function _beforeTokenTransfer(address from, address to, uint ticketId) internal override(ERC721, ERC721Enumerable){
        super._beforeTokenTransfer(from, to, ticketId);
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool){
        return super.supportsInterface(interfaceId);
    }
}