// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./BridgeReceiver.sol";
import "./IERC721Mintable.sol";
import "./IERC20Mintable.sol";


contract Bridge is BridgeReceiver {
    string internal chainName;
    uint256 internal eventId = 0;
    mapping(address => bool) internal allowedErc20;
    mapping(address => bool) internal allowedErc721;

    mapping(string => mapping (address => mapping(uint256 => bool))) internal claimed;

    /**
    * @dev Checks if message sender has admin role assigned.
    */
    modifier onlyAdmin() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Only admins");
        _;
    }

    constructor (string memory chainName_) {
        chainName = chainName_;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function addSupportedErc20Contract(address erc20Contract) external override onlyAdmin {
        require(allowedErc20[erc20Contract] == false, "Contract already supported");

        allowedErc20[erc20Contract] = true;
    }

    function removeSupportedErc20Contract(address erc20Contract) external override onlyAdmin {
        require(allowedErc20[erc20Contract] == true, "Contract not supported");

        delete allowedErc20[erc20Contract];
    }

    function _createMessageHash(string memory sourceChainName, address sourceErc20, uint256 id, uint256 amount, address sendTo, address destinationErc20) internal override view returns (bytes32) {
        return keccak256(abi.encodePacked(sourceChainName, sourceErc20, id, amount, sendTo, destinationErc20, chainName));
    }

    function depositErc20AndWrapToMe(uint256 amount, address erc20) external {
        return depositErc20AndWrap(amount, erc20, msg.sender);
    }

    function depositErc20AndWrap(uint256 amount, address erc20, address recipient) public {
        require(allowedErc20[erc20], "Contract not supported");

        emit DepositErc20(chainName, erc20, eventId, amount, recipient);
        eventId += 1;

        require(IERC20(erc20).transferFrom(msg.sender, address(this), amount) == true, "transferFrom failed for unknown reason");
    }

    function mintErc20(string memory sourceChainName, address sourceContractAddress, uint256 id, uint256 value,
        address toAddress, address destinationContractAddress) external onlyAdmin {
        require(!claimed[sourceChainName][sourceContractAddress][id], "This was already claimed");

        claimed[sourceChainName][sourceContractAddress][id] = true;
        emit WithdrawErc20(sourceChainName, sourceContractAddress, id, value, toAddress, destinationContractAddress);
        IERC20Mintable(destinationContractAddress).mintTo(toAddress, value);
    }

    function addSupportedErc721Contract(address erc721Contract) external override onlyAdmin {
        require(allowedErc721[erc721Contract] == false, "Contract already supported");

        allowedErc721[erc721Contract] = true;
    }

    function removeSupportedErc721Contract(address erc721Contract) external override onlyAdmin {
        require(allowedErc721[erc721Contract] == true, "Contract not supported");

        delete allowedErc721[erc721Contract];
    }

    function depositErc721AndWrapToMe(uint256 id, address erc721) external {
        return depositErc721AndWrap(id, erc721, msg.sender);
    }

    function depositErc721AndWrap(uint256 id, address erc721, address recipient) public {
        require(allowedErc721[erc721], "Contract not supported");

        emit DepositErc721(chainName, erc721, eventId, id, recipient);
        eventId += 1;

        IERC721(erc721).transferFrom(msg.sender, address(this), id);
    }

    function mintErc721(string memory sourceChainName, address sourceContractAddress, uint256 id, uint256 tokenId,
        address toAddress, address destinationContractAddress) external onlyAdmin {
        require(!claimed[sourceChainName][sourceContractAddress][id], "This was already claimed");

        claimed[sourceChainName][sourceContractAddress][id] = true;
        emit WithdrawErc721(sourceChainName, sourceContractAddress, id, tokenId, toAddress, destinationContractAddress);
        IERC721Mintable(destinationContractAddress).mintTo(toAddress, tokenId);
    }

    function isErc20Allowed(address erc20) external view returns(bool) {
        return allowedErc20[erc20];
    }

    function isErc721Allowed(address erc721) external view returns(bool) {
        return allowedErc721[erc721];
    }
}