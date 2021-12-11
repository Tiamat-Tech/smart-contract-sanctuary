// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.4;
pragma abicoder v2;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";


contract CarRacing is ERC721, ERC721URIStorage, Ownable{

    constructor() ERC721("CarRacing", "CAR") {}

    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private _tokenIdCounter;

    //EVENTS
    event NewCar(address indexed owner, uint carId, string name, uint dna, uint engineLevel, uint carHP, uint carFuel, uint endurance, uint maxSpeed, uint carLevel);
    event NftBought(address _seller, address _buyer, uint256 _price);


    //VARIABLES
    uint256 dnaDigits = 16;
    uint dnaModulus = 10 ** dnaDigits;
    uint nonce = 0;
    uint cooldownTime = 1 days;

    uint randNonce = 0;
    uint RaceWinningProbability = 50;

    uint256 _updatefee = 0.001 ether;

    uint256 _marketitemsize = 0;

    uint256 packonefee = 0.0000001 ether;
    uint256 packtwofee = 0.0000002 ether;
    uint256 packthreefee = 0.0000003 ether;

    mapping (uint256 => uint256) public tokenIdToPrice;

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

    function _createCar(string memory _name, uint _dna,
     uint _engineLevel, uint _carHP,uint _carFuel, uint _endurance,
     uint _maxSpeed, uint _carLevel) private returns (uint){
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        cars.push(Car(tokenId, _name, _dna, _engineLevel, _carHP, _carFuel, _endurance, _maxSpeed, _carLevel, uint32(block.timestamp + cooldownTime), 0, 0));
        _safeMint(msg.sender, tokenId);
        string memory uri = string(abi.encodePacked(tokenId.toString(), ".png"));
        _setTokenURI(tokenId, uri);
        emit NewCar(msg.sender, tokenId, _name, _dna, _engineLevel, _carHP, _carFuel, _endurance, _maxSpeed, _carLevel);
        return tokenId;
    }

    function createRandomCar(string memory _name, uint packType) external payable{
          
        uint randDna = _generateRandomDna(_name);
        uint _carLevel = getRandomLevel(packType);
        if(_carLevel == 1){
            require(msg.value == packonefee, "Not enough ether value!!");
            _createCar(
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
            require(msg.value == packtwofee);  
            _createCar(
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
            require(msg.value == packthreefee);  
            _createCar(
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

    function createRandomCarAdmin(string memory _name, uint packType) public{
        uint randDna = _generateRandomDna(_name);
        uint _carLevel = getRandomLevel(packType);

        if(_carLevel == 1){
            _createCar(
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
            _createCar(
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
            _createCar(
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


    function _baseURI() internal pure override returns (string memory) {
        return "https://gateway.pinata.cloud/ipfs/QmfSPKdCKZJ3QDNGm6uiow52uMhQLPF97bWWv2Xz3H91n8/";
    }

  // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }


    //MARKET 
    function allowBuy(uint256 _tokenId, uint256 _price) external {
            require(msg.sender == ownerOf(_tokenId), "Not owner of this token");
            require(_price > 0, "Price zero");
            tokenIdToPrice[_tokenId] = _price * 1000000000000000;
            _marketitemsize++;
        }

    function disallowBuy(uint256 _tokenId) external {
        require(msg.sender == ownerOf(_tokenId), "Not owner of this token");
        tokenIdToPrice[_tokenId] = 0;
         _marketitemsize--;
    }

    function buy(uint256 _tokenId) external payable {
        uint256 price = tokenIdToPrice[_tokenId];
        require(price > 0, "This token is not for sale");
        require(msg.value == price, "Incorrect value");
        
        address seller = ownerOf(_tokenId);
        _transfer(seller, msg.sender, _tokenId);
        tokenIdToPrice[_tokenId] = 0; // not for sale anymore
        _marketitemsize--;
        payable(seller).transfer(msg.value); // send the ETH to the seller

        emit NftBought(seller, msg.sender, msg.value);
    }

    function getMarketItems() public view returns (Car[] memory) {
        Car[] memory result = new Car[](_marketitemsize);
        uint256 counter = 0;
        for (uint256 i = 0; i < cars.length; i++) {
        
        if (tokenIdToPrice[i]>0) {
                result[counter] = cars[i];
                counter++;
            }
        }
        return result;
    }

    function getItemPrices() public view returns (uint256[] memory prices) {
        uint256[] memory result = new uint256[](_marketitemsize);
        uint256 counter = 0;
        for (uint256 i = 0; i < _marketitemsize; i++) {
        if (tokenIdToPrice[i]>0) {
                result[counter] = tokenIdToPrice[i];
                counter++;
            }
        }
        return result;
    }

    //MARKET
}