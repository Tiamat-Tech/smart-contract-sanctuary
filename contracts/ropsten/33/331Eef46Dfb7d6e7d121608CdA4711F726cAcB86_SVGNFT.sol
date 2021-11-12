// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "ERC721Enumerable.sol";
import "ReentrancyGuard.sol";
import "Ownable.sol";
// import "ERC721.sol";
import "Strings.sol";

contract SVGNFT is ERC721Enumerable, ReentrancyGuard, Ownable  {

  using Strings for uint256;
  
  uint256 public constant MAX_SUPPLY = 20;
  uint256 public constant PRICE = 0.00001 ether;
  uint256 public constant MAX_PER_TX = 10;
  uint256 public constant MAX_PER_ADDRESS = 20;
  uint256 public tokensMinted;
  bool public isSaleActive = true;

  mapping(address => uint256) private _mintedPerAddress;

  constructor() ERC721("The NFTSVG Project", "NFTSVG") {}

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    string memory name = string(abi.encodePacked("NFTSVG #", tokenId.toString()));
    string memory description = "On-chain SVGs.";
    string memory svgString = '<svg width="500" height="500" viewBox="0 0 500 500" xmlns="http://www.w3.org/2000/svg"><circle cx="250" cy="250" r="150" fill="green" /><text x="250" y="265" font-size="60" text-anchor="middle" fill="white">SVGNFT</text></svg>';
    
    string memory json = string(abi.encodePacked('{"name":"', name, '","description":"', description, '","image": "data:image/svg+xml;base64,', Base64.encode(bytes(svgString)), '"}'));
    return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(json))));
  }

  // required overrides

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
    return super.supportsInterface(interfaceId);
  }

      function _claim(uint256 numTokens) private {
        require(totalSupply() < MAX_SUPPLY, "All NFTs minted");
        require(
            totalSupply() + numTokens <= MAX_SUPPLY,
            "Minting exceeds max supply"
        );
        require(numTokens <= MAX_PER_TX, "Too many per transaction");
        require(numTokens > 0, "Must mint at least 1 NFT");
        require(
            _mintedPerAddress[_msgSender()] + numTokens <= MAX_PER_ADDRESS,
            "Exceeds wallet limit"
        );

        for (uint256 i = 0; i < numTokens; i++) {
            uint256 tokenId = tokensMinted + 1;
            _safeMint(_msgSender(), tokenId);
            tokensMinted += 1;
            _mintedPerAddress[_msgSender()] += 1;
        }
    }

    function toggleSale() public onlyOwner {
        isSaleActive = !isSaleActive;
    }

    function withdrawAll() public payable nonReentrant onlyOwner {
        require(payable(_msgSender()).send(address(this).balance));
    }


    function claim(uint256 numTokens) public payable virtual {
        require(isSaleActive, "Sale is not active");
        require(PRICE * numTokens == msg.value, "ETH amount is incorrect");
        _claim(numTokens);
    }

}



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