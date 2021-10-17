// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract TheDiary is ERC721, ReentrancyGuard, Ownable {
  using SafeMath for uint256;
  using SafeCast for int256;
  using Strings for uint256;
  using Counters for Counters.Counter;

  struct Diary {
        uint256 timestamp;
        string message;
  }

  Counters.Counter private _tokenIds;
  // maps tokenId timestamp to diary
  mapping (uint256 => Diary) internal _diaries;
  // maps timestamp to tokenId
  mapping (uint256 => uint256) internal _diaryMap;


  // mint price for every second
  uint256 public initPrice = 0.1 ether;
  uint256 public deployTs;
  uint256 public maxMsgSize;
  uint256 public latestMintDay;

  constructor() ERC721("The Diary", "DIARY") {
    uint256 _now = block.timestamp;
    deployTs = _now.sub(_now.mod(86400));
    latestMintDay = deployTs;
    maxMsgSize = 8000;
  }

  // Unix timestamp of the day in epoch seconds (GMT)
  function mint(uint256 epochSeconds, string memory message) external nonReentrant payable {
    require(bytes(message).length < maxMsgSize, "msg is too long.");
    uint256 _now = block.timestamp;
    uint256 requestedDay = epochSeconds.sub(epochSeconds.mod(86400));
    uint256 today = _now.sub(_now.mod(86400));
    require(requestedDay <= today, "Future mint is not allowed.");
    require(requestedDay >= deployTs, "Too old.");
    require(_diaryMap[requestedDay] == uint256(0x0), "Already claimed");
    uint256 mintPice = initPrice;
    uint256 startPrice = initPrice;
    uint256 daysSinceLatestMint = (today.sub(latestMintDay)).div(86400);
    if(daysSinceLatestMint > 2){
      // last two days were not sold, adapt the initial price
      startPrice = startPrice.div(daysSinceLatestMint.mul(2));
      if(startPrice < 0.1 ether) {
        startPrice = 0.1 ether;
      }
    }
    uint256 _hours = (_now.sub(today)).div(3600);
    if(requestedDay < today) {
      // date is out of auction
      mintPice = mintPice.div(20);
    } else {
      mintPice = startPrice.sub(startPrice.div(25).mul(_hours));
      if(mintPice < startPrice.div(20)) {
        mintPice = startPrice.div(20);
      }
    }
    require( msg.value >= mintPice, "Not enough Ether to mint the tokens.");
    if (msg.value > mintPice) {
      payable(msg.sender).transfer(msg.value - mintPice);
    }
    if(mintPice == initPrice) {
      initPrice = initPrice.mul(2);
    } else if (_hours > 22 && requestedDay == today) {
      initPrice = startPrice.div(2);
      if(initPrice < 0.1 ether) {
        initPrice = 0.1 ether;
      }
      startPrice = mintPice;
    }
    Diary memory diary;
    diary.timestamp = requestedDay;
    diary.message = message;

    _tokenIds.increment();
    uint256 newNftTokenId = _tokenIds.current();
    _diaryMap[requestedDay] = newNftTokenId;
    _diaries[newNftTokenId] = diary;
    if(requestedDay > latestMintDay) {
      latestMintDay = today;
    }
    _safeMint(msg.sender, newNftTokenId);
  }

  function calcMintPrice(uint256 timestamp) public view returns (uint256) {
    uint256 _now = block.timestamp;
    uint256 requestedDay = timestamp.sub(timestamp.mod(86400));
    uint256 today = _now.sub(_now.mod(86400));
    require(requestedDay <= today, "Future mint is not allowed.");
    require(requestedDay >= deployTs, "Too old.");
    require(_diaryMap[requestedDay] == uint256(0x0), "Already claimed");
    uint256 mintPice = initPrice;
    uint256 startPrice = initPrice;
    uint256 daysSinceLatestMint = today.sub(latestMintDay).div(86400);
    if(daysSinceLatestMint > 2){
      // last two days were not sold, adapt the initial price
      startPrice = startPrice.div(daysSinceLatestMint.mul(2));
      if(startPrice < 0.1 ether) {
        startPrice = 0.1 ether;
      }
    }
    uint256 _hours = (_now.sub(today)).div(3600);
    if(requestedDay < today) {
      // date is out of auction
      mintPice = mintPice.div(20);
    } else {
      mintPice = startPrice.sub(startPrice.div(25).mul(_hours));
      if(mintPice < startPrice.div(20)) {
        mintPice = startPrice.div(20);
      }
    }
    return mintPice;
  }

  function getTokenId(uint256 timestamp) public view returns(uint256){
    uint256 _ts = timestamp.sub(timestamp.mod(86400));
    return _diaryMap[_ts];
  }

  function getDiaryByTimestamp(uint256 timestamp) public view returns(Diary memory){
    uint256 _ts = timestamp.sub(timestamp.mod(86400));
    return _diaries[_diaryMap[_ts]];
  }

  function getDiary(uint256 tokenId) public view returns(Diary memory){
    return _diaries[tokenId];
  }

  function tokenURI(uint256 tokenId) override public view returns(string memory) {
      string[4] memory parts;
      parts[0] = '<svg xmlns="http://www.w3.org/2000/svg" preserveAspectRatio="xMinYMin meet" viewBox="0 0 350 350"><style>.base { fill: black; font-family: serif; font-size: 14px; }</style><rect width="100%" height="100%" fill="white" /><text x="10" y="20" class="base">';
      Diary memory _diary = _diaries[tokenId];
      uint256 _time = _diary.timestamp;
      uint256 _day = (_time.sub(deployTs)).div(86400);
      // starts from zero
      _day = _day.add(1);
      parts[1] =  string(abi.encodePacked(_diary.message));
      parts[2] = '</text><text x="10" y="40" class="base">';
      parts[3] = '</text></svg>';
      string memory output = string(abi.encodePacked(parts[0], parts[1], parts[2], parts[3]));
      string memory json = Base64.encode(bytes(string(abi.encodePacked('{"name": "Day #', _day.toString(), '", "description": "One single diary per day can be minted. Future mint is not allowed. Timestamp of the diary refers to the 00:00:00 of the day in GMT.", "image": "data:image/svg+xml;base64,', Base64.encode(bytes(output)), '"}'))));
      output = string(abi.encodePacked('data:application/json;base64,', json));
      return output;
  }

  function getString(int256 value) internal pure returns (string memory){
    if(value >= 0) {
      return value.toUint256().toString();
    } else {
      value = -1 * value;
      return string(abi.encodePacked('-' , value.toUint256().toString()));
    }
  }

  function setMaxMsgSize(uint256 _msgSize) external onlyOwner {
       maxMsgSize = _msgSize;
  }

}

