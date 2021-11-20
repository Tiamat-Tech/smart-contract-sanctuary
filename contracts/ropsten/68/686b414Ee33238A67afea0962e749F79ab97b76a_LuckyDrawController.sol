// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;


import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


/// @title Contract for handling lucky draws
/// @author Alexis Tay
/// @notice Contract used for creating lucky draws, submitting entries, and picking winners.
/// @dev Uses a commit reveal scheme to pick winners. Entries are salted, hashed and committed to the blockchain. The winner is picked, and the salt is then revealed.
/// @dev inherits from Ownable and Pausable [Only the owner can pause the contract]
contract LuckyDrawController is Ownable, Pausable {
    
    /// @notice Emitted when state of the lucky draw controller is changed.
    /// @param paused Boolean that indicates whether the contract is paused or not.
    event LuckyDrawStateChange(bool paused);

    /// @notice Pauses the contract.
    /// @dev This function is only accessible by the owner.
    function pause() public onlyOwner {
        _pause();
        emit LuckyDrawStateChange(true);
    }

    /// @notice Unpauses the contract.
    /// @dev This function is only accessible by the owner.
    function unpause() public onlyOwner {
        _unpause();
        emit LuckyDrawStateChange(false);
    }

    struct LuckyDraw {
        address owner;
        string name;
        bytes32 entries;
        string entriesIPFScid;
        uint256 numEntries;
        string salt;
        uint256[] winners;
        LuckyDrawState luckyDrawState;
    }

    enum LuckyDrawState {
        Created,
        EntriesSet,
        WinnerSet,
        SaltSet
    }
    
    /// @notice Array of all the lucky draws
    LuckyDraw[] public luckyDraws;

    /// @notice Emitted when lucky draw is created
    /// @param luckyDrawId Index of the lucky draw
    /// @param luckyDraw Lucky draw that was created
    event LuckyDrawCreated(uint256 luckyDrawId, LuckyDraw luckyDraw);

    /// @notice Emitted when entries of lucky draw is set
    /// @param luckyDraw Lucky draw that had its entries set
    event LuckyDrawEntriesSet(LuckyDraw luckyDraw);
     
    /// @notice Emitted when new winner of lucky draw is picked
    /// @param luckyDraw Lucky draw that had its winner picked
    event LuckyDrawWinnerPicked(LuckyDraw luckyDraw);

    /// @notice Emitted when salt of lucky draw is set
    /// @param luckyDraw Lucky draw that had its salt set
    event LuckyDrawSaltSet(LuckyDraw luckyDraw);

    /// @notice Creates a new lucky draw
    /// @param _name Name of the lucky draw
    function createLuckyDraw(string memory _name) public whenNotPaused() {
        LuckyDraw memory luckyDraw;
        luckyDraw.owner = msg.sender;
        luckyDraw.name = _name;
        luckyDraws.push(luckyDraw);
        emit LuckyDrawCreated(luckyDraws.length-1, luckyDraw);
    }    
    
    /// @notice Ensures that only lucky draw owner can operate on the lucky draw
    /// @param _luckyDrawId Index of the lucky draw
    modifier onlyLuckyDrawOwner(uint256 _luckyDrawId) {
        require (msg.sender == luckyDraws[_luckyDrawId].owner, "Not owner");
        _;
    }
    
    /// @notice Sets the entries of the lucky draw
    /// @param _luckyDrawId Index of the lucky draw
    /// @param _entries Entries of the lucky draw (hash of the concatenated salted hashed entries)
    /// @param _entriesIPFScid  PFS cid of the concatenated salted hashed entries
    /// @param _numEntries Number of entries
    /// @dev The actual entries on IPFS. Only the hash of the concatenated salted hashed entries is stored on the blockchain.
    function setEntries(uint256 _luckyDrawId, bytes32 _entries, string memory _entriesIPFScid, uint256 _numEntries) 
            public whenNotPaused() onlyLuckyDrawOwner(_luckyDrawId) {
        require(luckyDraws[_luckyDrawId].luckyDrawState == LuckyDrawState.Created, "State not Created");
        luckyDraws[_luckyDrawId].entries = _entries;
        luckyDraws[_luckyDrawId].entriesIPFScid = _entriesIPFScid;
        luckyDraws[_luckyDrawId].numEntries = _numEntries;

        luckyDraws[_luckyDrawId].luckyDrawState = LuckyDrawState.EntriesSet;
        emit LuckyDrawEntriesSet(luckyDraws[_luckyDrawId]);
    }
    
    /// @notice Picks a winner of the lucky draw
    /// @param _luckyDrawId Index of the lucky draw
    function pickWinner(uint256 _luckyDrawId) 
            public whenNotPaused() onlyLuckyDrawOwner(_luckyDrawId) {
        require(luckyDraws[_luckyDrawId].luckyDrawState != LuckyDrawState.Created, "State cannot be Created"); // need entries
        require(luckyDraws[_luckyDrawId].luckyDrawState != LuckyDrawState.SaltSet, "State cannot be SaltSet"); // cannot pick winner if salt is set

        uint256 winner =  uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _luckyDrawId, luckyDraws[_luckyDrawId].winners.length))) % luckyDraws[_luckyDrawId].numEntries;
        luckyDraws[_luckyDrawId].winners.push(winner);

        luckyDraws[_luckyDrawId].luckyDrawState = LuckyDrawState.WinnerSet;
        emit LuckyDrawWinnerPicked(luckyDraws[_luckyDrawId]);
    }

    /// @notice Sets the salt of the lucky draw
    /// @param  _luckyDrawId Index of the lucky draw
    /// @param  _salt Salt of the lucky draw
    function setSalt(uint256 _luckyDrawId, string memory _salt) 
            public whenNotPaused() onlyLuckyDrawOwner(_luckyDrawId) {
        require(luckyDraws[_luckyDrawId].luckyDrawState == LuckyDrawState.WinnerSet, "State not WinnerSet");
        luckyDraws[_luckyDrawId].salt = _salt;
        luckyDraws[_luckyDrawId].luckyDrawState = LuckyDrawState.SaltSet;
        emit LuckyDrawSaltSet(luckyDraws[_luckyDrawId]);
    }

    /// @notice Returns the number of lucky draws
    /// @return Number of lucky draws
    function getNumluckyDraws() public view returns (uint256) {
        return luckyDraws.length;
    }

    /// @notice Returns the lucky draw ids that belong to the given address
    /// @return array of lucky draw ids
    /// @dev Loops thru the array once to get the number of lucky draws that belong to the given address, and then populate the array with the lucky draw ids.
    function getLuckyDrawIds() public view returns (uint256[] memory  ) {
        uint256 length;
        length = 0;
        for (uint256 i = 0; i < luckyDraws.length; i++) {
            if (luckyDraws[i].owner == msg.sender) {
                length++;
            }
        }
        uint[] memory luckyDrawIds = new uint256[](length);
        length = 0;
        for (uint256 i = 0; i < luckyDraws.length; i++) {
            if (luckyDraws[i].owner == msg.sender) {
                luckyDrawIds[length] = i;
                length++;
            }
        }
        return luckyDrawIds;
    }   

    /// @notice Returns the lucky draw with the given id
    /// @param _luckyDrawId Index of the lucky draw
    /// @return luckyDraw Lucky draw with the given id
    function getLuckyDraw(uint256 _luckyDrawId) public view returns (LuckyDraw memory luckyDraw) {
        luckyDraw = luckyDraws[_luckyDrawId];
    }
    
    /// @notice Returns the entries of the lucky draw with the given id
    /// @param _luckyDrawId Index of the lucky draw
    /// @return entries Hash of the concatenated salted hashed entries
    function getEntries(uint256 _luckyDrawId) public view returns (bytes32 entries) {
        entries = luckyDraws[_luckyDrawId].entries;
    }
    
    /// @notice Returns the winners of the lucky draw with the given id
    /// @param _luckyDrawId Index of the lucky draw
    /// @return winners Winners of the lucky draw
    function getWinners(uint256 _luckyDrawId) public view returns (uint256[] memory winners) {
        winners = luckyDraws[_luckyDrawId].winners;
    }
    
}