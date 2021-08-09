pragma solidity >=0.5.0 <0.6.0;

import "./CHILLYPenguinFactory.sol";

contract KittyInterface {
  function getKitty(uint256 _id) external view returns (
    bool isGestating,
    bool isReady,
    uint256 cooldownIndex,
    uint256 nextActionAt,
    uint256 siringWithId,
    uint256 birthTime,
    uint256 matronId,
    uint256 sireId,
    uint256 generation,
    uint256 genes
  );
}

contract ChillyPenguinFeeder is ChillyPenguinFactory {

  address ckAddress = 0x06012c8cf97BEaD5deAe237070F9587f8E7A266d;
  KittyInterface kittyContract = KittyInterface(ckAddress);

  // Modify function definition here:
  function feedAndMultiply(uint _penguinoId, uint _targetDna) public {
    require(msg.sender == penguinoToOwner[_penguinoId]);
    Penguino storage myPenguino = penguinos[_penguinoId];
    _targetDna = _targetDna % dnaModulus;
    uint newDna = (myPenguino.dna + _targetDna) / 2;
    // Add an if statement here
    _createPenguino("NoName", newDna);
  }

  function feedOnKitty(uint _penguinoId, uint _kittyId) public {
    uint kittyDna;
    (,,,,,,,,,kittyDna) = kittyContract.getKitty(_kittyId);
    // And modify function call here:
    feedAndMultiply(_penguinoId, kittyDna);
  }

}