/// [MIT License]
/// @title Base64
/// @notice Provides a function for encoding some bytes in base64
/// @author Brecht Devos <[email protected]>
library Base64 {
    bytes internal constant TABLE = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    /// @notice Encodes some bytes to the base64 representation
    function encode(bytes memory data) internal pure returns (string memory) {
        uint256 len = data.length;
        if (len == 0) return "";

        // multiply by 4/3 rounded up
        uint256 encodedLen = 4 * ((len + 2) / 3);

        // Add some extra buffer at the end
        bytes memory result = new bytes(encodedLen + 32);

        bytes memory table = TABLE;

        assembly {
            let tablePtr := add(table, 1)
            let resultPtr := add(result, 32)

            for {
                let i := 0
            } lt(i, len) {

            } {
                i := add(i, 3)
                let input := and(mload(add(data, i)), 0xffffff)

                let out := mload(add(tablePtr, and(shr(18, input), 0x3F)))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(12, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(shr(6, input), 0x3F))), 0xFF))
                out := shl(8, out)
                out := add(out, and(mload(add(tablePtr, and(input, 0x3F))), 0xFF))
                out := shl(224, out)

                mstore(resultPtr, out)

                resultPtr := add(resultPtr, 4)
            }

            switch mod(len, 3)
            case 1 {
                mstore(sub(resultPtr, 2), shl(240, 0x3d3d))
            }
            case 2 {
                mstore(sub(resultPtr, 1), shl(248, 0x3d))
            }

            mstore(result, encodedLen)
        }

        return string(result);
    }
}