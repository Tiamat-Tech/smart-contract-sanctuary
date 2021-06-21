// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Lottery is Ownable {

    using SafeMath for uint256;

    enum STATE { IDLE, OPEN }

    //factors to initialize
    uint256 public hardCapOfNextPool;
    uint256 public feePrizePool1;
    uint256 public feeNextPool1;
    uint256 public feePrizePool2;
    uint256 public numberOfWinners;

    //lottery infos
    uint256 public lotteryId;

    address[] chasers;
    uint256[] putins;
    uint256[] timestamps;
    uint public lenChasers;

    uint256 public endingTimeStamp;
    uint256 public balanceOfPrizePool;
    uint256 public balanceOfNextPool;
    // uint256 public balanceOfMarketing;
    STATE public currentState;
    
    event NewEntry(uint256 endingTimeStamp);

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

        delete chasers;
        delete putins;
        delete timestamps;

        chasers = new address[](0);
        putins = new uint256[](0);
        timestamps = new uint256[](0);

        lenChasers = 0;

        emit NewEntry(endingTimeStamp);
    }

    function getLotteryStatus() external view returns(
        uint256 _lotteryId,
        uint256 _leftTimestamp, 
        STATE _currentState, 
        address[] memory _candsOfWin, 
        uint256[] memory _putins, 
        uint256[] memory _timestamps,
        uint256[] memory _willWins) {
        _lotteryId = lotteryId;
        if(endingTimeStamp > block.timestamp){
            _leftTimestamp =  endingTimeStamp - block.timestamp;
        }
        else{
            _leftTimestamp = 0;
        }
        
        _currentState = currentState;
        (_candsOfWin, _putins, _timestamps, _willWins) = _calcCandsOfWin();
    }

    function enter() external payable inState(STATE.OPEN){
        require(msg.value >= 0.01 ether, 'Minimum entry is 0.01 BNB');
        require(endingTimeStamp.sub(block.timestamp).add(5) < 18000 ,'Prize Hard Cap time has reached out');
        uint256 entryPrize;
        uint256 entryNext;
        (entryPrize, entryNext) = _splitEntry(msg.value);
        balanceOfPrizePool = balanceOfPrizePool + entryPrize;
        balanceOfNextPool = balanceOfNextPool + entryNext;
        
        uint256 _putin = msg.value;
        for(uint i = 0; i < lenChasers; i++){
            if(chasers[lenChasers-i-1]==msg.sender){
                _putin = _putin + putins[lenChasers-i-1];
                break;
            }
        }
        
        chasers.push(msg.sender);
        putins.push(_putin);
        timestamps.push(block.timestamp);
        lenChasers = lenChasers + 1;

        endingTimeStamp = endingTimeStamp.add(5);

        emit NewEntry(endingTimeStamp);
    }

    function _splitEntry(uint256 entry) internal view returns(uint256 prizeEntry, uint256 nextEntry){
        if(balanceOfNextPool < hardCapOfNextPool){
            if((hardCapOfNextPool-balanceOfNextPool) < entry.mul(feeNextPool1).div(10**2)){
                uint256 _putNext = hardCapOfNextPool-balanceOfNextPool;
                uint256 _putPrize = _putNext.mul(feePrizePool1).div(feeNextPool1);
                nextEntry = _putNext;
                prizeEntry = _putPrize.add((entry.sub(_putNext).sub(_putPrize)).mul(feePrizePool2).div(10**2));
            }
            else{
                prizeEntry = balanceOfPrizePool.add(entry.mul(feePrizePool1).div(10**2));
                nextEntry = balanceOfNextPool.add(entry.mul(feeNextPool1).div(10**2));
            }
        }
        else{
            prizeEntry = balanceOfPrizePool.add(entry.mul(feePrizePool2).div(10**2));
            nextEntry = 0;
        }
    }


    function deliverPrize() external inState(STATE.OPEN) onlyOwner(){
        require(endingTimeStamp<=block.timestamp,'Lottery game has not been ended.');
        address[] memory candsOfWin;
        uint256[] memory willWins;
        (candsOfWin, , , willWins) = _calcCandsOfWin();
        for(uint i = 0; i < candsOfWin.length; i++){
            (payable(candsOfWin[i])).transfer(willWins[i]);
        }
        balanceOfPrizePool = 0;
        currentState = STATE.IDLE;
    }

    function _calcCandsOfWin() internal view returns(
        address[] memory,
        uint256[] memory,
        uint256[] memory,
        uint256[] memory )
    {
        address[] memory _candsOfWin = new address[](numberOfWinners);
        uint256[] memory _putins = new uint256[](numberOfWinners); 
        uint256[] memory _timestamps = new uint256[](numberOfWinners); 
        uint256[] memory _willWins = new uint256[](numberOfWinners);    

        uint256 _winersTPutIn = 0;

        for(uint i = 0; i < numberOfWinners; i++){
            if(lenChasers < i + 1) { break; }
            _candsOfWin[i] = chasers[lenChasers-1-i];
            _putins[i] = putins[lenChasers-1-i];
            _timestamps[i] = timestamps[lenChasers-1-i];
            _winersTPutIn = _winersTPutIn.add(_putins[i]);
        }
        if(_winersTPutIn > 0){
            for(uint i = 0; i < _candsOfWin.length; i++){
                _willWins[i] = balanceOfPrizePool.mul(_putins[i]).div(_winersTPutIn);  //////TODO
            }
        }
        
        return (_candsOfWin, _putins, _timestamps, _willWins);
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

    function withdrawMarketing(uint256 amount) external onlyOwner(){
        require(amount <= (address(this).balance).sub(balanceOfPrizePool).sub(balanceOfNextPool), 'The amount is bigger than the balance of marketing pool.');
        (payable(msg.sender)).transfer(amount);
    }

    function getMarketingBalance() external view onlyOwner() returns(uint256 _balance){
        _balance =  (address(this).balance).sub(balanceOfPrizePool).sub(balanceOfNextPool);
    }

    function sendThisMarketing(address marketingAddress) external onlyOwner(){
        payable(marketingAddress).transfer((address(this).balance).sub(balanceOfPrizePool).sub(balanceOfNextPool));
    }

    function getPrizePoolBalance() external view returns(uint256 _balance){
        _balance =  balanceOfPrizePool;
    }

    function getNextPoolBalance() external view returns(uint256 _balance){
        _balance =  balanceOfNextPool;
    }
}