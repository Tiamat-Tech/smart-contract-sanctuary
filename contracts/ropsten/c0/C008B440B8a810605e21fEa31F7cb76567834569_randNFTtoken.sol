// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract randNFTtoken is ERC1155, Ownable {
    IERC1155 public tokenNFT = IERC1155(address(this));
    mapping(uint256 => string) public _uris;
    mapping(address => uint256) public TokenId;
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;
    uint256[] rare = [1, 1, 1, 1, 2, 2, 2, 3, 3, 4];
    uint256 indexRare;
    mapping(uint256 => RandNFT) public tokenDetails;

    struct RandNFT {
        uint256 id;
        uint256 rare;
        uint256 data;
        string uri;
    }

    RandNFT[] RandNFTs;

    constructor() ERC1155("") {}

    function mint(
        address account,
        string memory _uri,
        bytes memory data
    ) public {
        uint256 date = block.timestamp;
        _tokenIdCounter.increment();
        indexRare =
            (uint256(keccak256(abi.encode(block.difficulty + block.number)))) %
            rare.length;
        TokenId[msg.sender] = _tokenIdCounter.current();
        tokenDetails[_tokenIdCounter.current()] = RandNFT(
            _tokenIdCounter.current(),
            rare[indexRare],
            date,
            _uri
        );
        _mint(account, _tokenIdCounter.current(), 1, data);
    }

    function setURI(uint256 id, string memory _uri) public {
        require(balanceOf(msg.sender, id) > 0);
        tokenDetails[id].uri = _uri;
    }

    function getTokenDetails(uint256 id) public view returns (RandNFT memory) {
        return tokenDetails[id];
    }

    function getNFTidFromAddress() external returns (uint256) {
        return TokenId[msg.sender];
    }
}