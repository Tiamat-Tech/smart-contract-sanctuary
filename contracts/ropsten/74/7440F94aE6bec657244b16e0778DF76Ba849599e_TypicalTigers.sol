// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";


contract TypicalTigers is ERC721Enumerable, Ownable, AccessControlEnumerable {
    bytes32 public constant WHITELISTED_ROLE = keccak256("WHITELISTED_ROLE");
    uint256 public mintPrice = 30000000000000000; //0.03 ETH
    uint256 public maxPurchase = 10;
    bool public saleIsActive = false;

    uint256 public maxSupply = 3900;

    string _baseTokenURI;

    event SaleActivation(bool isActive);

    constructor() ERC721("TypicalTigers", "TPT") {
        // Grant the contract deployer the default admin role: it will be able
        // to grant and revoke any roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, AccessControlEnumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function addToWhitelist(address _account) external {
        grantRole(WHITELISTED_ROLE, _account);
    }

    function removeFromWhitelist(address _account) external {
        revokeRole(WHITELISTED_ROLE, _account);
    }

    function isWhitelistedAccount(address _account) public view returns (bool) {
        return hasRole(WHITELISTED_ROLE, _account);
    }

    function clearWhitelist() external {
       uint256  whitelistCount = getRoleMemberCount(WHITELISTED_ROLE);
        for (uint256 i = 0; i < whitelistCount; i++) {
            address member =  getRoleMember(WHITELISTED_ROLE, i);
            revokeRole(WHITELISTED_ROLE, member);
        }
}

    function devMint(address _to, uint256 _count) external onlyOwner {
        require(
            totalSupply() + _count <= maxSupply,
            "Purchase would exceed max supply of Typical Tigers"
        );

        for (uint256 i = 0; i < _count; i++) {
            uint256 mintIndex = totalSupply();
            if (totalSupply() < maxSupply) {
                _safeMint(_to, mintIndex);
            }
        }
    }

    function mint(address _to, uint256 _count) external payable {
        require(saleIsActive || isWhitelistedAccount(msg.sender), "Sale must be active to mint Typical Tiger");

        require(_count <= maxPurchase, "Can only mint 10 tokens at a time");

        require(
            totalSupply() + _count <= maxSupply,
            "Purchase would exceed max supply of Typical Tigers"
        );
        require(
            mintPrice * _count <= msg.value,
            "Ether value sent is not correct"
        );

        for (uint256 i = 0; i < _count; i++) {
            uint256 mintIndex = totalSupply();
            if (totalSupply() < maxSupply) {
                _safeMint(_to, mintIndex);
            }
        }
    }

    function setSaleIsActive(bool _active) external onlyOwner {
        saleIsActive = _active;
        emit SaleActivation(_active);
    }

    function setMintPrice(uint256 _mintPrice) external onlyOwner {
        mintPrice = _mintPrice;
    }

    function setMaxPurchase(uint256 _maxPurchase) external onlyOwner {
        maxPurchase = _maxPurchase;
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function getTotalSupply() external view returns (uint256) {
        return totalSupply();
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }


    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }
}