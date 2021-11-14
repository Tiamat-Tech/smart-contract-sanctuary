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

interface PixelContract {
    function mint(address _to, uint256 _amount) external;

    function balanceOf(address account) external returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);
}

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

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setRate(uint256 _rate) public onlyOwner {
        rate = _rate;
    }

    function setExpiration(uint256 _expiration) public onlyOwner {
        expiration = block.number + _expiration;
    }

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

    function stakerExists(address staker) public view returns (bool) {
        for (uint256 i; i < _stakers.length; i++) {
            if (_stakers[i] == staker) return true;
        }
        return false;
    }

    function deposit(uint256[] calldata tokenIds) external whenNotPaused {
        require(msg.sender != nixelContractAddress, "Invalid address");        
        claimRewards(tokenIds);
        if (!stakerExists(msg.sender)) _stakers.push(msg.sender);
        for (uint256 i; i < tokenIds.length; i++) {
            require(nixelContract.getRenter(nixelContract.blockLocation(tokenIds[i])[0], nixelContract.blockLocation(tokenIds[i])[1]) == address(0),"NFT is currently being rented");
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
    

    
    
    function recoverPixel() public payable onlyOwner {
        uint256 amount = pixelContract.balanceOf(address(this));
        require(
            IERC20(address(pixelContract)).transfer(
                _msgSender(),
                amount
            )
        );
    }

    function recoverETH() public payable onlyOwner {
        uint256 amount = address(this).balance;
        (bool sent, bytes memory data) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send Ether");
    }



    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}