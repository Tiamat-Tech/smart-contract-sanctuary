// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./utils/AccessController.sol";
import "./utils/IGame.sol";

contract GameController is Initializable, AccessController {
    enum GameStatus {
        Empty,
        Enabled,
        Disabled
    }

    struct Game {
        address gameAddress;
        string gameName;
    }

    struct GameSettings {
        uint8 index;
        GameStatus status;
    }

    struct GameToken {
        uint128 operating;
        uint128 fee;
        uint128 fund;
    }

    Game[] public gameList;
    mapping(address => GameSettings) public settings;
    mapping(uint8 => GameToken) public gameTokens;
    // mapping(uint8 => uint256) public gamePaused;

    modifier onlyDeclaredGame(uint8 _gameIndex) {
        require(
            settings[gameList[_gameIndex].gameAddress].status !=
                GameStatus.Empty,
            "Vault.sol: game is not declared."
        );
        _;
    }

    modifier onlyEnabledGame(uint8 _gameIndex) {
        require(
            settings[gameList[_gameIndex].gameAddress].status ==
                GameStatus.Enabled,
            "Vault.sol: game must be enabled."
        );
        _;
    }

    modifier onlyDisabledGame(uint8 _gameIndex) {
        require(
            settings[gameList[_gameIndex].gameAddress].status ==
                GameStatus.Disabled,
            "Vault.sol: game must be disabled."
        );
        _;
    }

    function __GameController_init() public initializer {
        AccessController.__AccessController_init();
    }

    function addGame(
        address _newGameAddress,
        string calldata _newGameName,
        bool _isActive
    ) external onlyAdmin {
        require(
            settings[_newGameAddress].status == GameStatus.Empty,
            "Vault.sol: game already declared."
        );

        gameList.push(
            Game({gameAddress: _newGameAddress, gameName: _newGameName})
        );
        settings[_newGameAddress].index = uint8(gameList.length - 1);
        settings[_newGameAddress].status = _isActive == true
            ? GameStatus.Enabled
            : GameStatus.Disabled;

        grantRole(GAME_ROLE, _newGameAddress);
    }

    function getGameIndex(address _gameAddress) public view returns (uint8) {
        require(
            settings[_gameAddress].status != GameStatus.Empty,
            "Vault.sol: game is not declared."
        );
        return settings[_gameAddress].index;
    }

    function updateGameAddress(uint8 _gameIndex, address _newGameAddress)
        external
        onlyAdmin
        onlyDeclaredGame(_gameIndex)
    {
        require(
            settings[_newGameAddress].status == GameStatus.Empty,
            "Vault.sol: game with new address already declared."
        );

        address oldGameAddress = gameList[_gameIndex].gameAddress;
        settings[_newGameAddress] = settings[oldGameAddress];
        delete settings[oldGameAddress];
        gameList[_gameIndex].gameAddress = _newGameAddress;

        revokeRole(GAME_ROLE, oldGameAddress);
        grantRole(GAME_ROLE, _newGameAddress);
    }

    function updateGameName(uint8 _gameIndex, string calldata _newGameName)
        external
        onlyAdmin
        onlyDeclaredGame(_gameIndex)
    {
        gameList[_gameIndex].gameName = _newGameName;
    }

    function enableGame(uint8 _gameIndex)
        external
        onlyAdmin
        onlyDisabledGame(_gameIndex)
    {
        address gameAddress = gameList[_gameIndex].gameAddress;
        IGame(gameAddress).unpause();
        settings[gameAddress].status = GameStatus.Enabled;
        // delete gamePaused[_gameIndex];
    }

    function disableGame(uint8 _gameIndex)
        external
        onlyAdmin
        onlyEnabledGame(_gameIndex)
    {
        address gameAddress = gameList[_gameIndex].gameAddress;
        IGame(gameAddress).pause();
        settings[gameAddress].status = GameStatus.Disabled;
        // gamePaused[_gameIndex] = block.timestamp + 10 minutes;
    }

    // function numberOfGame() public view returns (uint256) {
    //     return gameList.length;
    // }

    // function addGameTokens(uint8 _gameIndex, uint256 _amount) internal {
    //     gameTokens[_gameIndex] += _amount;
    // }

    // function subGameTokens(uint8 _gameIndex, uint256 _amount) internal {
    //     gameTokens[_gameIndex] -= _amount;
    // }
}

contract TokenController is Initializable, AccessController {
    address public tokenAddress;

    function __TokenController_init() public initializer {
        AccessController.__AccessController_init();
    }

    function setToken(address _tokenAddress) public onlyAdmin {
        tokenAddress = _tokenAddress;
    }

    function getTokenInstance() internal view returns (IERC20) {
        return IERC20(tokenAddress);
    }
}

