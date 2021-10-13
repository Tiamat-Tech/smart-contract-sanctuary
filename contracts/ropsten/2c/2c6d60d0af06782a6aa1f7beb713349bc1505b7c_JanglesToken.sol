// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/**


 */

//** OpenZeppelin Dependencies Upgradeable */
import '@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol';
//** OpenZepplin non-upgradeable */
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import './abstracts/Pausable.sol';

import 'hardhat/console.sol';

// Dependencies

contract JanglesToken is
    ERC20Upgradeable,
    AccessControlUpgradeable,
    OwnableUpgradeable,
    Pausable
{
    // Using
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    // Structs
    struct Multipliers {
        uint64 rare;
        uint64 count;
        uint64 maxNft;
        uint64 _gap;
    }

    //** Role Variables */
    bytes32 private constant MINTER_ROLE = keccak256('MINTER_ROLE');

    // Variables for mint for hold
    uint256 public start;
    uint256 public janglesPerSecond;
    address private signer;
    uint256 maxClaimTime;
    // Contracts
    IERC721EnumerableUpgradeable public bojangles;
    // Sets Structs n Mappings
    Multipliers multipliers;
    mapping(uint256 => uint256) public lastClaimOnNft;
    mapping(address => uint256) public slothClaimers;
    EnumerableSetUpgradeable.UintSet internal rares;

    //** Role Modifiers */
    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, _msgSender()), 'Caller is not a minter');
        _;
    }

    //** Initialize functions */
    function initialize(
        string memory _name,
        string memory _symbol,
        address _bojangles
    ) public initializer {
        __ERC20_init(_name, _symbol);
        __Ownable_init(); // Contract creator becomes owner
        __Pausable_init(); // Contract creator becomes pauser
        // Basic variable setters
        bojangles = IERC721EnumerableUpgradeable(_bojangles);
        janglesPerSecond = (1 * 1e18);
        janglesPerSecond = janglesPerSecond / 86400;
        start = block.timestamp;
        multipliers = Multipliers({rare: 200, count: 10, maxNft: 11, _gap: 0});
        maxClaimTime = block.timestamp + 86400 * 180; // 6months
        // add in rares
        rares.add(947);
        rares.add(858);
        rares.add(133);
        rares.add(1000);
        rares.add(732);
        rares.add(24);
        rares.add(625);
        rares.add(40);
        rares.add(264);
        rares.add(343);
        // Supply
        uint256 initialSupply = 1e6 * 1e18; // 1million
        _mint(owner(), initialSupply);

        emit Transfer(address(0), _msgSender(), initialSupply);
    }

    /** @dev addMinters: Allow lPool to become a minter. Can add more for other pools / farms in future 
        @param instances {address[]}
    */
    function addMinters(address[] calldata instances) external onlyOwner {
        for (uint256 index = 0; index < instances.length; index++) {
            _setupRole(MINTER_ROLE, instances[index]);
        }
    }

    /** @dev mint:Staking portal will have the ability to mint. 
        @param to {address}
        @param amount {uint256}
    */
    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    /** @dev mintForUser: Hold NFT to mint tokens. 
        @param user {address}

        note: Anybody can call this function for any user. #goodAccounting? :kek:
    */
    function mintForUser(address user) external {
        uint256 total = bojangles.balanceOf(user);
        uint256 owed = 0;
        for (uint256 i = 0; i < total; i++) {
            uint256 id = bojangles.tokenOfOwnerByIndex(user, i);
            uint256 claimed = lastClaim(id);
            if (rares.contains(id)) {
                owed += ((block.timestamp - claimed) *
                    ((janglesPerSecond * multipliers.rare) / 100));
            } else {
                owed += ((block.timestamp - claimed) * janglesPerSecond);
            }
            lastClaimOnNft[id] = block.timestamp;
        }
        uint256 multiplier =
            90 +
                MathUpgradeable.min(total, multipliers.maxNft) *
                multipliers.count;
        owed = (owed * multiplier) / 100;

        _mint(user, owed);
    }

    /** @dev userOwed: FrontendFunction....
        @param user {address}
    */
    function userOwed(address user) external view returns (uint256) {
        uint256 total = bojangles.balanceOf(user);
        uint256 owed = 0;
        for (uint256 i = 0; i < total; i++) {
            uint256 id = bojangles.tokenOfOwnerByIndex(user, i);
            uint256 claimed = lastClaim(id);
            if (rares.contains(id)) {
                owed += ((block.timestamp - claimed) *
                    ((janglesPerSecond * multipliers.rare) / 100));
            } else {
                owed += ((block.timestamp - claimed) * janglesPerSecond);
            }
        }
        uint256 multiplier =
            90 +
                MathUpgradeable.min(total, multipliers.maxNft) *
                multipliers.count;
        owed = (owed * multiplier) / 100;

        return owed;
    }

    /** @dev claim: Sleepy Sloth Holders will have the ability to 
        @param signature {bytes}
        @param _amount {uint256}
     */
    function claim(bytes memory signature, uint256 _amount) external {
        require(maxClaimTime > block.timestamp, 'CLAIM: Time has passed bud.');
        bytes32 messageHash = sha256(abi.encode(msg.sender, _amount));
        bool recovered =
            ECDSAUpgradeable.recover(messageHash, signature) == signer;

        require(recovered == true, 'CLAIM: Record not found bud.');
        require(
            slothClaimers[msg.sender] == 0,
            "CLAIM: You can't claim twice there bud."
        );
        slothClaimers[msg.sender] = _amount;

        _mint(msg.sender, _amount);
    }

    /** Getters -------------------------------- */
    function lastClaim(uint256 id) public view returns (uint256) {
        return MathUpgradeable.max(lastClaimOnNft[id], start);
    }

    /** Setters -------------------------------- */

    /** @dev set signer: Signer is address that created claims
        @param _signer {address}
     */
    function setSigner(address _signer) external onlyOwner {
        signer = _signer;
    }

    /** @dev set rare multiplier: Multiplier for rare nft set
        @param multiplier {uint64}

        note: starts at 100 for 1:1 with normal
     */
    function setRareMultiplier(uint64 multiplier) external onlyOwner {
        multipliers.rare = multiplier;
    }

    /** @dev set count multiplier: # of bojangles multiplier
        @param multiplier {uint64}

        note: setting to 10 means if user has 11 nfts they get 200% extra.
     */
    function setCountMultiplier(uint64 multiplier) external onlyOwner {
        multipliers.count = multiplier;
    }

    /** @dev set max nft multiplier: # nfts until multiplier cuts off
        @param multiplier {uint64}
     */
    function setMaxNftMultiplier(uint64 multiplier) external onlyOwner {
        multipliers.maxNft = multiplier;
    }

    /** @dev setMultiplier: Look at previous FN's for details on each params.
        @param rare {uint64}
        @param count {uint64}
        @param maxNft {uint64}
     */
    function setMultiplier(
        uint64 rare,
        uint64 count,
        uint64 maxNft
    ) external onlyOwner {
        multipliers = Multipliers({
            rare: rare,
            count: count,
            maxNft: maxNft,
            _gap: 0
        });
    }

    /** For testing purposes only. */
    function addRare(uint256 rareId) external onlyOwner {
        require(block.number <= 1000, 'TOKEN: Not hardhat');
        rares.add(rareId);
    }

    //to recieve ETH
    receive() external payable {}
}