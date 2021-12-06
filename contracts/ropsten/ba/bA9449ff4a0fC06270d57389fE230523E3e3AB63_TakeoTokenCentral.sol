pragma solidity >=0.6.0 <0.8.5;
pragma experimental ABIEncoderV2;
//SPDX-License-Identifier: MIT

//import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

//外のコントラクトに情報を送るために必要なやつ（Interface)
interface ITakeoToken {
  function backcounter() external view returns (uint256);
  function transfer(address from, address to, uint256 tokenId) external;
}

contract TakeoTokenCentral is ITakeoToken, ERC721, Ownable {

  using Counters for Counters.Counter;
  Counters.Counter public counter; // struct Counter { _value }

  /////interface用1
  function backcounter() external view override returns (uint256) {
    uint256 nowcounter = counter.current();
    return nowcounter; 
  } 

  /////interface用2
  function transfer(address from, address to, uint256 tokenId) external override{
    _transfer(from, to, tokenId);
  }

/////ERC721EnumerableMockのstring private _baseTokenURI;に引数の文字型を格納
/////ERC721内のstring private _name;とstring private _symbol;に引数の名前とシンボルを格納
  constructor() public ERC721("TakeoTokenCentral", "TTC") {
/////ベースURIをセット、これにトークンURIの文字列をつなげて一つのURLにする（フロント側で行う、これは容量削減のための処理）
    _setBaseURI("https://ipfs.io/ipfs/");
  }

  function mintItem(address to, string memory tokenURI)
      public
      onlyOwner
      returns (uint256)
  {
    /////カウンタを１上げる。（カウンタの役割＜１：後のガチャの上限を見るため ２：特定アドレスと今のカウンタの数値を紐づけるため＞）
      counter.increment();
      /////idに今のカウンタの数値を格納
      uint256 id = counter.current();
      /////_tokenOwners;のEnumerableMapはなんとなく分かった
      _mint(to, id);
      /////ERC721内のmapping (uint256 => string) private _tokenURIs;にトークンIDへURIを格納
      _setTokenURI(id, tokenURI);

      return id;
  }

}