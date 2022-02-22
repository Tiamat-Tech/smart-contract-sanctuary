// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

contract ERC1155 is IERC1155 {
    using Address for address;

    mapping(uint256 => mapping(address => uint256)) public _balances;
    mapping(address => mapping(address => bool)) public _operatorApprovals;

    function balanceOf(address account, uint256 id)
        external
        view
        returns (uint256)
    {
        require(
            account != address(0),
            "ERC1155: balance query for zero address"
        );
        return _balances[id][account];
    }

    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory)
    {
        require(
            accounts.length == ids.length,
            "ERC1155: accounts array and ids array of unequal length"
        );
        uint256[] memory balances = new uint256[](accounts.length);
        for (uint256 i = 0; i < accounts.length; i++) {
            balances[i] = this.balanceOf(accounts[i], ids[i]);
        }
        return balances;
    }

    function setApprovalForAll(address operator, bool approved) external {
        require(
            operator != msg.sender,
            "ERC1155: owner address equals operator"
        );
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address account, address operator)
        external
        view
        returns (bool)
    {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external {
        require(
            _isOwnerOrApproved(from),
            "ERC1155: msg.sender is not owner not approved operator"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    function _isOwnerOrApproved(address account) internal view returns (bool) {
        return msg.sender == account || _operatorApprovals[account][msg.sender];
    }

    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) internal {
        require(to != address(0), "ERC1155: 'to' equals zero address");
        require(from != to, "ERC1155: 'from' equals 'to'");
        require(
            _balances[id][from] >= amount,
            "ERC1155: insufficient balance to transfer amount"
        );

        unchecked {
            _balances[id][from] -= amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);
        _doSafeTransferAcceptanceCheck(msg.sender, from, to, id, amount, data);
    }

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC1155Receiver(to).onERC1155Received(
                    operator,
                    from,
                    id,
                    amount,
                    data
                )
            returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external {
        require(
            _isOwnerOrApproved(from),
            "ERC1155: msg.sender is not owner not approved operator"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) internal {
        require(to != address(0), "ERC1155: 'to' equals zero address");
        require(from != to, "ERC1155: 'from' equals 'to'");
        require(
            ids.length == amounts.length,
            "ERC1155: length of 'ids' array unequals length of 'amounts' array"
        );
        address operator = msg.sender;
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 amount = amounts[i];
            uint256 id = ids[i];
            uint256 ownerBalance = _balances[id][from];

            require(
                ownerBalance >= amount,
                "ERC1155: insufficient balance for transfer amount"
            );
            unchecked {
                _balances[id][from] -= amount;
            }
            _balances[id][to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);
        _doSafeBatchTransferAcceptanceCheck(
            operator,
            from,
            to,
            ids,
            amounts,
            data
        );
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try
                IERC1155Receiver(to).onERC1155BatchReceived(
                    operator,
                    from,
                    ids,
                    amounts,
                    data
                )
            returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        require(to != address(0), "ERC1155: cannot mint to zero address");
        address operator = msg.sender;

        _balances[id][to] += amount;

        emit TransferSingle(operator, address(0), to, id, amount);
        _doSafeTransferAcceptanceCheck(
            operator,
            address(0),
            to,
            id,
            amount,
            data
        );
    }

    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        require(to != address(0), "ERC1155: cannot mint to zero address");
        address operator = msg.sender;
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 amount = amounts[i];
            uint256 id = ids[i];
            _balances[id][to] += amount;
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);
        _doSafeBatchTransferAcceptanceCheck(
            operator,
            address(0),
            to,
            ids,
            amounts,
            data
        );
    }

    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal {
        require(from != address(0), "ERC1155: cannot burb from zero address");
        address operator = msg.sender;
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 amount = amounts[i];
            uint256 id = ids[i];

            uint256 fromBalance = _balances[id][from];
            require(
                fromBalance >= amount,
                "ERC1155: insufficient balance to burn amount"
            );
            _balances[id][from] = fromBalance - amount;
        }

        emit TransferBatch(operator, from, address(0), ids, amounts);
    }

    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal {
        require(from != address(0), "ERC1155: cannot burb from zero address");
        address operator = msg.sender;
        uint256 fromBalance = _balances[id][from];
        require(
            fromBalance >= amount,
            "ERC1155: insufficient balance to burn amount"
        );
        _balances[id][from] = fromBalance - amount;

        emit TransferSingle(operator, from, address(0), id, amount);
    }

    function supportsInterface(bytes4 interfaceId) public pure  returns (bool) {
        return interfaceId == type(IERC1155).interfaceId;
    }
}