contract Vault is GameController, TokenController {
    using SafeERC20 for IERC20;

    mapping(address => uint128) public balances;

    function initialize(address _defaultTokenAddress) public initializer {
        GameController.__GameController_init();

        TokenController.__TokenController_init();

        setToken(_defaultTokenAddress);
    }

    modifier onlyNoPlayer(uint8 _gameIndex) {
        require(
            !IGame(gameList[_gameIndex].gameAddress).isPlayerStillPlaying(),
            "Vault.sol: player are still playing."
        );
        _;
    }

    modifier checkBalance(address _owner, uint128 _amount) {
        IERC20 token = getTokenInstance();
        require(
            token.balanceOf(_owner) >= _amount,
            "Vault.sol: Insufficient balance."
        );
        require(
            token.allowance(_owner, address(this)) >= _amount,
            "Vault.sol: Insufficient allowance to user's token, please approve token allowance."
        );
        _;
    }

    // modifier onlyNoPlayerAndAllGameDisabled() {
    //     for (uint8 _gameIndex = 0; _gameIndex < gameList.length; _gameIndex++) {
    //         require(
    //             !IGame(gameList[_gameIndex].gameAddress).isPlayerStillPlaying(),
    //             "Vault: player are still playing"
    //         );
    //         require(
    //             settings[gameList[_gameIndex].gameAddress].status ==
    //                 GameStatus.Disabled,
    //             "Vault: game must be disabled!"
    //         );
    //     }
    //     _;
    // }

    function addGameBalance(address _player, uint128 _amount)
        external
        onlyRole(GAME_ROLE)
    {
        require(
            balances[_player] >= _amount,
            "Vault.sol: Player has insufficient token in balance, please deposit token."
        );

        balances[_player] -= _amount;
        balances[address(this)] += _amount;
        gameTokens[getGameIndex(msg.sender)].operating += _amount;
    }

    function subGameBalance(
        address _player,
        uint128 _amount,
        uint128 _fee
    ) external onlyRole(GAME_ROLE) {
        // check remain operating token
        // uint8 gameIndex = getGameIndex(msg.sender);
        // GameToken storage gameToken = gameTokens[gameIndex];
        // uint128 totalAmount = _amount + _fee;
        // uint128 amount = safeTokenAmount(
        //     gameIndex,
        //     totalAmount,
        //     true,
        //     false,
        //     false
        // );
        // gameToken.operating -= amount;
        // gameToken.fee += _fee;
        // balances[address(this)] -= amount - _fee;
        // balances[_player] += amount - _fee;

        GameToken storage gameToken = gameTokens[getGameIndex(msg.sender)];

        gameToken.operating -= _amount + _fee;
        gameToken.fee += _fee;
        balances[address(this)] -= _amount;
        balances[_player] += _amount;
    }

    function tokenInboundTransfer(uint128 _amount)
        external
        checkBalance(msg.sender, _amount)
    {
        IERC20 token = getTokenInstance();

        token.safeTransferFrom(msg.sender, address(this), _amount);

        balances[msg.sender] += _amount;
        // gameTokens[getGameIndex(msg.sender)].operating += _amount;
    }

    function tokenOutboundTransfer(uint128 _amount) external {
        require(
            balances[msg.sender] >= _amount,
            "Vault.sol: Player's balance has not enough token."
        );

        IERC20 token = getTokenInstance();

        //uint8 gameIndex = getGameIndex(msg.sender);
        // uint128 amount = safeTokenAmount(
        //     gameIndex,
        //     _amount,
        //     true,
        //     false,
        //     false
        // );

        // subGameTokens(gameIndex, amount);
        //GameToken storage gameToken = gameTokens[gameIndex];
        //gameToken.operating -= amount;
        //gameToken.fee += _fee;

        uint256 tokenBal = token.balanceOf(address(this));
        if (uint256(_amount) > tokenBal) {
            balances[msg.sender] -= uint128(tokenBal);
            token.safeTransfer(msg.sender, tokenBal);
        } else {
            balances[msg.sender] -= _amount;
            token.safeTransfer(msg.sender, _amount);
        }
    }

    function withdrawFee(uint8 _gameIndex, uint128 _amount) external onlyAdmin {
        IERC20 token = getTokenInstance();

        uint128 amount = safeTokenAmount(
            _gameIndex,
            _amount,
            false,
            true,
            false
        );

        gameTokens[_gameIndex].fee -= amount;
        balances[address(this)] -= amount;
        token.safeTransfer(owner(), amount);
    }

    function depositFund(uint8 _gameIndex, uint128 _amount)
        external
        onlyRole(WORKER_ROLE)
        checkBalance(msg.sender, _amount)
    {
        IERC20 token = getTokenInstance();

        token.safeTransferFrom(msg.sender, address(this), _amount);

        // addGameTokens(getGameIndex(msg.sender), _amount);
        gameTokens[_gameIndex].fund += _amount;
        balances[address(this)] += _amount;
    }

    function withdrawFund(uint8 _gameIndex, uint128 _amount)
        external
        onlyAdmin
    {
        IERC20 token = getTokenInstance();

        uint128 amount = safeTokenAmount(
            _gameIndex,
            _amount,
            false,
            false,
            true
        );

        gameTokens[_gameIndex].fund -= amount;
        balances[address(this)] -= amount;
        token.safeTransfer(owner(), amount);
    }

    // function addFunds(uint8 _gameIndex, uint256 _tokenAmount) external {
    //     require(_gameIndex < gameList.length, "Vault: unregistered gameIndex");

    //     IERC20 token = getTokenInstance();

    //     addGameTokens(_gameIndex, _tokenAmount);

    //     token.transferFrom(msg.sender, address(this), _tokenAmount);
    // }

    // function withdrawFund(uint8 _gameIndex, uint256 _amount)
    //     public
    //     onlyNoPlayer(_gameIndex)
    //     onlyDisabledGame(_gameIndex)
    //     onlyRole(ADMIN_ROLE)
    // {
    //     IERC20 token = getTokenInstance();

    //     // subGameTokens(_gameIndex, _amount);

    //     // token.transfer(owner(), _amount);

    //     uint256 amount = safeTokenAmount(_gameIndex, _amount);
    //     subGameTokens(_gameIndex, amount);
    //     token.safeTransfer(owner(), amount);
    // }

    function addReserveOperating(uint128 _amount) external onlyRole(GAME_ROLE) {
        GameToken storage gameToken = gameTokens[getGameIndex(msg.sender)];

        require(
            gameToken.fund >= _amount,
            "Vault.sol: Vault has insufficient token in fund balance."
        );

        gameToken.fund -= _amount;
        gameToken.operating += _amount;
    }

    function subReserveOperating(uint128 _amount) external onlyRole(GAME_ROLE) {
        uint8 gameIndex = getGameIndex(msg.sender);
        GameToken storage gameToken = gameTokens[gameIndex];

        uint128 amount = safeTokenAmount(
            gameIndex,
            _amount,
            true,
            false,
            false
        );

        gameToken.operating -= amount;
        gameToken.fund += amount;
    }

    function deleteGame(uint8 _gameIndex)
        public
        onlyAdmin
        onlyNoPlayer(_gameIndex)
        onlyDisabledGame(_gameIndex)
    {
        IERC20 token = getTokenInstance();

        uint128 amount = getGameTokenAmount(_gameIndex);

        token.safeTransfer(owner(), amount);

        delete gameTokens[_gameIndex];
        delete settings[gameList[_gameIndex].gameAddress];
        delete gameList[_gameIndex];
        balances[address(this)] -= amount;
    }

    // function withdrawGameTokens(uint8 _gameIndex, uint256 _amount)
    //     external
    //     onlyRole(ADMIN_ROLE)
    // {
    //     _withdrawGameTokens(_gameIndex, _amount);
    // }

    // function withdrawVaultTokens()
    //     public
    //     onlyRole(ADMIN_ROLE)
    //     onlyNoPlayerAndAllGameDisabled
    // {
    //     IERC20 token = getTokenInstance();

    //     uint256 amount = token.balanceOf(address(this));

    //     for (uint256 i = 0; i < gameList.length; i++) {
    //         uint8 _gameIndex = getGameIndex(gameList[i].gameAddress);
    //         gameTokens[_gameIndex] = 0;
    //     }

    //     token.transfer(owner(), amount);
    // }

    function safeTokenAmount(
        uint8 _gameIndex,
        uint128 _amount,
        bool _isOpe,
        bool _isFee,
        bool _isFund
    ) internal view returns (uint128) {
        GameToken memory gameToken = gameTokens[_gameIndex];
        uint128 operating = _isOpe ? gameToken.operating : 0;
        uint128 fee = _isFee ? gameToken.fee : 0;
        uint128 fund = _isFund ? gameToken.fund : 0;

        uint128 totalBal = operating + fee + fund;
        if (_amount > totalBal) {
            return totalBal;
        } else {
            return _amount;
        }
    }

    function getGameTokenAmount(uint8 _gameIndex)
        public
        view
        returns (uint128 totalToken)
    {
        GameToken memory gameToken = gameTokens[_gameIndex];
        totalToken = gameToken.operating + gameToken.fee + gameToken.fund;
    }

    // function checkApproval(address _userAddress)
    //     external
    //     view
    //     returns (uint256)
    // {
    //     return getTokenInstance().allowance(_userAddress, address(this));
    // }

    // function balanceOf(address _userAddress) external view returns (uint256) {
    //     return getTokenInstance().balanceOf(_userAddress);
    // }

    function withdrawExcessTokens(address _token) external {
        require(_token != tokenAddress, "can't withdraw the game's token");
        IERC20 token = IERC20(_token);
        uint256 amount = IERC20(token).balanceOf(address(this));
        if (amount > 0) {
            IERC20(token).transfer(owner(), amount);
        }
    }

    receive() external payable {
        revert();
    }
}