// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract PunkPass is ERC1155, Ownable, Pausable, ERC1155Burnable, ERC1155Supply {
    using ECDSA for bytes32;

    mapping(bytes32 => bool) public executed;
    address internal signer;
    address public nftContract;

    event Claimed (uint256 amount, address minter, uint8 tokenId);

    constructor(address _signer) ERC1155("") {
        require(_signer != address(0), "check deploy script");
        signer = _signer;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function setSigner(address _signer) public onlyOwner {
        require(_signer != address(0), "can't be zero address");
        signer = _signer;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyOwner {
        _mint(account, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyOwner {
        _mintBatch(to, ids, amounts, data);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        if (paused()) {
            require(from == address(0) || to == address(0), "transfers disallowed");            
        }
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    // To set the Metasaurs Punks address
    function setContract(address _nftContract) external onlyOwner {
        require(_nftContract != address(0), "wrong address");
        nftContract = _nftContract;
    }

    function burn(
        address account,
        uint256 id,
        uint256 value
    ) public override {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()) || msg.sender == nftContract,
            "ERC1155: caller is not owner nor approved"
        );
        
        _burn(account, id, value);
    }

    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory values
    ) public override {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()) || msg.sender == nftContract,
            "ERC1155: caller is not owner nor approved"
        );

        _burnBatch(account, ids, values);
    }

    function claim(
        bytes calldata _signature,
        bytes calldata _UUID,
        uint256 amount,
        address minter,
        uint8 tokenId
    ) public returns (bool) {
        bytes32 msgHash = keccak256(
            abi.encode(msg.sender, _UUID, amount, minter, tokenId)
        );
        require(!executed[msgHash], "Rewarder:: Has been executed!");
        executed[msgHash] = true;
        require(
            msgHash.toEthSignedMessageHash().recover(_signature) == signer,
            "Rewarder:: signer not recovered from signed tx!"
        );

        _mint(minter, tokenId, amount, "");
        emit Claimed(amount, minter, tokenId);

        return true;
    }
}