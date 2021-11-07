// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

import "hardhat/console.sol";

/// @title Sisterhood of the Knives
/// @author KIRA (twitter.com/rtm1s)
contract HANA is ERC721Enumerable, Ownable, Pausable {
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIds;

    mapping(address => bool) private _allowList;
    mapping(address => uint256) private _allowListClaimed;

    uint256 public constant PRICE = 0.04444 ether;
    uint256 public constant MAX_SUPPLY = 8888;
    uint256 public constant PURCHASE_LIMIT = 20;
    uint256 public constant PRESALE_PURCHASE_LIMIT = 5;

    string private _baseTokenURI = "https://sisterhoodoftheknives.com/api/";
    bool private _preSalePaused = true;
    uint256 private _reserved = 96; // 100 - 4 for the team

    /// @dev team address
    address t1 = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address t2 = 0x70997970C51812dc3A010C7d01b50e0d17dc79C8;
    address t3 = 0x90F79bf6EB2c4f870365E785982E1f101E93b906;

    /// @dev events
    event AddedToAllowList(address[] addresses);

    constructor() ERC721("Sisterhood of the Knives", "HANA") {
        // // team gets the first 4 Hanas
        // _safeMint(t1, 1);
        // _safeMint(t2, 2);
        // _safeMint(t3, 3);
        // _safeMint(t3, 4);

        // _tokenIds.increment();
        // _tokenIds.increment();
        // _tokenIds.increment();
        // _tokenIds.increment();

        _pause();
    }

    function addToAllowList(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Can't add the null address");
            _allowList[addresses[i]] = true;
            _allowListClaimed[addresses[i]] > 0
                ? _allowListClaimed[addresses[i]]
                : 0;
        }

        emit AddedToAllowList(addresses);
    }

    function onAllowList(address addr) external view returns (bool) {
        return _allowList[addr];
    }

    function removeFromAllowList(address[] calldata addresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Can't add the null address");
            _allowList[addresses[i]] = false;
        }
    }

    function clone(uint256 num) public payable {
        uint256 supply = totalSupply();

        require(!paused(), "Sale paused");
        require(num < 21, "You can clone a maximum of 20");
        require(
            supply + num < MAX_SUPPLY - _reserved,
            "Exceeds maximum clone supply"
        );
        require(msg.value >= PRICE * num, "Ether sent is not correct");

        for (uint256 i; i < num; i++) {
            _tokenIds.increment();
            uint256 newTokenId = _tokenIds.current();

            _safeMint(msg.sender, newTokenId);
        }
    }

    function giveaway(address to) public onlyOwner {
        require(_reserved > 0, "Reserved are all used");

        _tokenIds.increment();
        _safeMint(to, _tokenIds.current());
        _reserved -= 1;
    }

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function flipSaleState() public onlyOwner {
        _unpause();
    }
}