// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";

contract SharkNFT is ERC721, ERC721Enumerable, Pausable, AccessControl, ERC721Burnable {
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    string public tokenURIPrefix = "https://sharkshakesea.com/erc/721/shark/";
    string public tokenURISuffix = ".json";

    struct Shark {
        uint256 genes;
        uint256 bornAt;
    }

    Shark[] sharks;

    event SharkBorned(uint256 indexed _sharkId, address indexed _owner, uint256 _genes);
    event SharkRebirthed(uint256 indexed _sharkId, uint256 _genes);
    event SharkRetired(uint256 indexed _sharkId);
    event SharkEvolved(uint256 indexed _sharkId, uint256 _oldGenes, uint256 _newGenes);

    constructor() ERC721("MyNFT", "MTK") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        return string(abi.encodePacked(tokenURIPrefix, tokenId, tokenURISuffix));
    }

    function setTokenURIAffixes(string memory _prefix, string memory _suffix) external onlyRole(DEFAULT_ADMIN_ROLE) {
        tokenURIPrefix = _prefix;
        tokenURISuffix = _suffix;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    // TODO Access control
    function bornShark(uint256 _sharkId, uint256 _genes, address _owner) external onlyRole(MINTER_ROLE) {
        return _bornShark(_sharkId, _genes, _owner);
    }

    // TODO Access control
    function rebirthShark(
        uint256 _sharkId,
        uint256 _genes
    )
        external
    {
        Shark storage _shark = sharks[_sharkId];
        _shark.genes = _genes;
        _shark.bornAt = block.timestamp;
        SharkRebirthed(_sharkId, _genes);
    }
    
    // TODO Access control
    function retireShark(
        uint256 _sharkId
    ) 
        external
    {
        _burn(_sharkId);

        SharkRetired(_sharkId);
    }

    // TODO Access control
    function evolveShark(
        uint256 _sharkId,
        uint256 _newGenes
    )
        external
    {
        uint256 _oldGenes = sharks[_sharkId].genes;
        sharks[_sharkId].genes = _newGenes;
        SharkEvolved(_sharkId, _oldGenes, _newGenes);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function _bornShark(uint256 _sharkId, uint256 _genes, address _owner) private {
        Shark memory _shark = Shark(_genes, block.timestamp);
        sharks.push(_shark);
        _mint(_owner, _sharkId);
        SharkBorned(_sharkId, _owner, _genes);
    }
}