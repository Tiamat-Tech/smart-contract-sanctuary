// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

    /**
     * @dev Allows staking contract to mint rewards to users
     */
interface PixelContract {
    function mint(address _to, uint256 _amount) external;

    function balanceOf(address account) external returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);
}

/**
 * @dev Allows Staking contract to check if the NFT is being rented
 */
interface NixelContract {
    function getRenter(int256 x_pos, int256 y_pos) external returns (address);

    function blockLocation(uint256 tokenId) external returns (int256[] memory);
}

contract PixelStake is Ownable, IERC721Receiver, ReentrancyGuard, Pausable {
    using EnumerableSet for EnumerableSet.UintSet;

    address public nixelContractAddress;
    PixelContract public pixelContract;
    NixelContract public nixelContract;

    uint256 public expiration;
    uint256 public rate;

    uint256 public claimedRewards;

    uint256 public nixelStaked;

    mapping(address => EnumerableSet.UintSet) private _deposits;
    mapping(address => mapping(uint256 => uint256)) public _depositBlocks;

    address[] private _stakers;

    constructor(
        address _nixelContractAddress,
        uint256 _rate,
        uint256 _expiration,
        address _erc20Address
    ) {
        nixelContractAddress = _nixelContractAddress;
        nixelContract = NixelContract(_nixelContractAddress);
        rate = _rate;
        expiration = block.number + _expiration;
        pixelContract = PixelContract(_erc20Address);
        _pause();
    }

    receive() external payable {}
    fallback() external payable {}


    /**
     * @dev Pauses all rewards, helpful to devs to change parameters and ensure proper behavior before allowing users to interact with the contract
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Allows users to interact with the contract
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @dev Sets the amount per block allowed for minting
     * @param _rate Rate amount to give users per block per nft
     */
    function setRate(uint256 _rate) public onlyOwner {
        rate = _rate;
    }

    /**
     * @dev Sets the expiration of current staking period
     * @param _expiration Block number of when to stop allowing staking of rewards
     */
    function setExpiration(uint256 _expiration) public onlyOwner {
        expiration = block.number + _expiration;
    }

    /**
     * @dev Returns tokens of account
     * @param account ETH Address of Stake holder
     */
    function depositsOf(address account)
        public
        view
        returns (uint256[] memory)
    {
        EnumerableSet.UintSet storage depositSet = _deposits[account];
        uint256[] memory tokenIds = new uint256[](depositSet.length());

        for (uint256 i; i < depositSet.length(); i++) {
            tokenIds[i] = depositSet.at(i);
        }

        return tokenIds;
    }

    /**
     * @dev Returns sum of all unclaimed rewards
     */
    function unclaimedRewards() public view returns (uint256 unclaimed) {
        uint256 rewards;

        for (uint256 i; i < _stakers.length; i++) {
            uint256[] memory deposits = depositsOf(_stakers[i]);
            for (uint256 j; j < deposits.length; j++) {
                rewards +=
                    rate *
                    (_deposits[_stakers[i]].contains(deposits[j]) ? 1 : 0) *
                    (Math.min(block.number, expiration) -
                        _depositBlocks[_stakers[i]][deposits[j]]);
            }
        }
        return rewards;
    }

    /**
     * @dev Calculates rewards for an account
     * @param account ETH Address of Stake holder
     * @param tokenIds Array of Nixel NFT tokenIds to check for rewards
     */
    function calculateRewards(address account, uint256[] memory tokenIds)
        public
        view
        returns (uint256[] memory rewards)
    {
        rewards = new uint256[](tokenIds.length);

        for (uint256 i; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            rewards[i] =
                rate *
                (_deposits[account].contains(tokenId) ? 1 : 0) *
                (Math.min(block.number, expiration) -
                    _depositBlocks[account][tokenId]);
        }

        return rewards;
    }

    /**
     * @dev Returns calculated reward of an account for a given Nixel NFT tokenId
     * @param account ETH Address of Stake holder
     * @param tokenId Nixel NFT Token ID
     */
    function calculateReward(address account, uint256 tokenId)
        public
        view
        returns (uint256)
    {
        require(
            Math.min(block.number, expiration) >
                _depositBlocks[account][tokenId],
            "Invalid blocks"
        );
        return
            rate *
            (_deposits[account].contains(tokenId) ? 1 : 0) *
            (Math.min(block.number, expiration) -
                _depositBlocks[account][tokenId]);
    }

    /**
     * @dev Allows user to claim their rewards
     * @param tokenIds Array of Nixel NFT tokenIds to check and claim rewards from
     */
    function claimRewards(uint256[] calldata tokenIds) public whenNotPaused {
        uint256 reward;
        uint256 blockCur = Math.min(block.number, expiration);

        for (uint256 i; i < tokenIds.length; i++) {
            reward += calculateReward(msg.sender, tokenIds[i]);
            _depositBlocks[msg.sender][tokenIds[i]] = blockCur;
        }

        if (reward > 0) {
            pixelContract.mint(msg.sender, reward);
            claimedRewards += reward;
        }
    }

    /**
     * @dev Checks if a stake holder exists
     * @param staker ETH Address of Stake holder
     */
    function stakerExists(address staker) public view returns (bool) {
        for (uint256 i; i < _stakers.length; i++) {
            if (_stakers[i] == staker) return true;
        }
        return false;
    }

    /**
     * @dev Receives Nixel NFT's and checks if staking is possible
     * @param tokenIds Array of Nixel NFT Token IDs to deposit
     */
    function deposit(uint256[] calldata tokenIds) external whenNotPaused {
        require(msg.sender != nixelContractAddress, "Invalid address");
        claimRewards(tokenIds);
        if (!stakerExists(msg.sender)) _stakers.push(msg.sender);
        for (uint256 i; i < tokenIds.length; i++) {
            require(
                nixelContract.getRenter(
                    nixelContract.blockLocation(tokenIds[i])[0],
                    nixelContract.blockLocation(tokenIds[i])[1]
                ) == address(0),
                "NFT is currently being rented"
            );
            IERC721(nixelContractAddress).safeTransferFrom(
                msg.sender,
                address(this),
                tokenIds[i],
                ""
            );
            _deposits[msg.sender].add(tokenIds[i]);
            nixelStaked += 1;
        }
    }

    /**
     * @dev Withdraws tokens and claims rewards
     * @param tokenIds Array of Nixel NFT Token IDs to claim rewards from and withdraw
     */
    function withdraw(uint256[] calldata tokenIds)
        external
        whenNotPaused
        nonReentrant
    {
        claimRewards(tokenIds);

        for (uint256 i; i < tokenIds.length; i++) {
            require(
                _deposits[msg.sender].contains(tokenIds[i]),
                "Staking: token not deposited"
            );

            _deposits[msg.sender].remove(tokenIds[i]);
            IERC721(nixelContractAddress).safeTransferFrom(
                address(this),
                msg.sender,
                tokenIds[i],
                ""
            );
            nixelStaked -= 1;
        }
        if (_deposits[msg.sender].length() == 0) {
            for (uint256 i; i < _stakers.length; i++) {
                if (_stakers[i] == msg.sender) {
                    delete _stakers[i];
                }
            }
        }
    }

    /**
     * @dev Recover any accidental PIXEL sent to this contract
     */
    function recoverPixel() public payable onlyOwner {
        uint256 amount = pixelContract.balanceOf(address(this));
        require(IERC20(address(pixelContract)).transfer(_msgSender(), amount));
    }

    /**
     * @dev Recover any ETH accidentally sent to this contract
     */
    function recoverETH() public payable onlyOwner {
        uint256 amount = address(this).balance;
        (bool sent, bytes memory data) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }

    /**
     * @dev ERC721 Token Processing
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}