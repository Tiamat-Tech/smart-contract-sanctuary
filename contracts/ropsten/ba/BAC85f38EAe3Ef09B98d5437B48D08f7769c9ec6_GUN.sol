// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract GUN is ERC721, AccessControl {
    using Counters for Counters.Counter;

    mapping(uint256 => string) private _tokenUri;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    Counters.Counter private _tokenIds;

    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, _msgSender()), "Error: Admin role required");
        _;
    }

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, _msgSender()), "Error: Minter role required");
        _;
    }

    modifier onlyOwnerOf(uint256 tokenId) {
        require(_msgSender() == ownerOf(tokenId));
        _;
    }

    constructor(address multisigAddress) ERC721("PlanetSandbox GUN", "GUN") {
        renounceRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(DEFAULT_ADMIN_ROLE, multisigAddress);
    }

    function approveBatch(address to, uint256[] memory tokenIds) external {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            approve(to, tokenIds[i]);
        }
    }

    function mint(
        address to,
        string memory tokenUri,
        uint256 amount
    ) external onlyMinter returns (uint256[] memory ids) {
        ids = new uint256[](amount);

        for (uint256 i = 0; i < amount; i++) {
            _tokenIds.increment();

            uint256 newTokenId = _tokenIds.current();

            _mint(to, newTokenId);
            _tokenUri[newTokenId] = tokenUri;

            ids[i] = newTokenId;
        }
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "Error: URI query for nonexistent token");
        return _tokenUri[tokenId];
    }

    function burn(uint256 tokenId) external onlyOwnerOf(tokenId) {
        _burn(tokenId);
    }

    function currentTokenId() external view returns (uint256) {
        return _tokenIds.current();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function withdrawERC20(address token) external onlyAdmin {
        require(IERC20(token).transfer(_msgSender(), IERC20(token).balanceOf(address(this))), "Transfer failed");
    }

    function withdrawERC721(IERC721 token, uint256[] memory ids) external onlyAdmin {
        for (uint256 i = 0; i < ids.length; i++) {
            IERC721(token).transferFrom(address(this), _msgSender(), ids[i]);
        }
    }

    function withdrawERC1155(
        address token,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external onlyAdmin {
        IERC1155(token).safeBatchTransferFrom(address(this), _msgSender(), ids, amounts, data);
    }
}