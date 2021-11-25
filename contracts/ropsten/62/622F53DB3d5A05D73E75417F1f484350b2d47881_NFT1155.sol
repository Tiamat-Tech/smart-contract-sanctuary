// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

contract NFT1155 is ERC1155, Ownable, AccessControl, Pausable, ERC1155Burnable {

    /* Variable */
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    string public name = "NFT1155";

    /* Constructor */
    constructor() ERC1155("https://item.ohdat.io/battle-mech/") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(URI_SETTER_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    /**
     * @dev get the URI of this nft_token_id.
     * @param _id the token_id will be checked.
     */
    function uri(uint256 _id) public override view returns (string memory) {
        string memory id = uint2str(_id);
        string memory baseURI = super.uri(_id);
        return string(abi.encodePacked(baseURI, id));
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k - 1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    function setURI(string memory newuri) public onlyRole(URI_SETTER_ROLE) {
        _setURI(newuri);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address account, uint256 id, uint256 amount, bool specifyCreator) public onlyRole(MINTER_ROLE) {
        address _owner = owner();
        if (specifyCreator) {
            _mint(account, id, amount, abi.encode(_owner));
        } else {
            _mint(account, id, amount, abi.encode(msg.sender));
        }
    }

    function airdrop(uint160[] memory to, uint256[] memory ids, bytes memory data)
    public
    onlyRole(MINTER_ROLE)
    {
        for (uint256 i = 0; i < ids.length; i++) {
            address ss = address(to[i]);
            _mint(ss, ids[i], 1, data);
        }
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bool specifyCreator) public onlyRole(MINTER_ROLE) {
        address _owner = owner();
        if (specifyCreator) {
            _mintBatch(to, ids, amounts, abi.encode(_owner));
        } else {
            _mintBatch(to, ids, amounts, abi.encode(msg.sender));
        }
    }

    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)
    internal
    whenNotPaused
    override
    {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    function supportsInterface(bytes4 interfaceId)
    public
    view
    override(ERC1155, AccessControl)
    returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}