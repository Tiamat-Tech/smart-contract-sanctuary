pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract RPS is ERC1155 {
    
    uint8 constant ROCK = 1;
    uint8 constant PAPER = 2;
    uint8 constant SCISSORS = 3;
    
    uint256 constant TOKEN = 4;
    
    address public player1;
    address public player2;
    address owner = msg.sender;
    
    bool  onlyOnce_1 = false;
    bool  onlyOnce_2 =false;
    
    uint8 player1_roundno = 0;
    uint8 player2_roundno = 0;
    
    uint8 turn = 1;
    
    mapping (string => mapping(string => uint8)) private results;
    mapping (address => string) public choices;
    
    constructor() ERC1155("https://test.json") {
        results["R"]["R"] = 0;
        results["R"]["P"] = 2;
        results["R"]["S"] = 1;
        results["P"]["R"] = 1;
        results["P"]["P"] = 0;
        results["P"]["S"] = 2;
        results["S"]["R"] = 2;
        results["S"]["P"] = 1;
        results["S"]["S"] = 0;

    }
    
    function assignPlayers(address _player1, address _player2) public {
        require(msg.sender == owner);
        player1 = _player1;
        player2 = _player2;
    }
    
    function player1Mint() public {
        require(onlyOnce_1 == false, "Already minted");
        require(msg.sender == player1,"You're not player 1");
        _mint(msg.sender, ROCK, 3 , "");
        _mint(msg.sender, PAPER, 3 , "");
        _mint(msg.sender, SCISSORS, 3 , "");
        
        _mint(msg.sender, TOKEN, 6, "");
        
        onlyOnce_1 = true;
    }
    
    function player2Mint() public {
        require(onlyOnce_2 == false, "Already minted");
        require(msg.sender == player2,"You're not player 2");
        _mint(msg.sender, ROCK, 3 , "");
        _mint(msg.sender, PAPER, 3 , "");
        _mint(msg.sender, SCISSORS, 3 , "");
        
        _mint(msg.sender, TOKEN, 6, "");
        
        onlyOnce_2 = true;
    }
    
    
    function play_player1(string memory choice) public {
        require(msg.sender == player1, "You're not player 1");
        require(turn == 1, "Not your turn");
        require(player1_roundno <= 3, "3 rounds finished");
        choices[msg.sender] = choice;
        _burn(msg.sender,1 ,1);
        _burn(msg.sender,2 ,1);
        _burn(msg.sender,3 ,1);
        
        player1_roundno++;
        turn = 2;
    }
    
    function play_player2(string memory choice) public {
        require(msg.sender == player2, "You're not player 1");
        require(turn == 2, "Not your turn");
        require(player2_roundno <= 3, "3 rounds finished");
        choices[msg.sender] = choice;
        _burn(msg.sender,1 ,1);
        _burn(msg.sender,2 ,1);
        _burn(msg.sender,3 ,1);
        
        player2_roundno++;
        turn = 1;
    }
    
    function getWinner() public view returns (string memory) {
        
        uint8 result = results[choices[player1]][choices[player2]];
        
        if (result == 1) {
            return "Player 1 won";
        }
        if (result == 2) {
            return "Player 2 won";
        }
        else{
            return "tie match";
        }
    }    
    
    function getRewards() public returns (string memory) {
        
        uint8 result = results[choices[player1]][choices[player2]];
        
        if (result == 1) {
            _safeTransferFrom(player2, player1, 4, 1, "");
        }
        if (result == 2) {
            _safeTransferFrom(player1, player2, 4, 1, "");
        }
        else{
            return "tie match";
        }
    }    
    
}