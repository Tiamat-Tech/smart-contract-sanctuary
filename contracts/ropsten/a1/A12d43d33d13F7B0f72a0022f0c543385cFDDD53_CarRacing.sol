// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract CarRacing is ERC721, Ownable{

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    //EVENTS
    event NewCar(address indexed owner, uint carId, string name, uint dna, uint engineLevel, uint carHP, uint carFuel, uint endurance, uint maxSpeed, uint carLevel);
    //event Transfer(address _from, address _to, uint _carId);
    //event Approval(address _from,address _approved, uint _carId);
  
    //mapping (uint => address) carApprovals;

    //VARIABLES
    uint256 dnaDigits = 16;
    uint dnaModulus = 10 ** dnaDigits;
    uint nonce = 0;
    uint cooldownTime = 1 days;
    uint256 COUNTER;

    uint randNonce = 0;
    uint RaceWinningProbability = 50;

    uint256 _updatefee = 0.001 ether;
    uint256 _creationfee = 0.001 ether;
    uint256 _listingfee = 0.001 ether;

    struct Car{
        uint carId;
        string name;
        uint dna;
        uint engineLevel;
        uint carHP;
        uint carFuel;
        uint endurance;
        uint maxSpeed;
        uint carLevel;
        uint readyTime;
        uint winCount;
        uint lossCount;
    }

    Car[] public cars;

    // CAR CREATION

    function _createCar( uint _carId, string memory _name, uint _dna,
     uint _engineLevel, uint _carHP,uint _carFuel, uint _endurance,
     uint _maxSpeed, uint _carLevel) private {
        cars.push(Car(_carId, _name, _dna, _engineLevel, _carHP, _carFuel, _endurance, _maxSpeed, _carLevel, uint32(block.timestamp + cooldownTime), 0, 0));
        _safeMint(msg.sender, _carId);
        emit NewCar(msg.sender, _carId, _name, _dna, _engineLevel, _carHP, _carFuel, _endurance, _maxSpeed, _carLevel);
        COUNTER++;
    }

    function createRandomCar(string memory _name, uint packType) public payable{
        
        require(msg.value == 0.001 ether);        
        uint randDna = _generateRandomDna(_name);
        uint _carLevel = getRandomLevel(packType);
        if(_carLevel == 1){
            _createCar(COUNTER,
            _name, 
            randDna, 
            1, 
            random(50,50), 
            random(20,10), 
            random(10,40), 
            random(50,100), 
            1);
        }
        else if(_carLevel == 2){
            _createCar(COUNTER,
            _name, 
            randDna, 
            2, 
            random(50,100), 
            random(20,20), 
            random(25,50), 
            random(50,120), 
            2);
        }
        else{
            _createCar(COUNTER,
            _name, 
            randDna, 
            3, 
            random(50,150), 
            random(30,25), 
            random(25,75), 
            random(100,140), 
            3);
        }
    }

    function createRandomCarAdmin(string memory _name, uint packType) public onlyOwner{
        uint randDna = _generateRandomDna(_name);
        uint _carLevel = getRandomLevel(packType);

        if(_carLevel == 1){
            _createCar(COUNTER,
            _name, 
            randDna, 
            1, 
            random(50,50), 
            random(20,10), 
            random(10,40), 
            random(50,100), 
            1);

        }
        else if(_carLevel == 2){
            _createCar(COUNTER,
            _name, 
            randDna, 
            2, 
            random(50,100), 
            random(20,20), 
            random(25,50), 
            random(50,120), 
            2);
        }
        else{
            _createCar(COUNTER,
            _name, 
            randDna, 
            3, 
            random(50,150), 
            random(30,25), 
            random(25,75), 
            random(100,140), 
            3);
        }

    }

    //GETTER Functions

    function getCars() public view returns (Car[] memory) {
        return cars;
    }

    function getOwnerCars(address _owner) public view returns (Car[] memory) {
        Car[] memory result = new Car[](balanceOf(_owner));
        uint256 counter = 0;
        for (uint256 i = 0; i < cars.length; i++) {
        if (ownerOf(i) == _owner) {
            result[counter] = cars[i];
            counter++;
        }
        }
        return result;
    }


    //ACTION Functions

    function withdraw() external payable onlyOwner {
        address payable _owner = payable(owner());
        _owner.transfer(address(this).balance);
    }

    function updateFee(uint256 _fee) external onlyOwner {
        _updatefee = _fee;
    }

    function creationFee(uint256 _fee) external onlyOwner {
        _creationfee = _fee;
    }

    function listingFee(uint256 _fee) external onlyOwner {
        _listingfee = _fee;
    }

    function levelUp(address _owner, uint _carId) external payable {
         if (ownerOf(_carId) == _owner){
            require(msg.value == _updatefee);
            cars[_carId].carLevel = cars[_carId].carLevel+1;
         }
    }

    function changeName(address _owner, uint _carId, string calldata _newName) external  {
         if (ownerOf(_carId) == _owner){
            cars[_carId].name = _newName;
         }
    }

    function changeDna(address _owner, uint _carId, uint _newDna) external  {
         if (ownerOf(_carId) == _owner){
            cars[_carId].dna = _newDna;
         }
    }


    function startRacing(uint _carId, uint _targetId) external payable{
        require(msg.value == 0.001 ether);
        Car storage myCar = cars[_carId];
        Car storage enemyCar = cars[_targetId];
        uint rand = randMod(100);
        if (rand <= RaceWinningProbability) {
            myCar.winCount = myCar.winCount+1;
            myCar.carLevel = myCar.carLevel+1;
            enemyCar.lossCount = enemyCar.lossCount+1;
        } else {
            myCar.lossCount = myCar.lossCount+1;
            enemyCar.winCount = enemyCar.winCount+1;
        }
  }

    //CAR OWNERSHIPS



    //HELPERS

    function _generateRandomDna(string memory _str) private view returns (uint) {
        uint rand = uint(keccak256(abi.encodePacked(_str)));
        return rand % dnaModulus;
    }

    function random(uint _topNum, uint _offset) internal returns (uint) {
        uint randomnumber = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, nonce))) % _topNum;
        randomnumber = randomnumber + _offset;
        nonce++;
        return randomnumber;
    }

    function getRandomLevel(uint packType) private returns (uint){
        
        if(packType == 1){
            return 1;
        }
        else if(packType == 2){
            uint randNum = random(1000,0);   
            if(randNum <= 700){
            return 1;
            }
            else {
                return 2;
            }
        }
        else {
            uint randNum = random(1000,0);
            if(randNum <= 500){
                return 1;
            }
            else if(randNum <= 900){
                return 2;
            }
            else {
                return 3;
            }
        }
    }

    function randMod(uint _modulus) internal returns(uint) {
        randNonce = randNonce++;
        return uint(keccak256(abi.encodePacked(block.timestamp, msg.sender, randNonce))) % _modulus;
  }

}