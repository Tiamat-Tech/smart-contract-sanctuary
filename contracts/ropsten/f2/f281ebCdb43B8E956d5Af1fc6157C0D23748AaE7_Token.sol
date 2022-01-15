pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../node_modules/@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IPT.sol";
import "../interfaces/IArena.sol";

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
        // benefit is lost if 'b' is also tested.
        // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers. Reverts with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

//SPDX-License-Identifier: MIT

contract Token is ERC721, Ownable {
    using SafeMath for uint256;
    using Strings for uint256;
    // mint price
    uint256 public MINT_PRICE = .068850 ether;
    uint256 public points;
    uint8 public gamePhase = 0; //0-255
    uint256 public gpCost = 100;
    bool public paused = false;
    uint256 public stakeTime = 5 minutes;
    uint256 public maxSupply = 10000;
    address public teamAddress;

    string public baseURI;
    string public baseExtension = ".json";
    // reference to $GP for burning on mint
    IPT public pToken;
    // reference to the Arena
    IArena public arena;
    // Tracks the last block and timestamp that a caller has written to state.
    // Disallow some access to functions if they occur while a change is being written.
    mapping(address => LastWrite) private lastWriteAddress;
    mapping(uint256 => LastWrite) private lastWriteToken;

    // maps tokenId to stake
    mapping(uint256 => Stake) private staked;

    struct LastWrite {
        uint64 time;
        uint64 blockNum;
    }
    uint256 private numPetsStaked;
    // struct to store a stake's token, owner, and the time it's staked at
    struct Stake {
        uint256 tokenId;
        uint80 stakedAt;
        address owner;
    }
    struct Pet {
        uint256 strength;
        uint256 magic;
        uint256 dexterity;
        uint256 wisdom;
        uint256 intelligence;
    }

    uint256 nextId = 1;

    mapping(uint256 => Pet) private _tokenDetails;

    constructor(
        string memory name,
        string memory symbol,
        string memory _initBaseURI,
        uint256 _points,
        address _teamAddress
    ) ERC721(name, symbol) {
        setBaseURI(_initBaseURI);
        points = _points;
        teamAddress = _teamAddress;
    }

    /** CRITICAL TO SETUP */

    modifier requireContractsSet() {
        require(
            address(pToken) != address(0) && address(arena) != address(0),
            "Contracts not set"
        );
        _;
    }

    //to recieve ETH
    receive() external payable {}

    function setContracts(address _pt, address _arena) external onlyOwner {
        pToken = IPT(_pt);
        arena = IArena(_arena);
    }

    function getTokenDetails(uint256 tokenId)
        external
        view
        returns (Pet memory)
    {
        // was public
        return _tokenDetails[tokenId];
    }

    //only owner
    function setgamePhase(uint8 _newGamePhase) public onlyOwner {
        gamePhase = _newGamePhase;
    }

    //only owner
    function setCost(uint256 _newPrice) public onlyOwner {
        MINT_PRICE = _newPrice;
    }

    //only owner
    function setPleyerPoints(uint256 _newPoints) public onlyOwner {
        points = _newPoints;
    }

    //only owner
    function pause(bool _state) public onlyOwner {
        paused = _state;
    }

    //only owner
    function setStakeTime(uint256 _stakeTime) external onlyOwner {
        stakeTime = _stakeTime;
    }

    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    function setMaxMaxSupply(uint256 _newMaxSupply) public onlyOwner {
        maxSupply = _newMaxSupply;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    function mint(
        uint256 strength,
        uint256 magic,
        uint256 dexterity,
        uint256 wisdom,
        uint256 intelligence
    ) public onlyOwner {
        _tokenDetails[nextId] = Pet(
            strength,
            magic,
            dexterity,
            wisdom,
            intelligence
        );
        _safeMint(msg.sender, nextId);
        nextId++;
    }

    function updateCost(uint256 supply)
        internal
        view
        returns (uint256 _mintCost)
    {
        if (supply < 1500) {
            return 0.075 ether;
        }
        if (supply < 4000) {
            return 0.01 ether;
        }
        if (supply < maxSupply) {
            return 0.15 ether;
        }
    }

    function playerMint(
        uint256 strength,
        uint256 magic,
        uint256 dexterity,
        uint256 wisdom,
        uint256 intelligence
    ) external payable {
        uint256 totalPoints = strength +
            magic +
            dexterity +
            wisdom +
            intelligence;
        require(!paused);
        require(nextId <= maxSupply);
        // EOA: Externally Owned Account, not a wallet contract.
        // there are two types of accounts, externally owned accounts,
        // controlled by private keys, and contract accounts, controlled by their contract code.
        require(tx.origin == _msgSender(), "Only EOA");
        require(totalPoints == points, "Invalid points");
        require(updateCost(nextId) == msg.value, "Invalid payment amount");
        _tokenDetails[nextId] = Pet(
            strength,
            magic,
            dexterity,
            wisdom,
            intelligence
        );
        _safeMint(msg.sender, nextId);

        uint256 balance = msg.value;
        uint256 prize = balance.div(10); // 10% of mint price
        uint256 forTeam = balance.sub(prize); // 90% of mint price
        payable(address(arena)).transfer(prize); //10% of mint price sent as prize
        payable(teamAddress).transfer(forTeam); //90% of mint price sent to team

        nextId++;
    }

    /**
     * allows owner to send funds to the arena
     */
    function sendAllEthToArena() external onlyOwner {
        payable(address(arena)).transfer(address(this).balance);
    }

    /** EXTERNAL */

    function getTokenWriteBlock(uint256 tokenId)
        external
        view
        returns (uint64)
    {
        //require(admins[_msgSender()], "Only admins can call this");
        return lastWriteToken[tokenId].blockNum;
    }

    function updateOriginAccess(uint256[] memory tokenIds) external {
        //require(admins[_msgSender()], "Only admins can call this");
        uint64 blockNum = uint64(block.number);
        uint64 time = uint64(block.timestamp);
        lastWriteAddress[tx.origin] = LastWrite(time, blockNum);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            lastWriteToken[tokenIds[i]] = LastWrite(time, blockNum);
        }
    }

    function upgrade(
        uint256 tokenId,
        uint256 strength,
        uint256 magic,
        uint256 dexterity,
        uint256 wisdom,
        uint256 intelligence
    ) external {
        // was public
        require(gamePhase > 1, "can't upgrade at phase 1");
        Pet storage pet = _tokenDetails[tokenId];
        uint256 oldTotalPoints = pet.strength +
            pet.magic +
            pet.intelligence +
            pet.dexterity +
            pet.wisdom;
        uint256 totalPoints = oldTotalPoints +
            strength +
            magic +
            intelligence +
            dexterity +
            wisdom;
        require(totalPoints == points, "Invalid points");
        require(ownerOf(tokenId) == _msgSender(), "You don't own this token");

        uint256 totalGpCost = (totalPoints - oldTotalPoints) * gpCost;
        if (totalGpCost > 0) {
            pToken.burn(_msgSender(), totalGpCost);
            pToken.updateOriginAccess();
        }

        pet.dexterity += dexterity;
        pet.wisdom += wisdom;
        pet.strength += strength;
        pet.magic += magic;
        pet.intelligence += intelligence;
    }

    function getAllTokensForUser(address user)
        external
        view
        returns (uint256[] memory)
    {
        // was public
        uint256 tokenCount = balanceOf(user);
        if (tokenCount == 0) {
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 totalPets = nextId;
            uint256 resultIndex = 0;
            uint256 i;
            for (i = 0; i < totalPets; i++) {
                if (ownerOf(i) == user) {
                    result[resultIndex] = i;
                    resultIndex++;
                }
            }
            return result;
        }
    }

    /*
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);
        Pet storage pet = _tokenDetails[tokenId];
    }
    */

    /**
     * allows owner to withdraw funds from minting
     */
    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}