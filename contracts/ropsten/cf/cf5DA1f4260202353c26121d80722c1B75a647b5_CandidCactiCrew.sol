// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/*


 ▄▄·  ▄▄▄·  ▐ ▄ ·▄▄▄▄  ▪  ·▄▄▄▄       ▄▄·  ▄▄▄·  ▄▄· ▄▄▄▄▄▪       ▄▄· ▄▄▄  ▄▄▄ .▄▄▌ ▐ ▄▌
▐█ ▌▪▐█ ▀█ •█▌▐███▪ ██ ██ ██▪ ██     ▐█ ▌▪▐█ ▀█ ▐█ ▌▪•██  ██     ▐█ ▌▪▀▄ █·▀▄.▀·██· █▌▐█
██ ▄▄▄█▀▀█ ▐█▐▐▌▐█· ▐█▌▐█·▐█· ▐█▌    ██ ▄▄▄█▀▀█ ██ ▄▄ ▐█.▪▐█·    ██ ▄▄▐▀▀▄ ▐▀▀▪▄██▪▐█▐▐▌
▐███▌▐█ ▪▐▌██▐█▌██. ██ ▐█▌██. ██     ▐███▌▐█ ▪▐▌▐███▌ ▐█▌·▐█▌    ▐███▌▐█•█▌▐█▄▄▌▐█▌██▐█▌
·▀▀▀  ▀  ▀ ▀▀ █▪▀▀▀▀▀• ▀▀▀▀▀▀▀▀•     ·▀▀▀  ▀  ▀ ·▀▀▀  ▀▀▀ ▀▀▀    ·▀▀▀ .▀  ▀ ▀▀▀  ▀▀▀▀ ▀▪

                        Candid Cacti Crew | 2021 | version 2.0 | ERC721

*/

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

contract CandidCactiCrew is ERC721Enumerable, Ownable {
    using Strings for uint256;

    uint256 public constant CCC_TOTAL = 7777;

    string private _contractURI;
    string private _tokenBaseURI;
    string public proof;

    address private _ERC1155BURNADDRESS;

    bool public mintLive = false;

    constructor(address cccticket) ERC721("Candid Cacti Crew", "CCC") {
        _ERC1155BURNADDRESS = cccticket;
    }

    //Mint functions
    function onERC1155Received(
        address,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4) {
        _onERC1155Received(from, id, value, data);
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4) {
        require(ids.length == values.length, "Invalid input");
        for (uint256 i = 0; i < ids.length; i++) {
            _onERC1155Received(from, ids[i], values[i], data);
        }
        return this.onERC1155BatchReceived.selector;
    }

    event ErrorHandled(string reason);
    event ErrorNotHandled(bytes reason);

    function _onERC1155Received(
        address from,
        uint256 id,
        uint256 value,
        bytes calldata
    ) private {
        uint256 totalMinted = totalSupply();
        require(msg.sender == _ERC1155BURNADDRESS && id == 1, "Invalid_NFT");
        require(mintLive, "Minting is not active yet.");
        require(totalMinted + value <= CCC_TOTAL, "EXCEED_TOTAL_SUPPLY");

        // Burn it
        try
            ERC1155Burnable(msg.sender).burn(address(this), id, value)
        {} catch Error(string memory reason) {
            emit ErrorHandled(reason);
            revert("Burn failure");
        } catch (bytes memory lowLevelData) {
            emit ErrorNotHandled(lowLevelData);
            revert("Burn failure");
        }

        for (uint256 i = 0; i < value; i++) {
            totalMinted++;
            _mint(from, totalMinted);
        }
    }

    //onlyOwner functions
    function withdraw() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function toggleMint() external onlyOwner {
        mintLive = !mintLive;
    }

    function updateERC1155BurnAddress(address erc1155BurnAddress)
        external
        onlyOwner
    {
        _ERC1155BURNADDRESS = erc1155BurnAddress;
    }

    function setProvenanceHash(string calldata hash) external onlyOwner {
        proof = hash;
    }

    function setContractURI(string calldata URI) external onlyOwner {
        _contractURI = URI;
    }

    function setBaseURI(string calldata URI) external onlyOwner {
        _tokenBaseURI = URI;
    }

    //view functions
    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        require(_exists(tokenId), "Cannot query non-existent token");

        return string(abi.encodePacked(_tokenBaseURI, tokenId.toString()));
    }

    function baseURI() public view returns (string memory) {
        return _tokenBaseURI;
    }
}