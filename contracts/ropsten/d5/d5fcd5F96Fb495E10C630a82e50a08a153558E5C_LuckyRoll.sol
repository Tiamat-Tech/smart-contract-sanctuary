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
        uint rand = _random();
        for(uint i = 0; i < prizes.length; i++) {
            uint luckyNumber = (rand % participants.length);
            prizeMap[participants[luckyNumber]] = prizes[i];
            winners.push(participants[luckyNumber]);
            _removeParticipants(luckyNumber);
            rand = rand / participants.length / 10;
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

    function getPrizes(uint i) external view returns (string memory prize) {
        return prizes[i];
    }

    function getParticipants(uint i) external view returns (string memory username) {
        return participants[i];
    }

    function winnerBoard(uint index) external view returns (string memory username, string memory prize) {
        return (winners[index], prizeMap[winners[index]]);
    }

    function restart() external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not a ADMIN");
        uint i;
        for(i = 0; i < prizes.length; i++) {
            // delete prizes[i];
            prizes.pop();
        }
        for(i = 0; i < participants.length; i++) {
            // delete participants[i];
            participants.pop();
        }
        for(i = 0; i < winners.length; i++) {
            delete prizeMap[winners[i]];
            // delete winners[i];
            winners.pop();
        }
        _finished = true;
    }

    function participantCount() external view returns (uint count) {
        return participants.length;
    }
    function winnerCount() external view returns (uint count) {
        return winners.length;
    }

    function _removeParticipants(uint index) internal {
        require(index < participants.length, "out of index");

        for (uint i = index; i<participants.length-1; i++){
            participants[i] = participants[i+1];
        }
        delete participants[participants.length-1];
        participants.pop();
    }

    function _removePrizes(uint index) internal {
        require(index < prizes.length, "out of index");

        for (uint i = index; i<prizes.length-1; i++){
            prizes[i] = prizes[i+1];
        }
        delete prizes[prizes.length-1];
        prizes.pop();
    }
}