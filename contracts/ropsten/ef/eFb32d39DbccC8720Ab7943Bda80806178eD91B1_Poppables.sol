// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721A.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

// import "@openzeppelin/contracts/utils/Strings.sol";

contract Poppables is ERC721A, Ownable, ReentrancyGuard, AccessControl {
    using SafeMath for uint256;
    // using Strings for uint256;

    bool public saleIsActive = false;
    uint256 public price;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    uint256 private maxMintableSupply;

    string private _contractURI;
    string private _tokenBaseURI;
    uint256 private maxSupply;
    uint256 private _seed = 0;
    bool private _requestedVRF = false;

    event NFTMinted(bool state);

    constructor(address adminRoleAdress) ERC721A("Poppables", "POP") {
        price = 50000000000000000; //0.05 ETH
        maxMintableSupply = 1600;

        maxSupply = 9599;

        //testing only
        _seed = 30207470459964961279215818016791723193587102244018403859363363849439350753829;

        _contractURI = "https://www.poppables.io/opensea.json";
        _tokenBaseURI = "TBD - add address";

        //dev admin
        _setupRole(ADMIN_ROLE, adminRoleAdress);
        //contract owner
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function mintNFTs(uint256 quantity)
        external
        payable
        nonReentrant
        returns (bool)
    {
        require(saleIsActive, "Sales is not active");
        require(quantity >= 1 && quantity < 23, "Wrong quantity");

        require(
            totalSupply() + quantity <= maxMintableSupply,
            "Cannot mint more"
        );

        require(msg.value >= price.mul(quantity), "Not enough ETH");

        _safeMint(msg.sender, quantity);

        emit NFTMinted(true);

        return true;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        if (!_exists(tokenId)) revert URIQueryForNonexistentToken();

        return
            string(
                abi.encodePacked(_tokenBaseURI, metadataOf(tokenId), ".json")
            );
    }

    function metadataOf(uint256 tokenId) internal view returns (string memory) {
        uint256[] memory metaIds = new uint256[](maxSupply + 1);
        uint256 ss = _seed;

        for (uint256 i = 1; i <= maxSupply; i += 1) {
            metaIds[i] = i;
        }

        for (uint256 i = 1; i <= maxSupply; i += 1) {
            uint256 j = (uint256(keccak256(abi.encode(ss, i))) % (maxSupply));
            (metaIds[i], metaIds[j]) = (metaIds[j], metaIds[i]);
        }
        return Strings.toString(metaIds[tokenId]);
    }

    function toggleSale() external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Not admin");
        saleIsActive = !saleIsActive;
    }

    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function setContractURI(string memory contractUri) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Not admin");
        _contractURI = contractUri;
    }

    function setBaseURI(string memory baseURI) external {
        require(hasRole(ADMIN_ROLE, msg.sender), "Not admin");
        _tokenBaseURI = baseURI;
    }

    function setSeed(uint256 randomNumber) public {
        require(hasRole(ADMIN_ROLE, msg.sender), "Not admin");
        _requestedVRF = true;
        _seed = randomNumber;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721A, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}