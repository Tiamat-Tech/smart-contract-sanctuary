// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/INftGenerator.sol";
import "./interfaces/ICreature.sol";
import "./interfaces/IRandomizer.sol";
import "./interfaces/IProtectionProgram.sol";

/// @title Is responsible for NFTs generation
contract NftGenerator is INftGenerator, Ownable {
    ICreature public creatureContract;
    IRandomizer private randomizerContract;
    IProtectionProgram private protectionProgramContract;

    /// @dev START storage for group
    uint256[] public groupToNftCounts;
    uint256[] public groupToNftPrices;
    address[] public groupToPaymentTokens;
    uint8[] public groupToNftGen;
    /// @dev END storage for group

    struct Chance {
        uint128 toMintBanker;
        uint128 toStealOnMint;
    }

    /// @notice Contain chances information
    Chance public chances;

    constructor(
        ICreature _creatureContract,
        IRandomizer _randomizerContract,
        IProtectionProgram _protectionProgramContract
    ) {
        creatureContract = _creatureContract;
        randomizerContract = _randomizerContract;
        protectionProgramContract = _protectionProgramContract;
    }

    modifier onlyEOA() {
        address _sender = msg.sender;
        require(_sender == tx.origin, "onlyEOA: invalid sender (1).");

        uint256 size;
        assembly {
            size := extcodesize(_sender)
        }
        require(size == 0, "onlyEOA: invalid sender (2).");

        _;
    }

    /// @notice When new token minted, it can be stolen. Set steal on mint chance.
    /// @param _chanceToStealOnMint Chance. Where 10^27 = 100%.
    function setStealOnMintChance(uint128 _chanceToStealOnMint) external override onlyOwner {
        require(
            _chanceToStealOnMint > 0 && _chanceToStealOnMint < _getDecimals(),
            "NftGenerator: invalid steal chance."
        );

        chances.toStealOnMint = _chanceToStealOnMint;
    }

    /// @notice When new token minted, it can be a banker. Set mint banker chance
    /// @param _chanceToMintBanker Chance. Where 10^27 = 100%
    function setMintBankerChance(uint128 _chanceToMintBanker) external override onlyOwner {
        require(
            _chanceToMintBanker > 0 && _chanceToMintBanker < _getDecimals(),
            "NftGenerator: invalid mint banker chance."
        );

        chances.toMintBanker = _chanceToMintBanker;
    }

    /// @notice Setting the data by which new nfts will be generated.
    /// @dev If set as payment token zero address, payment will be for a native token.
    /// @param _groupToNftCounts [100, 235...]. First group: 1-100, second group: 101-235...
    /// @param _groupToNftPrices [1*10^18, 2*10^18]. First group price per nft: 1*10^18...
    /// @param _groupToPaymentTokens ['0xa4fas...', '0x00000...']. Group payment token
    /// @param _groupToNftGen [0, 4]. Generation number.
    function setGroups(
        uint256[] calldata _groupToNftCounts,
        uint256[] calldata _groupToNftPrices,
        address[] calldata _groupToPaymentTokens,
        uint8[] calldata _groupToNftGen
    ) external override onlyOwner {
        require(_groupToNftCounts.length > 0, "NftGenerator: arrays is empty.");
        require(
            _groupToNftCounts.length == _groupToNftPrices.length &&
            _groupToNftCounts.length == _groupToNftGen.length &&
            _groupToNftCounts.length == _groupToPaymentTokens.length,
            "NftGenerator: different array length."
        );

        delete groupToNftCounts;
        delete groupToNftPrices;
        delete groupToNftGen;
        delete groupToPaymentTokens;

        for (uint256 i = 0; i < _groupToNftCounts.length; i++) {
            require(_groupToNftCounts[i] != 0, "NftGenerator: nft count can't be a zero.");

            if (i > 0) require(_groupToNftCounts[i] > _groupToNftCounts[i - 1],
                "NftGenerator: each next value should be bigger then previous.");

            groupToNftCounts.push(_groupToNftCounts[i]);
            groupToNftPrices.push(_groupToNftPrices[i]);
            groupToNftGen.push(_groupToNftGen[i]);
            groupToPaymentTokens.push(_groupToPaymentTokens[i]);
        }

        emit GroupsSetUp(_groupToNftCounts, groupToNftPrices, groupToNftGen, _groupToPaymentTokens);
    }

    /// @notice Return group length
    function getGroupLength() external view override returns (uint256) {
        return groupToNftCounts.length;
    }

    /// @notice Mint new nfts
    /// @param _to Nft receiver
    /// @param _amount Nft amount
    function mint(address _to, uint256 _amount) external payable override onlyEOA {
        ICreature _creatureContract = creatureContract;
        IRandomizer _randomizerContract = randomizerContract;
        IProtectionProgram _protectionProgramContract = protectionProgramContract;

        uint256 _currentNftNum = _creatureContract.totalSupply();
        uint256[] memory _groupToNftCounts = groupToNftCounts;

        uint256 _maxNftCount = _groupToNftCounts[_groupToNftCounts.length - 1];
        if (_currentNftNum + _amount > _maxNftCount) _amount = _maxNftCount - _currentNftNum;
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
                _randomizerContract,
                _protectionProgramContract
            );

            _nftCountToGenerateInGroup[_groupNum]++;
        }

        _paymentProcess(_nftCountToGenerateInGroup);
    }

    /// @notice Withdraw native token from contract
    /// @param _to Token receiver
    function withdrawNative(address _to) external override onlyOwner {
        payable(_to).transfer(address(this).balance);
    }

    /// @notice Transfer stuck ERC20 tokens.
    /// @param _token Token address
    /// @param _to Address 'to'
    /// @param _amount Token amount
    function withdrawStuckERC20(
        IERC20 _token,
        address _to,
        uint256 _amount
    ) external override onlyOwner {
        _token.transfer(_to, _amount);
    }

    /// @dev Mint new nft
    function _mintProcess(
        address _to,
        uint256 _num,
        uint8 _gen,
        Chance memory _chances,
        ICreature _creatureContract,
        IRandomizer _randomizerContract,
        IProtectionProgram _protectionProgramContract
    ) private {
        if (_randomizerContract.random(_getDecimals()) < _chances.toStealOnMint) {
            address _recipient = _protectionProgramContract.getRandomRebel();

            if (_recipient != address(0)) {
                _creatureContract.safeMint(_recipient, _num);
                if (_to != _recipient) {
                    emit CreatureStolen(_num, _to, _recipient);
                    _to = _recipient;
                }
            } else {
                _creatureContract.safeMint(_to, _num);
            }
        } else {
            _creatureContract.safeMint(_to, _num);
        }

        if (_randomizerContract.random(_getDecimals()) < _chances.toMintBanker) {
            _creatureContract.addBankerInfo(_num, _gen, _randomizerContract.random(_getDecimals()));
            emit BankerCreated(_num, _to);
        } else {
            _creatureContract.addRebelInfo(_num, uint8(5 + _randomizerContract.random(4)),
                _randomizerContract.random(_getDecimals()));
            emit RebelCreated(_num, _to);
        }
    }

    /// @dev Calculate payment amount and pay
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

    /// @dev Detect group number by nft number
    function _getGroupNumberByNftNumber(uint256[] memory _groupToNftCounts, uint256 _nftNumber)
        private
        pure
        returns (uint256)
    {
        uint256 _groupNumber;
        for (uint256 i = 0; i < _groupToNftCounts.length; i++) {
            if (_groupToNftCounts[i] < _nftNumber) continue;

            _groupNumber = i;
            break;
        }

        return _groupNumber;
    }

    /// @dev Decimals for number.
    function _getDecimals() internal pure returns (uint256) {
        return 10**27;
    }
}