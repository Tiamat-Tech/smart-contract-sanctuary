//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./interfaces/IERC677Receiver.sol";

contract TiersV1 is IERC677Receiver, Initializable, ReentrancyGuardUpgradeable, AccessControlUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    struct UserInfo {
        uint256 lastFeeGrowth;
        uint256 lastDeposit;
        uint256 lastWithdraw;
        mapping(address => uint256) amounts;
    }

    uint256 private constant PRECISION = 1e8;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN");
    bytes32 public constant CONFIG_ROLE = keccak256("CONFIG");
    bool public paused;
    address public dao;
    IERC20Upgradeable public rewardToken;
    IERC20Upgradeable public votersToken;
    mapping(address => uint256) public totalAmounts;
    uint256 public lastFeeGrowth;
    mapping(address => UserInfo) public userInfos;
    address[] public users;
    mapping(address => uint256) public tokenRates;
    EnumerableSetUpgradeable.AddressSet private tokens;
    mapping(address => uint256) public nftRates;
    EnumerableSetUpgradeable.AddressSet private nfts;
    uint256[50] private __gap;

    event Donate(address indexed user, uint256 amount);
    event Deposit(address indexed user, uint256 amount, address indexed to);
    event Withdraw(address indexed user, uint256 amount, address indexed to);
    event WithdrawNow(address indexed user, uint256 amount, address indexed to);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(address _owner, address _dao, address _rewardToken, address _votersToken) public initializer {
        __ReentrancyGuard_init();
        _setRoleAdmin(ADMIN_ROLE, ADMIN_ROLE);
        _setRoleAdmin(CONFIG_ROLE, ADMIN_ROLE);
        _setupRole(ADMIN_ROLE, _owner);
        _setupRole(CONFIG_ROLE, _owner);
        dao = _dao;
        rewardToken = IERC20Upgradeable(_rewardToken);
        votersToken = IERC20Upgradeable(_votersToken);
        lastFeeGrowth = 1;
    }

    function updateToken(address[] calldata _tokens, uint[] calldata _rates) external onlyRole(CONFIG_ROLE) {
        require(_tokens.length == _rates.length, "tokens and rates length");
        for (uint256 i = 0; i < _tokens.length; i++) {
            require(_tokens[i] != address(0), "token is zero");
            require(_tokens[i] != address(votersToken), "do not add voters to tokens");
            tokens.add(_tokens[i]);
            tokenRates[_tokens[i]] = _rates[i];
        }
    }

    function updateNft(address _token, uint _rate) external onlyRole(CONFIG_ROLE) {
        require(_token != address(0), "token is zero");
        nfts.add(_token);
        nftRates[_token] = _rate;
    }

    function updateVotersToken(address _token) external onlyRole(CONFIG_ROLE) {
        require(_token != address(0), "token is zero");
        votersToken = IERC20Upgradeable(_token);
    }

    function updateVotersTokenRate(uint _rate) external onlyRole(CONFIG_ROLE) {
        tokenRates[address(votersToken)] = _rate;
    }

    function updateDao(address _dao) external onlyRole(CONFIG_ROLE) {
        require(_dao != address(0), "address is zero");
        dao = _dao;
    }

    function togglePaused() external onlyRole(CONFIG_ROLE) {
        paused = !paused;
    }

    function totalAmount() public view returns (uint256 total) {
        for (uint256 i = 0; i < tokens.length(); i++) {
            address token = tokens.at(i);
            total += totalAmounts[token] * tokenRates[token] / PRECISION;
        }
    }

    function usersList(uint page, uint pageSize) external view returns (address[] memory) {
        address[] memory list = new address[](pageSize);
        for (uint i = page * pageSize; i < (page + 1) * pageSize && i < users.length; i++) {
            list[i-(page*pageSize)] = users[i];
        }
        return list;
    }

    function userInfoPendingFees(address user, uint256 tokensOnlyTotal) public view returns (uint256) {
        return (tokensOnlyTotal * (lastFeeGrowth - userInfos[user].lastFeeGrowth)) / PRECISION;
    }

    function userInfoAmounts(address user) public view returns (uint256, uint256, address[] memory, uint256[] memory, uint256[] memory) {
        (uint256 tokensOnlyTotal, uint256 total) = userInfoTotal(user);
        uint256 tmp = tokens.length() + 1 + nfts.length();
        address[] memory addresses = new address[](tmp);
        uint256[] memory rates = new uint256[](tmp);
        uint256[] memory amounts = new uint256[](tmp);

        for (uint256 i = 0; i < tokens.length(); i++) {
            address token = tokens.at(i);
            addresses[i] = token;
            rates[i] = tokenRates[token];
            amounts[i] = userInfos[user].amounts[token];
            if (token == address(rewardToken)) {
                amounts[i] += userInfoPendingFees(user, tokensOnlyTotal);
            }
        }

        tmp = tokens.length() + 1;
        addresses[tmp - 1] = address(votersToken);
        rates[tmp - 1] = tokenRates[address(votersToken)];
        amounts[tmp - 1] = votersToken.balanceOf(user);

        for (uint256 i = 0; i < nfts.length(); i++) {
            address token = nfts.at(i);
            addresses[tmp + i] = token;
            rates[tmp + i] = nftRates[token];
            amounts[tmp + i] = IERC20Upgradeable(token).balanceOf(user);
        }

        return (tokensOnlyTotal, total, addresses, rates, amounts);
    }

    function userInfoTotal(address user) public view returns (uint256, uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < tokens.length(); i++) {
            address token = tokens.at(i);
            total += userInfos[user].amounts[token] * tokenRates[token] / PRECISION;
        }
        uint256 tokensOnlyTotal = total;
        total += votersToken.balanceOf(user) * tokenRates[address(votersToken)] / PRECISION;
        for (uint256 i = 0; i < nfts.length(); i++) {
            address token = nfts.at(i);
            if (IERC20Upgradeable(token).balanceOf(user) > 0) {
                total += nftRates[token];
            }
        }
        return (tokensOnlyTotal, total);
    }

    function _userInfo(address user) private returns (UserInfo storage, uint256, uint256) {
        require(user != address(0), "zero address provided");
        UserInfo storage userInfo = userInfos[user];
        (uint256 tokensOnlyTotal, uint256 total) = userInfoTotal(user);
        if (userInfo.lastFeeGrowth == 0) {
            users.push(user);
        } else {
            uint fees = (tokensOnlyTotal * (lastFeeGrowth - userInfo.lastFeeGrowth)) / PRECISION;
            userInfo.amounts[address(rewardToken)] += fees;
        }
        userInfo.lastFeeGrowth = lastFeeGrowth;
        return (userInfo, tokensOnlyTotal, total);
    }

    function donate(uint256 amount) external {
        _transferFrom(rewardToken, msg.sender, amount);
        lastFeeGrowth += (amount * PRECISION) / totalAmount();
        emit Donate(msg.sender, amount);
    }

    function deposit(address token, uint256 amount, address to) external nonReentrant {
        require(!paused, "paused");
        require(tokenRates[token] > 0, "not a supported token");
        (UserInfo storage user,,) = _userInfo(to);

        _transferFrom(IERC20Upgradeable(token), msg.sender, amount);

        totalAmounts[token] += amount;
        user.amounts[token] += amount;
        user.lastDeposit = block.timestamp;

        emit Deposit(msg.sender, amount, to);
    }

    function onTokenTransfer(address user, uint amount, bytes calldata _data) public override {
        require(msg.sender == address(rewardToken), "onTokenTransfer: not rewardToken");
        (UserInfo storage userInfo,,) = _userInfo(user);
        totalAmounts[address(rewardToken)] += amount;
        userInfo.amounts[address(rewardToken)] += amount;
        emit Deposit(user, amount, user);
    }

    function withdraw(address token, uint256 amount, address to) external nonReentrant {
        (UserInfo storage user,,) = _userInfo(msg.sender);
        require(!paused, "paused");
        require(block.timestamp > user.lastDeposit + 7 days, "can't withdraw before 7 days after last deposit");

        totalAmounts[token] -= amount;
        user.amounts[token] -= amount;
        user.lastWithdraw = block.timestamp;

        IERC20Upgradeable(token).safeTransfer(to, amount);

        emit Withdraw(msg.sender, amount, to);
    }

    function withdrawNow(address token, uint256 amount, address to) external nonReentrant {
        (UserInfo storage user,,) = _userInfo(msg.sender);
        require(!paused, "paused");

        uint256 half = amount / 2;
        totalAmounts[token] -= amount;
        user.amounts[token] -= amount;
        user.lastWithdraw = block.timestamp;

        // If token is XRUNE, donate, else send to DAO
        if (token == address(rewardToken)) {
            lastFeeGrowth += (half * PRECISION) / totalAmount();
            emit Donate(msg.sender, half);
        } else {
            IERC20Upgradeable(token).safeTransfer(dao, half);
        }

        IERC20Upgradeable(token).safeTransfer(to, amount - half);

        emit WithdrawNow(msg.sender, amount, to);
    }

    function migrateRewards(uint256 amount) public onlyRole(ADMIN_ROLE) {
        rewardToken.safeTransfer(msg.sender, amount);
    }

    function _transferFrom(IERC20Upgradeable token, address from, uint256 amount) private {
        uint256 balanceBefore = token.balanceOf(address(this));
        token.safeTransferFrom(from, address(this), amount);
        uint256 balanceAfter = token.balanceOf(address(this));
        require(balanceAfter - balanceBefore == amount, "_transferFrom: balance change does not match amount");
    }
}