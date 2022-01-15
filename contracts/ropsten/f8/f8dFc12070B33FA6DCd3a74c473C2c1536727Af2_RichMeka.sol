// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RichMeka is Initializable, ERC721EnumerableUpgradeable, OwnableUpgradeable {
    event Staked(address indexed owner, uint256 indexed tokenId);
    event Unstaked(address indexed owner, uint256 indexed tokenId, uint256 reward);
    event Claimed(address indexed owner, uint256 indexed tokenId, uint256 amount);

    struct Stake {
        bool created;
        uint256 createdAt;
        uint256 rate;
        uint256 claimedAmount;
    }

    bool public _saleIsActive;
    string public _baseTokenURI;
    address private _serumAccount;
    IERC20 private _serumContract;
    uint256 _tokenIdTracker;
    uint256 public _maxSupply;
    uint256 public _maxNumberOfTokens;
    uint256 public _tokensInReserve;
    uint256 public _tokenPrice;
    uint256 public _commissionValue;
    uint256 public _minClaim;
    uint256 public _coloredMekaRate;
    uint256 public _monochromeMekaRate;
    uint256 public _minStakeTime;
    uint256 public _stakedTokensCount;
    mapping(address => mapping(uint256 => Stake)) private _holderStakes;
    mapping(address => uint256[]) private _holderTokensStaked;

    function initialize() public initializer {
        _baseTokenURI = "https://api.richmeka.com/metadata/richmeka/";
        _maxSupply = 888;
        _maxNumberOfTokens = 10;
        _tokensInReserve = 60;
        _tokenPrice = 0.055 ether;
        _commissionValue = 0.005 ether;
        _minClaim = 500000000000000000000; // 500 SERUM;
        _coloredMekaRate = 8000000000000000000000; // 8 000 SERUM;
        _monochromeMekaRate = 5000000000000000000000; // 5 000 SERUM;
        _minStakeTime = 86400; // 24 hours;
        __ERC721_init("RichMeka", "RM");
        __Ownable_init();
     }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseTokenURI(string memory baseTokenURI) external onlyOwner {
        _baseTokenURI = baseTokenURI;
    }

    function flipSaleState() external onlyOwner {
        _saleIsActive = !_saleIsActive;
    }

    function setMaxSupply(uint256 maxSupply) external onlyOwner {
        _maxSupply = maxSupply;
    }

    function setTokenPrice(uint256 tokenPrice) external onlyOwner {
        _tokenPrice = tokenPrice;
    }

    function setCommissionValue(uint256 commissionValue) external onlyOwner {
        _commissionValue = commissionValue;
    }

    function setSerumContract(address serumContract) external onlyOwner {
        _serumContract = IERC20(serumContract);
    }

    function setSerumAccount(address serumAccount) external onlyOwner {
        _serumAccount = serumAccount;
    }

    function withdrawEther() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function _stake(uint256 tokenId) internal {
        require(!_holderStakes[msg.sender][tokenId].created, "RichMeka: staking of token that is already staked");

        _holderStakes[msg.sender][tokenId] = Stake(true, block.timestamp, tokenId <= 888 ? _coloredMekaRate : _monochromeMekaRate, 0);
        _holderTokensStaked[msg.sender].push(tokenId);
        _stakedTokensCount += 1;

        emit Staked(msg.sender, tokenId);
    }

    function _unstake(uint256 tokenId) internal {
        require(_holderStakes[msg.sender][tokenId].created, "RichMeka: unstaking of token that is not staked");
        require((block.timestamp - _holderStakes[msg.sender][tokenId].createdAt) >= _minStakeTime, "RichMeka: unstaking of token that is staked for less then min time");

        uint256 reward = ((_holderStakes[msg.sender][tokenId].rate / 86400) * (block.timestamp - _holderStakes[msg.sender][tokenId].createdAt)) - _holderStakes[msg.sender][tokenId].claimedAmount;
        _serumContract.transferFrom(_serumAccount, msg.sender, reward);
        _stakedTokensCount -= 1;

        delete _holderStakes[msg.sender][tokenId];
        for (uint256 i = 0; i < _holderTokensStaked[msg.sender].length; i++) {
            if (_holderTokensStaked[msg.sender][i] == tokenId) {
                 _holderTokensStaked[msg.sender][i] = _holderTokensStaked[msg.sender][_holderTokensStaked[msg.sender].length - 1];
                 _holderTokensStaked[msg.sender].pop();
                 break;
            }
        }

        emit Unstaked(msg.sender, tokenId, reward);
    }

    function mintMekas(uint256 numberOfTokens, bool stakeTokens) external payable {
        require(_saleIsActive, "RichMeka: sale must be active to mint Meka");
        require(numberOfTokens <= _maxNumberOfTokens, "RichMeka: can`t mint more then _maxNumberOfTokens at a time");
        require(msg.value >= numberOfTokens * _tokenPrice, "RichMeka: ether value sent is not correct");
        require(totalSupply() + _tokensInReserve + numberOfTokens <= _maxSupply, "RichMeka: purchase would exceed max supply of Mekas");

        if (totalSupply() + _tokensInReserve + numberOfTokens == _maxSupply) {
            _saleIsActive = false;
        }

        for (uint256 i = 0; i < numberOfTokens; i++) {
            _tokenIdTracker++;

            if (stakeTokens) {
                _stake(_tokenIdTracker);
            }
            else {
                _mint(msg.sender, _tokenIdTracker);
            }
        }
    }

    function stakeMekas(uint256[] memory tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(msg.sender == ownerOf(tokenId), "RichMeka: staking of token that is not own");
            _stake(tokenId);
            _burn(tokenId);
        }
    }

    function unstakeMekas(uint256[] memory tokenIds) external payable {
        require(msg.value >= _commissionValue, "RichMeka: ether value sent is not correct");
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            _unstake(tokenId);
            _mint(msg.sender, tokenId);
        }
    }

    function claimSerum(uint256 tokenId, uint256 amount) external payable {
        require(msg.value >= _commissionValue, "RichMeka: ether value sent is not correct");
        require(_holderStakes[msg.sender][tokenId].created, "RichMeka: claim of reward for token that is not staked");
        require((block.timestamp - _holderStakes[msg.sender][tokenId].createdAt) >= _minStakeTime, "RichMeka: claim of token that is staked for less then min time");
        require(amount >= _minClaim, "RichMeka: claim amount is less the min amout");

        uint256 reward = ((_holderStakes[msg.sender][tokenId].rate / 86400) * (block.timestamp - _holderStakes[msg.sender][tokenId].createdAt)) - _holderStakes[msg.sender][tokenId].claimedAmount;
        require(amount <= reward, "RichMeka: reward is less then amount");

        _holderStakes[msg.sender][tokenId].claimedAmount += amount;
        _serumContract.transferFrom(_serumAccount, msg.sender, amount);

        emit Claimed(msg.sender, tokenId, amount);
    }

    function claimSerumAll() external payable {
        require(msg.value >= _commissionValue, "RichMeka: ether value sent is not correct");

        for (uint256 i = 0; i < _holderTokensStaked[msg.sender].length; i++) {
            uint256 tokenId = _holderTokensStaked[msg.sender][i];
            uint256 amount = ((_holderStakes[msg.sender][tokenId].rate / 86400) * (block.timestamp - _holderStakes[msg.sender][tokenId].createdAt)) - _holderStakes[msg.sender][tokenId].claimedAmount;

            if (amount >= _minClaim && (block.timestamp - _holderStakes[msg.sender][tokenId].createdAt) >= _minStakeTime) {
                _holderStakes[msg.sender][tokenId].claimedAmount += amount;
                _serumContract.transferFrom(_serumAccount, msg.sender, amount);

                emit Claimed(msg.sender, tokenId, amount);
            }
        }
    }

    function getTokensOfHolder(address holder) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(holder);
        if (tokenCount == 0) {
            return new uint256[](0);
        }
        else {
            uint256[] memory tokens = new uint256[](tokenCount);
            for (uint256 i = 0; i < tokenCount; i++) {
                tokens[i] = tokenOfOwnerByIndex(holder, i);
            }
            return tokens;
        }
    }

    function getStakedTokensOfHolder(address holder) external view returns (uint256[] memory) {
        return _holderTokensStaked[holder];
    }

    function getStakeOfHolderByTokenId(address holder, uint256 tokenId) external view returns (uint256, uint256) {
        require(_holderStakes[holder][tokenId].created, "RichMeka: operator query for nonexistent stake");
        return (_holderStakes[holder][tokenId].createdAt, _holderStakes[holder][tokenId].claimedAmount);
    }

    function totalSupply() public view virtual override returns (uint256) {
        return super.totalSupply() + _stakedTokensCount;
    }
}