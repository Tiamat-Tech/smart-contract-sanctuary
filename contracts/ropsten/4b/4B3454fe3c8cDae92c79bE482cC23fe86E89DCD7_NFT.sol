// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFT is ERC721Enumerable, Ownable {
    using Strings for uint256;

    uint256 public constant MAX_PRIVATE_SUPPLY = 9;
    uint256 public constant MAX_PUBLIC_SUPPLY = 40;
    uint256 public constant MAX_SUPPLY = MAX_PRIVATE_SUPPLY + MAX_PUBLIC_SUPPLY;

    uint256 public cost = 0.06 ether;
    uint256 public whitelistCost = 0.00 ether;

    bool public isActive = false;
    bool public isWhitelistActive = false;

    uint256 public totalPrivateSupply;
    uint256 public totalPublicSupply;

    uint256 public maxMint = 1;
    uint256 public whitelistMaxMint = 1;

    string private _baseTokenURI = "";
    mapping(address => bool) private _whitelist;
    mapping(address => uint256) private _whitelistClaimed;

    constructor(string memory name, string memory symbol)
        ERC721(name, symbol)
    {}

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    function addToWhitelist(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(addresses[i] != address(0), "Can't add the null address");

            _whitelist[addresses[i]] = true;
            _whitelistClaimed[addresses[i]] > 0
                ? _whitelistClaimed[addresses[i]]
                : 0;
        }
    }

    function gift(address to, uint256 num) external onlyOwner {
        require(totalSupply() < MAX_SUPPLY + 1, "All tokens minted");
        require(
            totalPrivateSupply + num < MAX_PRIVATE_SUPPLY + 1,
            "Exceeds private supply"
        );

        for (uint256 i; i < num; i++) {
            totalPrivateSupply += 1;
            _safeMint(to, totalPrivateSupply);
        }
    }

    function mint(uint256 num) public payable {
        uint256 supply = totalSupply();

        require(isActive, "Contract is inactive");
        require(num < maxMint + 1, "Over max limit");
        require(supply < MAX_SUPPLY, "All tokens minted");
        require(totalPublicSupply < MAX_PUBLIC_SUPPLY, "Over max public limit");
        require(msg.value >= cost * num, "ETH sent is not correct");

        for (uint256 i; i < num; i++) {
            if (totalPublicSupply < MAX_PUBLIC_SUPPLY) {
                totalPublicSupply += 1;
                _safeMint(msg.sender, MAX_PRIVATE_SUPPLY + totalPublicSupply);
            }
        }
    }

    function isOnWhitelist(address addr) external view returns (bool) {
        return _whitelist[addr];
    }

    function removeFromWhitelist(address[] calldata addresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < addresses.length; i++) {
            require(
                addresses[i] != address(0),
                "Can't remove the null address"
            );

            _whitelist[addresses[i]] = false;
        }
    }

    function setActive(bool val) public onlyOwner {
        require(
            bytes(_baseTokenURI).length != 0,
            "Set Base URI before activating"
        );
        isActive = val;
    }

    function setBaseURI(string memory val) public onlyOwner {
        _baseTokenURI = val;
    }

    function setMaxMint(uint256 val) external onlyOwner {
        maxMint = val;
    }

    function setWhitelistActive(bool val) public onlyOwner {
        isWhitelistActive = val;
    }

    function setWhitelistPrice(uint256 val) public onlyOwner {
        whitelistCost = val;
    }

    function setWhitelistMaxMint(uint256 val) external onlyOwner {
        whitelistMaxMint = val;
    }

    function setPrice(uint256 val) public onlyOwner {
        cost = val;
    }

    function whitelistClaimedBy(address owner) external view returns (uint256) {
        require(owner != address(0), "Zero address not on Whitelist");

        return _whitelistClaimed[owner];
    }

    function whitelistMint(uint256 num) external payable {
        require(isWhitelistActive, "Whitelist is not active");
        require(_whitelist[msg.sender], "You are not on the Whitelist");
        require(totalSupply() < MAX_SUPPLY, "All tokens minted");
        require(num <= whitelistMaxMint, "Over max limit");
        require(totalPublicSupply < MAX_PUBLIC_SUPPLY, "Over max public limit");
        require(
            _whitelistClaimed[msg.sender] + num <= whitelistMaxMint,
            "Whitelist tokens already claimed"
        );
        require(whitelistCost * num <= msg.value, "ETH amount is not correct");

        for (uint256 i = 0; i < num; i++) {
            totalPublicSupply += 1;
            _whitelistClaimed[msg.sender] += 1;
            _safeMint(msg.sender, MAX_PRIVATE_SUPPLY + totalPublicSupply);
        }
    }

    function withdraw() public payable onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}