// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Lottery is Ownable {

    using SafeMath for uint256;

    enum STATE { IDLE, OPEN, CLOSED }

    struct PlayerInfo{
        address payable playerAddress;
        uint256 putIn;
        uint256 lastEnterTimestamp;
    }

    //factors to initialize
    uint256 hardCapOfNextPool;
    uint256 feePrizePool1;
    uint256 feeNextPool1;
    uint256 feePrizePool2;
    uint256 numberOfWinners;

    //lottery infos
    uint256 public lotteryId;
    address[] public chasingList;
    mapping(address=>PlayerInfo) players;
    uint256 endingTimeStamp;
    uint256 public balanceOfPrizePool;
    uint256 public balanceOfNextPool;
    // uint256 public balanceOfMarketing;
    STATE public currentState;
    
    event NewEntry(uint256 lotteryId, uint256 endingTimeStamp, PlayerInfo[] candsOfWin, uint256[] willWins);

    modifier inState(STATE state) {
        require(state == currentState, 'current state does not allow this');
        _;
    }

    constructor(uint256 _hardCapOfNextPool, uint256 _feePrizePool1, uint256 _feeNextPool1, uint256 _feePrizePool2, uint256 _numberOfWinners) {
        require(_feePrizePool1 > 1 && _feePrizePool1 < 99, 'fee should be between 1 and 99');
        require(_feeNextPool1 > 1 && _feeNextPool1 < 99, 'fee should be between 1 and 99');
        require(_feePrizePool2 > 1 && _feePrizePool2 < 99, 'fee should be between 1 and 99');

        hardCapOfNextPool = _hardCapOfNextPool.mul(10**18);
        feePrizePool1 = _feePrizePool1;
        feeNextPool1 = _feeNextPool1;
        feePrizePool2 = _feePrizePool2;
        numberOfWinners = _numberOfWinners;

        lotteryId = 0;
        balanceOfPrizePool=0;
        balanceOfNextPool=0;
        currentState=STATE.IDLE;
    }

    function start() external inState(STATE.IDLE) onlyOwner() {
        lotteryId = lotteryId.add(1);
        balanceOfPrizePool = balanceOfNextPool;
        balanceOfNextPool = 0;
        currentState = STATE.OPEN;

        endingTimeStamp = (block.timestamp).add(18000);
        chasingList = new address[](0);
        PlayerInfo[] memory candsOfWin = new PlayerInfo[](0);
        uint256[] memory willWins = new uint256[](0);

        emit NewEntry(lotteryId, endingTimeStamp, candsOfWin, willWins);
    }

    function getLotteryStatus() external view returns(STATE, uint256, uint256, PlayerInfo[] memory, uint256[] memory) {
        PlayerInfo[] memory candsOfWin;
        uint256[] memory willWins;
        (candsOfWin, willWins) = _calcCandsOfWin();
        return (currentState, lotteryId, endingTimeStamp, candsOfWin, willWins);
    }

    function enter() external payable inState(STATE.OPEN){
        require(msg.value >= 0.01 ether, 'Minimum entry is 0.01 BNB');
        require(endingTimeStamp.sub(block.timestamp).add(5) < 18000 ,'Prize Hard Cap time has reached out');
        require(chasingList[chasingList.length.sub(1)] != msg.sender, 'You have just entered');


        if(players[msg.sender].playerAddress != msg.sender){  // first put in
            PlayerInfo memory info = PlayerInfo(payable(msg.sender),  msg.value, block.timestamp);
            players[msg.sender] = info;
        }
        else{
            players[msg.sender].putIn = players[msg.sender].putIn.add(msg.value);
            players[msg.sender].lastEnterTimestamp = block.timestamp;
        }

        chasingList.push(msg.sender);
        endingTimeStamp = endingTimeStamp.sub(5);

        if(balanceOfNextPool < hardCapOfNextPool){
            balanceOfPrizePool = balanceOfPrizePool.add((msg.value).mul(feePrizePool1).div(10**2));
            balanceOfNextPool = balanceOfNextPool.add((msg.value).mul(feeNextPool1).div(10**2));
        }
        else{
            balanceOfPrizePool = balanceOfPrizePool.add((msg.value).mul(feePrizePool2).div(10**2));
        }

        PlayerInfo[] memory candsOfWin;
        uint256[] memory willWins;
        (candsOfWin, willWins) = _calcCandsOfWin();
        emit NewEntry(lotteryId, endingTimeStamp, candsOfWin, willWins);
    }

    function closeLottery() external inState(STATE.OPEN) onlyOwner(){
        currentState = STATE.CLOSED;
    }

    function deliverPrize() external inState(STATE.CLOSED) onlyOwner(){
        PlayerInfo[] memory candsOfWin;
        uint256[] memory willWins;
        (candsOfWin, willWins) = _calcCandsOfWin();
        for(uint i = 0; i < candsOfWin.length; i++){
            candsOfWin[i].playerAddress.transfer(willWins[i]);
        }
        for(uint i = 0; i < chasingList.length; i++){
            delete players[chasingList[i]];
        }
        
        currentState = STATE.IDLE;
    }

    function _calcCandsOfWin() internal view returns(PlayerInfo[] memory, uint256[] memory){

        PlayerInfo[] memory _cands = new PlayerInfo[](numberOfWinners);

        uint _chasingLength = chasingList.length;
        uint256 _winersTPutIn = 0;

        for(uint i = 0; i < numberOfWinners; i++){
            if(_chasingLength < i + 1) { break; }
            _cands[i] = players[chasingList[_chasingLength-1-i]];
            _winersTPutIn = _winersTPutIn.add(_cands[i].putIn);
        }

        uint256[] memory _willWins = new uint256[](numberOfWinners);
        for(uint i = 0; i < _cands.length; i++){
            _willWins[i] = balanceOfPrizePool.mul(_cands[i].putIn).div(_winersTPutIn);  //////TODO
        }
        
        return (_cands, _willWins);
    }

    function setHardCapOfNextPool(uint256 _hardCap) external inState(STATE.IDLE) onlyOwner(){
        hardCapOfNextPool = _hardCap;
    }

    function setFeePrizePool1(uint256 _fee) external inState(STATE.IDLE) onlyOwner(){
        require(_fee > 1 && _fee < 99, 'fee should be between 1 and 99');
        feePrizePool1 = _fee;
    }

    function setFeeNextPool1(uint256 _fee) external inState(STATE.IDLE) onlyOwner(){
        require(_fee > 1 && _fee < 99, 'fee should be between 1 and 99');
        feeNextPool1 = _fee;
    }

    function setFeePrizePool2(uint256 _fee) external inState(STATE.IDLE) onlyOwner(){
        require(_fee > 1 && _fee < 99, 'fee should be between 1 and 99');
        feePrizePool2 = _fee;
    }

    function setNumberOfWinners(uint256 _num) external inState(STATE.IDLE) onlyOwner(){
        require(_num > 2, 'The number of Winners should be bigger than 2');
        numberOfWinners = _num;
    }

    function withDrawMarketing(uint256 amount) external inState(STATE.IDLE) onlyOwner(){
        require(amount < (address(this).balance).sub(balanceOfPrizePool).sub(balanceOfNextPool), 'The amount is bigger than the balance of marketing pool.');
        (payable(msg.sender)).transfer(amount);
    }
}