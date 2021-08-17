/// SPDX-License-Identifier: GNU General Public License v3.0

pragma solidity 0.8.0;

import "@openzeppelin/contracts/proxy/Clones.sol";
import "./interface/ITournament.sol";
import "./interface/IRegistry.sol";


contract TournamentFactory {

    /***************
    GLOBAL VARIABLES
    ***************/
    IRegistry public registry;

    address private _owner;

    uint16 constant public MIN_VOTING_PERIOD = 3600; // 1 hour

    /***************
    EVENTS
    ***************/
    event BalanceWithdrawn(uint256 indexed amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event TournamentCreated(address indexed creator, address indexed tournamentAddr);

    /***************
    MODIFIERS
    ***************/
    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    /***************
    FUNCTIONS
    ***************/

    /// @dev Contructor sets the Pool implementation contract's address
    /// @param _registry The address for the Registry contract
    /// @param _implementation The address for the Tournament implementation contract
    constructor(address _registry, address _implementation) {
        registry = IRegistry(_registry);
        registry.setTournamentFactoryAddress(address(this));
        registry.setTournamentAddress(_implementation);
        _owner = msg.sender;
    }

    /** @dev Creates a Tournament with custom parameters
     * Creator must pay tournament creation fee of 0.005 ETH
     * @param startTime Start time of the tournament (NFT submission deadline)
     * @param bracketSize Maximum size of the bracket. Reverts if invalid (not a sq. num)
     * @param votingPeriod How much time users have to vote in each round (seconds)
     * @param whitelistedNFT (Optional) Allows Tournament creators to limit the Tournament to one type of NFT
     * @return Address of the new Tournament
    */
    function createTournament(
        uint256 startTime,
        uint256 votingPeriod,
        uint8 bracketSize,
        address whitelistedNFT
    )
        external
        payable
        returns (address)

    {
        require(startTime > block.timestamp, "startTime must be greater than now");
        require(votingPeriod >= MIN_VOTING_PERIOD, "votingPeriod must be at least 1 hour");
        require(msg.value == 0.005 ether, "tournament creation fee is 0.005 ETH");

        uint8[7] memory validBracketSizes = [2, 4, 8, 16, 32, 64, 128];

        // check bracketSize validity
        for (uint256 i = 0; i < 7; i++) {
            if (validBracketSizes[i] == bracketSize) {
                break;
            } else if (i == 6) {
                revert("bracketSize must be a square num <= 128");
            }
        }

        address tournament = Clones.clone(registry.tournament());
        ITournament(tournament).initialize(startTime, votingPeriod, bracketSize, whitelistedNFT, address(registry), msg.sender);

        emit TournamentCreated(msg.sender, tournament);
        
        return tournament;

    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     * @param newOwner address to transfer ownership privileges to.
     */
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    /**
     * @dev Transfers contract balance (from tournament creation fees) to owner
     * Can only be called by the current owner.
     */
    function withdrawBalance() external onlyOwner {
        uint256 amount = address(this).balance;
        
        emit BalanceWithdrawn(amount);
        
        payable(msg.sender).transfer(amount);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() external view returns (address) {
        return _owner;
    }
    
}