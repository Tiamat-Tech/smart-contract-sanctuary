pragma solidity >=0.6.0 <0.8.5;
pragma experimental ABIEncoderV2;
//SPDX-License-Identifier: MIT

//import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
//import "@openzeppelin/contracts/utils/Counters.sol"; 使ってなくね？のためCO
import "@openzeppelin/contracts/access/Ownable.sol";
import "./TakeoTokenCentral.sol";
/////learn more: https://docs.openzeppelin.com/contracts/3.x/erc721

contract TakeoGacha is Ownable {
//  using Counters for Counters.Counter; 使ってなくね？のためCO

/////後にTakeoTokenCentralのコントラクト内の情報を書き換えるときにコントラクトアドレスを使用するので定義
  address takeoToken;
/////抽選用の箱を作る
  uint256[] public BackNumbers; //　抽選番号

/////ガチャコントラクトに武雄トークン本体のアドレスを紐づけるための処理,デプロイ時に引数として設定します
  constructor(address _token) public {
    takeoToken = _token;
  }

  function initLottery() public onlyOwner {
    uint256 _counter = ITakeoToken(takeoToken).backcounter();

    // Note: current() is 30 if you've minted all.
    for (uint i = 1; i <= _counter; i ++) {
      BackNumbers.push(i);
    }
  }

  function getGacha() public {
    uint256 _counter = ITakeoToken(takeoToken).backcounter();
    bytes32 RandBase = keccak256(abi.encode(msg.sender, block.timestamp));
    uint256 r = uint256(RandBase) % _counter;
    ITakeoToken(takeoToken).transfer(address(this),msg.sender,BackNumbers[r]);//address(this)は自分のアドレスを指す
    (BackNumbers[r],BackNumbers[BackNumbers.length - 1]) = (BackNumbers[BackNumbers.length-1],BackNumbers[r]);
    BackNumbers.pop();

  }

}