// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "openzeppelin-solidity/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "openzeppelin-solidity/contracts/access/AccessControl.sol";
import "openzeppelin-solidity/contracts/utils/cryptography/ECDSA.sol";

contract ERC1155Main is ERC1155Burnable, AccessControl {
    bytes32 public SIGNER_ROLE = keccak256("SIGNER_ROLE");

    address public factory;

    constructor(string memory uri_, address _exchange, address signer) ERC1155(uri_) {
        factory = _msgSender();
        _setupRole(DEFAULT_ADMIN_ROLE, signer);
        _setupRole(SIGNER_ROLE, signer);
        setApprovalForAll(_exchange, true);
    }

    function mint(
        uint256 id,
        uint256 amount,
        bytes calldata signature
    ) external {
        _verifySigner(id, amount, signature);
        _mint(_msgSender(), id, amount, "");
    }

    function mint(
        uint256 id,
        uint256 amount,
        bytes memory data,
        bytes calldata signature
    ) external {
        _verifySigner(id, amount, signature);
        _mint(_msgSender(), id, amount, data);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC1155)
        returns (bool)
    {
        return
            ERC1155.supportsInterface(interfaceId) ||
            AccessControl.supportsInterface(interfaceId);
    }

    function _verifySigner(
        uint256 id,
        uint256 amount,
        bytes calldata signature
    ) private view {
        address signer =
            ECDSA.recover(
                keccak256(abi.encodePacked(this, id, amount)),
                signature
            );
        require(
            hasRole(SIGNER_ROLE, signer),
            "ERC1155Main: Signer should sign transaction"
        );
    }
}