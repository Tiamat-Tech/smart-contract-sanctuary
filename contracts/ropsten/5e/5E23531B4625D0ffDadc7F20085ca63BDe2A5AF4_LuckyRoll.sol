// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
// import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/master/contracts/access/AccessControl.sol";
// import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts/master/contracts/security/ReentrancyGuard.sol";

contract LuckyRoll is AccessControl, ReentrancyGuard{
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");                   // Admin can set claim start time
    bytes32 public constant EXECUTE_ROLE = keccak256("EXECUTE_ROLE");
    string[] public prizes;
    string[] public participants;
    mapping(string => string) public prizeMap;
    string[] public winners;
    bool private _finished;

    struct prizeAssign {
        string prize;
        string username;
    }

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, _msgSender()), "not admin");
        _;
    }

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());   // DEFAULT_ADMIN_ROLE can grant other roles
        _setupRole(ADMIN_ROLE, _msgSender());
        _setupRole(EXECUTE_ROLE, _msgSender());
        _finished = true;
    }

    function setPrize(string[] memory prizes_) external  {
        require(hasRole(EXECUTE_ROLE, msg.sender), "Caller is not a EXECUTER");
        require(_finished, "this turn have not finished");
        for (uint i = 0; i < prizes_.length; i++) {
            prizes.push(prizes_[i]);
        }
        _finished = false;
    }

    function participant(string memory username) public payable {
        require(hasRole(ADMIN_ROLE, msg.sender) || msg.value > 0.99e18, "0.99 ether lead to the game");
        participants.push(username);
    }

    function luckyRoll() external {
        require(hasRole(EXECUTE_ROLE, msg.sender), "Caller is not a EXECUTER");
        for(uint i = 0; i < prizes.length; i++) {
            uint luckyNumber = (_random() % participants.length);
            prizeMap[prizes[i]] = participants[luckyNumber];
            delete participants[luckyNumber];
        }
    }

    function _random() private view returns (uint) {
        return uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp)));
    }

    function withdraw() external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not a ADMIN");
        uint amount = address(this).balance;
        (bool success) = payable(msg.sender).send(amount);
        require(success, "Failed to send Ether");
    }

    function getPrizes() external view returns (string[] memory) {
        return prizes;
    }

    function getParticipants() external view returns (string[] memory) {
        return participants;
    }

    function winnerBoard(uint index) external view returns (string memory prize, string memory username) {
        return (prizeMap[participants[index]], participants[index]);
    }

    function restart() external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not a ADMIN");
        uint i;
        for(i = 0; i < prizes.length; i++) {
            delete prizes[i];
        }
        for(i = 0; i < participants.length; i++) {
            delete participants[i];
        }
        for(i = 0; i < winners.length; i++) {
            delete prizeMap[participants[i]];
            delete participants[i];
        }
        _finished = true;
    }
}