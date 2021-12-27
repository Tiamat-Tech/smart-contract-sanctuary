//SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';

/// @title A blockchain record of epic chess games
/// @author A. Nonymous
/// @notice You can use this contract to create chess games and record every move. Even attach a stake to the game that will be transferred to the winner.
/// @dev Requires off-chain service to validate and sign the moves.
contract Chess is Ownable {
  enum GameState {
    New,
    Live,
    CheckMate,
    StaleMate,
    Draw,
    Canceled,
    Forfeit,
    Timeout,
    SysCanceled
  }

  enum GameTurn {
    None,
    Black,
    White
  }

  struct Game {
    uint amount;
    uint gameFee;
    uint32 turnTimeout;
    uint32 createdAt;
    uint32 updatedAt;
    GameState gameState;
    GameTurn turn;
    bool fundsPaid;
    bytes16 lastMove;
    address payable black;
    address payable white;
    address payable winner;
    address payable canceledBy;
    string board;
  }

  event GameCreated(uint gameId, address black, address white, uint stake);
  event GameJoined(uint gameId, address white);
  event GameCanceled(uint gameId, address canceledBy, GameState gameState);
  event TurnTaken(uint gameId, address player, string board, string lastMove, GameState gameState);
  event CheckMate(uint gameId, address winner);
  event StaleMate(uint gameId);
  event Draw(uint gameId);
  event TipReceived(address sender, uint amount, string message);

  uint    private  _version = 1;
  uint    private  _gameFeePct;
  uint    private  _minStake;
  uint32  private  _minExpire;
  uint32  private  _maxExpire;
  bool    private  _open;
  bool    private  _playing;
  address private  _validator;
  address payable private  _payee;
  string constant DEFAULT_BOARD = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';
  Game[] _games;

  modifier ifOpen()
  {
    require(_open == true, 'Not open');
    _;
  }

  modifier ifPlaying()
  {
    require(_playing == true, 'Not playing');
    _;
  }

  constructor() {
    _validator   = msg.sender;
    _payee       = payable(msg.sender);
    _minStake    = 0; 
    _gameFeePct  = 0;
    _minExpire   = 3600;        /// 1 hour
    _maxExpire   = 86400 * 7;   /// 1 week
    _open        = true;
    _playing     = true;
  }

  //  Only Owner Methods 

  /// @dev Update the gameFeePct used for new games (Created after change).
  /// @param gameFeePct_ The percentage (whole numbe) fee of game stakes for contract owner (0-100).
  function setGameFee(uint gameFeePct_) external onlyOwner {
    _gameFeePct = gameFeePct_;
  }

  /// @dev Update the minStake used for new games (Created after change).
  /// @param minStake_ Minimum stake allowed for new games, can be 0.
  function setMinStake(uint minStake_) external onlyOwner {
    _minStake = minStake_;
  }

  /// @dev Update the mi/maxnExpire used for new games (Created after change).
  /// @param minExpire_ Minimum seconds that a game creator can set for turn expirations. 
  /// @param maxExpire_ Maximum seconds that a game creator can set for turn expirations. 
  function setMinExpire(uint32 minExpire_, uint32 maxExpire_) external onlyOwner {
    _minExpire = minExpire_;
    _maxExpire = maxExpire_;
  }
  
  /// @dev Updates the address of the accepted account used to sign submitted moves.
  /// @param validator_ Public address of account used to sign moves (if 0 use account that created the contract).
  function setValidator(address validator_) external onlyOwner {
    _validator   = (validator_ != address(0)) ? validator_ : owner();
  }

  /// @dev Updates the address of the account that receives the gameFee.
  /// @param payee_ account that receives gameFee, default to owner.
  function setPayee(address payable payee_) external onlyOwner {
    _payee   = (payee_ != address(0)) ? payee_ : payable(owner());
  }

  /// @dev Updates the state of the contract for creating games, making moves.
  /// @param open_ If true, allow new games to be created.
  /// @param playing_ If true, allow moves to be submitted to existing games.
  function setStatus(bool open_, bool playing_) external onlyOwner {
    _open    = open_;
    _playing = playing_;
  }


  // Public accessors

  function version() external view returns (uint) {
    return _version;
  }

  function validator() external view returns (address) {
    return _validator;
  }

  function payee() external view returns (address) {
    return _payee;
  }

  function gameFeePct() external view returns (uint) {
    return _gameFeePct;
  }

  function minStake() external view returns (uint) {
    return _minStake;
  }

  function minExpire() external view returns (uint32) {
    return _minExpire;
  }

  function maxExpire() external view returns (uint32) {
    return _maxExpire;
  }

  function open() external view returns (bool) {
    return _open;
  }

  function playing() external view returns (bool) {
    return _playing;
  }

  /// Private methods that modify game state


  /// @dev All transfers are implemented in this internal method.
  /// @param game_ The game to update.
  /// @param prevGameState_ The state of the game prior to this action.
  function _makePayments(Game storage game_, GameState prevGameState_) internal {
    if (
      (game_.gameState == GameState.New) ||
      (game_.gameState == GameState.Live)
    ) {
      return;
    }

    if (game_.fundsPaid) {
      return;
    }
    // Make sure this is set before anyone gets paid to prevent
    // possible re-entry attack.
    game_.fundsPaid = true;
   
    // Check Mate
    if (game_.gameState ==  GameState.CheckMate) {
      game_.winner.transfer((game_.amount * 2) - game_.gameFee);
      _payee.transfer(game_.gameFee);
      return;
    }
   
    // Stale Mate
    if (game_.gameState == GameState.StaleMate) {
      game_.black.transfer(game_.amount - (game_.gameFee / 2));
      game_.white.transfer(game_.amount - (game_.gameFee / 2));
      _payee.transfer(game_.gameFee);
      return;
    }

    // Draw
    if (game_.gameState == GameState.Draw) {
      game_.black.transfer(game_.amount - (game_.gameFee / 2));
      game_.white.transfer(game_.amount - (game_.gameFee / 2));
      _payee.transfer(game_.gameFee);
      return;
    }

    // Contract Not Playing
    // If the contract is not in a playing state, something went
    // wrong and we want folks to be able to get their money back
    if (game_.gameState == GameState.SysCanceled) {
      if (prevGameState_ == GameState.New) {
        // No player has joined and no gameFee has been collected yet
        // everything goes back to the black account.
        game_.black.transfer(game_.amount);
      }
      else {
        // The game was joined, so the gameFee was already collected
        game_.white.transfer(game_.amount);
        game_.black.transfer(game_.amount);
      }
      return;
    }

    // Someone canceled, timed out or forfeit
    if (game_.canceledBy != address(0)) {
      uint amountCanceler = 0;
      uint amountCancelee = 0;
      uint amountPayee = 0;
      address payable acctCancelee = (game_.canceledBy == game_.white)
        ? game_.black
        : game_.white;

      // It's an open game anyone could have joined, or a reserved
      // game that has not been joined yet.
      if (game_.gameState == GameState.Canceled) {
        // They waited for a day and didn't get a hit
        // so we don't penalize them.
        if ((uint32(block.timestamp) - game_.createdAt) >= 86400 ) {
          amountCanceler = (game_.amount);
        }
        // They were impatient so they get dinged.
        else {
          amountCanceler = (game_.amount - game_.gameFee);
          amountPayee = game_.gameFee;
        }
      }
      else
      if (game_.gameState == GameState.Forfeit) {
        // Forfeit by the current turn player, or the
        // waiting player, but before turn timeout
        amountCancelee = ((game_.amount * 2) - game_.gameFee);
        amountPayee = game_.gameFee;
      }
      else
      if (game_.gameState == GameState.Timeout) {
        // Player canceled due to opponent's timeout
        amountCanceler = ((game_.amount * 2) - game_.gameFee);
        amountPayee = game_.gameFee;
      }

      if (amountCanceler > 0) {
        game_.canceledBy.transfer(amountCanceler);
      }
      if (amountCancelee > 0) {
        acctCancelee.transfer(amountCancelee);
      }
      if (amountPayee > 0) {
        _payee.transfer(amountPayee);
      }
    }
  }

  ///  Methods that update state

  /// @notice Sender creates a game.
  /// @dev If address _white is valid, will reserve for that account. Emits GameCreated.
  /// @param white_ Address of the "reserved" opponent.  Set to address(0) to allow anyone.
  /// @param turnTimeout_ If set to a number > 0, will make the game elligible for forfeit if _turnTimeout expires without player taking their turn. If set to 0 will default to contract 1 day. Otherwise must be between minExpire and maxExpire.
  function createGame(address white_, uint32 turnTimeout_)
    external payable ifOpen {
    require(msg.value >= _minStake, 'Insufficient funds');
    require(
      (turnTimeout_ < 1) ||
      ((turnTimeout_ >= _minExpire) && (turnTimeout_ <=  _maxExpire)),
      'Invalid turnTimeout'
    );
    uint fee = ((_gameFeePct > 0) && (msg.value > 0)) ? 
        ((msg.value * 1 * 100 * _gameFeePct) / 10000)  : 0;

    Game memory g = Game({
      amount:           msg.value,         
      gameFee:          (white_ == address(0)) ? fee : fee / 2,
      board:            DEFAULT_BOARD,
      lastMove:         '',
      gameState:        GameState.New,
      turn:             GameTurn.None,
      black:            payable(msg.sender),
      white:            payable(white_),
      winner:           payable(address(0)),
      canceledBy:       payable(address(0)),
      fundsPaid:        false,             
      turnTimeout:      (turnTimeout_ < 1 ? 86400 : turnTimeout_),
      createdAt:        uint32(block.timestamp),
      updatedAt:        uint32(block.timestamp)
    });
    _games.push(g);
    uint gameId = _games.length - 1;
    emit GameCreated(gameId, msg.sender, white_, msg.value);
  }

  /// @notice Sender cancels game.  May incur penalties depending on timing, turn.
  /// @dev See _makePayments for logic used to determine whether there are penalties. Emits GameCanceled.
  /// @param id_ The contracts identifier for the game to be canceled.
  function cancelGame(uint id_) external {
    Game storage g = _games[id_];
    require(
      ((g.gameState == GameState.New) ||
      (g.gameState == GameState.Live))
      , 'Forbidden');
    require(g.fundsPaid == false, 'Game over');
    require(msg.sender != address(0), 'Unauthorized');
    require(msg.sender == g.black || msg.sender == g.white, 'Unauthorized');
  
    GameState prevGameState = g.gameState;
    // If the contract is not playing, its a syscancel
    if (!_playing) {
      g.gameState = GameState.SysCanceled;
    }
    // If the game hasn't started yet, it's a pure cancel
    else
    if (g.gameState == GameState.New) {
      g.gameState = GameState.Canceled;
    }
    // If it was canceled by the current turn player
    // they are forfeiting for sure (since they could play)
    // the waiting player gets all the spoils
    else
    if ((g.turn == GameTurn.White) && (msg.sender == g.white)) {
      g.gameState = GameState.Forfeit;
    }
    else
    if ((g.turn == GameTurn.Black) && (msg.sender == g.black)) {
      g.gameState = GameState.Forfeit;
    }
    // Game is being canceled by the opponent of current turn player
    else {
      // Current turn player has let the clock run out
      // We will interpret that as a timeout
      if ((uint32(block.timestamp) - g.updatedAt) > (g.turnTimeout)) {
        g.gameState = GameState.Timeout; 
      }
      /// Not a timeout, so the player waiting for a turn is forfeiting
      // The current turn player gets the spoils
      else { 
        g.gameState = GameState.Forfeit;
      }
    }

    g.canceledBy = payable(msg.sender);
    _makePayments(g, prevGameState);
    g.updatedAt = uint32(block.timestamp);
    emit GameCanceled(id_, g.canceledBy, g.gameState);
  }

  /// @notice Joins sender to an open game.
  /// @dev Performs checks on whether game is rerved for other sender, if its open, etc. Emits GameJoined.
  /// @param id_ The contracts identifier for the game to be joined.
  function joinGame(uint id_) external payable ifOpen {
    Game storage g = _games[id_];
    require(g.gameState == GameState.New, 'Invalid state');
    require((g.white == address(0)) || (g.white == msg.sender), 'Forbidden');
    require(g.black != msg.sender, 'Forbidden');
    require(g.amount >= msg.value, 'Too much funds');
    require(g.amount <= msg.value, 'Insufficient funds');
    g.white = payable(msg.sender);
    g.turn = GameTurn.White;
    g.gameState = GameState.Live;
    g.updatedAt = uint32(block.timestamp);
    emit GameJoined(id_, msg.sender);
  }

  /// @notice Evaluates and records a player move.  If the move ends the game, that is
  /// implemented here.
  /// @dev Accepts a move that has been signed by the external validation service. Emits TurnTaken, possibly CheckMate or StaleMate
  /// @param id_ The contracts identifier for the game.
  /// @param lastMove_ The last move to and from SANS encoded in a bytes16 array.
  /// @param newBoard_ The board as it is rendered (FEN) after the move is applied
  /// @param gameState_ Should be 0 (not over) or CheckMate, StaleMate or Draw.
  /// @param message_ A hash of the current board + move + newBoard + gameState.
  /// @param signature_ The signature used to sign the message hash. The signature account must match the contract's validator account.
  function makeMove(uint id_, string calldata lastMove_, string calldata newBoard_,
    GameState gameState_, bytes32 message_, bytes calldata signature_) external ifPlaying {
    require(ECDSA.recover(message_, signature_) == _validator, 'Bad signature');
    Game storage g = _games[id_];
    require(msg.sender == g.black || msg.sender == g.white, 'Unauthorized');
    require(g.gameState == GameState.Live, 'Invalid state');
    if (g.turn == GameTurn.White) {
        require(g.white == msg.sender, 'Forbidden');
    } else {
        require(g.black == msg.sender, 'Forbidden');
    }
    require(keccak256(abi.encodePacked(g.board,lastMove_,newBoard_,gameState_)) == message_,
      'Bad request');
    string memory oldBoard = g.board;

    GameState prevGameState = g.gameState;
    g.board = newBoard_;
    g.lastMove = bytes16(bytes(lastMove_));
    g.gameState = gameState_;
    g.turn  = (g.turn == GameTurn.White) ? GameTurn.Black : GameTurn.White; 
    g.updatedAt = uint32(block.timestamp);

    emit TurnTaken(id_, msg.sender, oldBoard, lastMove_, gameState_);

    if (gameState_ == GameState.CheckMate) {
        g.winner = payable(msg.sender);
        emit CheckMate(id_, msg.sender);
        _makePayments(g, prevGameState);
    } else 
    if (gameState_ == GameState.StaleMate) {
        emit StaleMate(id_);
        _makePayments(g, prevGameState);
    } else
    if (gameState_ == GameState.Draw) {
        emit Draw(id_);
        _makePayments(g, prevGameState);
    }
  }

  /// @notice Enables fans to send tips.
  /// @dev Funds are auto transferred to contract payee account. Emits TipReceived
  /// @param msg_ A message to put in the event log.
  function tip(string calldata msg_) external payable {
    require(_payee != msg.sender, 'Forbidden');
    require(msg.value > 0, 'Thanks for nothin');
    _payee.transfer(msg.value);
    emit TipReceived(msg.sender, msg.value, msg_);
  }

  /// @notice Receive function to ensure only owner or payee can send funds. Trying to derisk random folks locking funds in the contract.
  receive() external payable {
    require(msg.sender == _payee || msg.sender == owner(), 'Forbidden');
    require(msg.value > 0, 'Thanks for nothin');
  }

  //  Methods that read state

  /// @notice Returns the number of games that have been created.
  /// @return uint, number of games created.
  function getGamesCount() external view returns (uint) {
    return _games.length; 
  }

  /// @notice Returns list of created games.
  /// @dev Works with pagination, not sure if this is necessary, but could be helpful.
  /// @param limit_ Number of games to return.
  /// @param offset_ Zero based offset for current page of data.
  /// @return array of Game structs.
  function getGames(uint limit_, uint offset_) external view returns (Game[] memory) {
    uint256 length_ = _games.length;
    Game[] memory tmp = new Game[](
      (offset_ + limit_) > length_
        ? length_ - offset_
        : limit_
    );
    if (length_ == 0) {
      return tmp;
    }
    uint idx = 0;
    uint eof = ((offset_ + limit_) > length_) 
      ? length_
      : (offset_ + limit_);
    for (uint i = offset_; i < eof; i++) {
      Game memory _g = _games[i];
      tmp[idx++] = _g;
    }
    return tmp;
  }

  /// @notice Returns a single game based on gameId.
  /// @dev gameId is the array index of the game in the games array.
  /// @param id_ Index of the requrested game.
  /// @return Game struct.
  function getGameById(uint id_) external view returns (Game memory) {
    require(id_ < _games.length, 'Invalid game id.');
    return _games[id_];
  }
}