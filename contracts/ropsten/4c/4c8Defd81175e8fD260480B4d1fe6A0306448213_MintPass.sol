//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165Storage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "./interface/IMintPass.sol";

contract MintPass is IERC1155MetadataURI, ERC1155Supply, AccessControl, IERC2981, ERC165Storage, IMintPass {

    bytes32 public constant MINT_ROLE = keccak256("MINT");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER");

    address royaltyAddress;
    uint256 royaltyPercentage;

    constructor(string memory uri_, address royaltyAddress_, uint256 royaltyPercentage_) ERC1155(uri_) {
        require(royaltyPercentage_ <= 10000, "royaltyPercentage_ must be lte 10000.");
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINT_ROLE, _msgSender());
        _setupRole(BURNER_ROLE, _msgSender());

        _setRoleAdmin(MINT_ROLE, DEFAULT_ADMIN_ROLE);
        _setRoleAdmin(BURNER_ROLE, DEFAULT_ADMIN_ROLE);

        royaltyAddress = royaltyAddress_;
        royaltyPercentage = royaltyPercentage_;

        _registerInterface(type(IERC2981).interfaceId);
        _registerInterface(type(IERC1155).interfaceId);
        _registerInterface(type(ERC1155Supply).interfaceId);
        _registerInterface(type(IERC1155MetadataURI).interfaceId);
        _registerInterface(type(AccessControl).interfaceId);

    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Storage, IERC165, ERC1155, AccessControl) returns (bool) {
        return ERC165Storage.supportsInterface(interfaceId);
    }

    function burn(
        address account,
        uint256 id,
        uint256 amount
    ) public  onlyRole(BURNER_ROLE) {
        ERC1155Supply._burn(account, id, amount);
    }

    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    )  public  onlyRole(BURNER_ROLE) {
        ERC1155Supply._burnBatch(account, ids, amounts);
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyRole(MINT_ROLE) {
        ERC1155Supply._mint(account, id, amount, data);

    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyRole(MINT_ROLE){
        ERC1155Supply._mintBatch(to, ids, amounts, data);
    }

    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view override returns (address royaltyReceiver, uint256 royaltyAmount) {
        royaltyReceiver = royaltyAddress;
        royaltyAmount = salePrice * royaltyPercentage / 10000;
    }
}