// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Creature.sol";
import "./interfaces/IRandomizer.sol";
import "hardhat/console.sol";

contract NftGenerator is Ownable, ReentrancyGuard {
    event GroupsSetUp(uint256[] nftCounts, uint256[] nftPrices, uint8[] nftGen, address[] groupToPaymentTokens);
    event BankerCreated(uint256 num);
    event RebelCreated(uint256 num);
    event CreatureStolen(uint256 num, address minter, address recipient);

    Creature public creatureContract;
    IRandomizer private randomizerContract;

    uint256[] public groupToNftCounts;
    uint256[] public groupToNftPrices;
    address[] public groupToPaymentTokens;
    uint8[] public groupToNftGen;

    struct Chance {
        uint8 toMintBanker;
        uint8 toStealOnMint;
    }

    Chance public chances;

    constructor(Creature _creatureContract, IRandomizer _randomizerContract) {
        creatureContract = _creatureContract;
        randomizerContract = _randomizerContract;
    }

    function setGroups(
        uint256[] calldata _groupToNftCounts,
        uint256[] calldata _groupToNftPrices,
        address[] calldata _groupToPaymentTokens,
        uint8[] calldata _groupToNftGen
    ) external onlyOwner {
        require(_groupToNftCounts.length > 0, "NftGenerator: arrays is empty.");
        require(
            _groupToNftCounts.length == _groupToNftPrices.length &&
            _groupToNftCounts.length == _groupToNftGen.length &&
            _groupToNftCounts.length == _groupToPaymentTokens.length, "NftGenerator: different array length."
        );

        delete groupToNftCounts;
        delete groupToNftPrices;
        delete groupToNftGen;
        delete groupToPaymentTokens;

        for (uint256 i = 0; i < _groupToNftCounts.length; i++) {
            require(_groupToNftCounts[i] != 0, "NftGenerator: nft count can't be a zero.");

            if (i > 0) {
                require(_groupToNftCounts[i] > _groupToNftCounts[i - 1],
                    "NftGenerator: each next value should be bigger then previous.");
            }

            groupToNftCounts.push(_groupToNftCounts[i]);
            groupToNftPrices.push(_groupToNftPrices[i]);
            groupToNftGen.push(_groupToNftGen[i]);
            groupToPaymentTokens.push(_groupToPaymentTokens[i]);
        }

        emit GroupsSetUp(_groupToNftCounts, groupToNftPrices, groupToNftGen, _groupToPaymentTokens);
    }

    /// @dev Only whole number, 0 < x < 100;
    function setChancesToMintBanker(uint8 _chanceToMintBanker, uint8 _chanceToStealOnMint) external onlyOwner {
        require(_chanceToMintBanker > 0 && _chanceToMintBanker < 100, "NftGenerator: invalid mint banker chance.");
        require(_chanceToStealOnMint > 0 && _chanceToStealOnMint < 100, "NftGenerator: invalid steal chance.");

        chances.toMintBanker = _chanceToMintBanker;
        chances.toStealOnMint = _chanceToStealOnMint;
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function mint(address _to, uint256 _amount) external payable nonReentrant {
        Creature _creatureContract = creatureContract;
        IRandomizer _randomizerContract = randomizerContract;

        uint256 _currentNftNum = _creatureContract.totalSupply();
        uint256[] memory _groupToNftCounts = groupToNftCounts;

        uint256 _maxNftCount = groupToNftCounts[_groupToNftCounts.length - 1];
        if (_currentNftNum + _amount> _maxNftCount) {
            _amount = _maxNftCount - _currentNftNum;
        }
        require(_amount > 0, "NftGenerator: nfts limit has been reached.");

        uint8[] memory _groupToNftGen = groupToNftGen;
        uint256[] memory _nftCountToGenerateInGroup = new uint256[](_groupToNftCounts.length);

        Chance memory _chances = chances;

        for (uint256 i = 0; i < _amount; i++) {
            _currentNftNum++;
            uint256 _groupNum = _getGroupNumberByNftNumber(_groupToNftCounts, _currentNftNum);

            _mintProcess(
                _to,
                _currentNftNum,
                _groupToNftGen[_groupNum],
                _chances,
                _creatureContract,
                _randomizerContract
            );

            _nftCountToGenerateInGroup[_groupNum]++;
        }

        _paymentProcess(_nftCountToGenerateInGroup);
    }

    function _mintProcess(
        address _to,
        uint256 _currentNftNum,
        uint8 _gen,
        Chance memory _chances,
        Creature _creatureContract,
        IRandomizer _randomizerContract
    ) private {
        if (_randomizerContract.random(100) < _chances.toStealOnMint) {
            uint256 _rebelsCount = _creatureContract.getRebelsCount();
            if (_rebelsCount == 0) {
                _creatureContract.safeMint(_to, _currentNftNum);
            } else {
                address _recipient = _creatureContract.ownerOf(_creatureContract.rebels(_randomizerContract.random(_rebelsCount)));
                _creatureContract.safeMint(_recipient, _currentNftNum);

                emit CreatureStolen(_currentNftNum, _to, _to);
            }
        } else {
            _creatureContract.safeMint(_to, _currentNftNum);
        }


        if (_randomizerContract.random(100) < _chances.toMintBanker) {
            _creatureContract.addBankerInfo(_currentNftNum, _gen);
            emit BankerCreated(_currentNftNum);
        } else {
            _creatureContract.addRebelInfo(_currentNftNum, uint8(5 + _randomizerContract.random(4)));
            emit RebelCreated(_currentNftNum);
        }
    }

    function _paymentProcess(uint256[] memory _nftCountToGenerateInGroup) private {
        uint256 _nativePrice;
        for (uint256 i = 0; i < _nftCountToGenerateInGroup.length; i++) {
            uint256 _totalPrice = groupToNftPrices[i] * _nftCountToGenerateInGroup[i];
            if (_totalPrice == 0) continue;

            address _paymentTokenAddress = groupToPaymentTokens[i];
            if (_paymentTokenAddress == address(0)) {
                _nativePrice += _totalPrice;
            } else {
                IERC20(_paymentTokenAddress).transferFrom(msg.sender, address(this), _totalPrice);
            }
        }

        if (_nativePrice > 0) {
            require(msg.value >= _nativePrice, "NftGenerator: insufficient funds for payment.");
            if (msg.value > _nativePrice) {
                payable(msg.sender).transfer(msg.value - _nativePrice);
            }
        }
    }

    function _getGroupNumberByNftNumber(
        uint256[] memory _groupToNftCounts,
        uint256 _nftNumber
    ) private pure returns (uint256) {
        uint256 _groupNumber;

        for (uint256 i = 0; i < _groupToNftCounts.length; i++) {
            if (_groupToNftCounts[i] < _nftNumber) {
                continue;
            }

            _groupNumber = i;
            break;
        }

        return _groupNumber;
    }
}