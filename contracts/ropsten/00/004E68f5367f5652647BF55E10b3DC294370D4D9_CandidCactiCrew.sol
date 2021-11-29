// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/*


 ▄▄·  ▄▄▄·  ▐ ▄ ·▄▄▄▄  ▪  ·▄▄▄▄       ▄▄·  ▄▄▄·  ▄▄· ▄▄▄▄▄▪       ▄▄· ▄▄▄  ▄▄▄ .▄▄▌ ▐ ▄▌
▐█ ▌▪▐█ ▀█ •█▌▐███▪ ██ ██ ██▪ ██     ▐█ ▌▪▐█ ▀█ ▐█ ▌▪•██  ██     ▐█ ▌▪▀▄ █·▀▄.▀·██· █▌▐█
██ ▄▄▄█▀▀█ ▐█▐▐▌▐█· ▐█▌▐█·▐█· ▐█▌    ██ ▄▄▄█▀▀█ ██ ▄▄ ▐█.▪▐█·    ██ ▄▄▐▀▀▄ ▐▀▀▪▄██▪▐█▐▐▌
▐███▌▐█ ▪▐▌██▐█▌██. ██ ▐█▌██. ██     ▐███▌▐█ ▪▐▌▐███▌ ▐█▌·▐█▌    ▐███▌▐█•█▌▐█▄▄▌▐█▌██▐█▌
·▀▀▀  ▀  ▀ ▀▀ █▪▀▀▀▀▀• ▀▀▀▀▀▀▀▀•     ·▀▀▀  ▀  ▀ ·▀▀▀  ▀▀▀ ▀▀▀    ·▀▀▀ .▀  ▀ ▀▀▀  ▀▀▀▀ ▀▪

                        Candid Cacti Crew | 2021 | version 2.0a | ERC721

*/

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

//import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract CandidCactiCrew is ERC721Enumerable, Ownable {
    using Strings for uint256;
    // using ECDSA for bytes32;

    uint256 public constant CCC_TOTAL = 7777;

    string private _contractURI;
    string private _tokenBaseURI;
    string public proof;

    address private _CCCTICKET;

    constructor(address cccticket) ERC721("Candid Cacti Crew", "CCC") {
        _CCCTICKET = cccticket;
    }

    //**** Purchase functions ****//

    /**
     * @dev minting 721 to 1155 holders
     */

    function mintBridge(address to, uint256 tokenQuantity) external {
        uint256 totalMinted = totalSupply();
        require(msg.sender == _CCCTICKET, "INVALID_ACCESS");
        require(
            totalMinted + tokenQuantity <= CCC_TOTAL,
            "EXCEED_TOTAL_SUPPLY"
        );

        for (uint256 i = 0; i < tokenQuantity; i++) {
            totalMinted++;
            _mint(to, totalMinted);
        }
    }

    //**** onlyOwner functions ****//

    /**
     * @dev withdraw any funds in contract
     */
    function withdrawAll() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    /**
     * @dev CCCTicket Contract Address
     */
    function updateTicketAddress(address ticketAddress) external onlyOwner {
        _CCCTICKET = ticketAddress;
    }

    /**
     * @dev set Provenance Hash
     */
    function setProvenanceHash(string calldata hash) external onlyOwner {
        proof = hash;
    }

    /**
     * @dev set Contract URI
     */
    function setContractURI(string calldata URI) external onlyOwner {
        _contractURI = URI;
    }

    /**
     * @dev set BASE URI
     */
    function setBaseURI(string calldata URI) external onlyOwner {
        _tokenBaseURI = URI;
    }

    //**** View functions ****//

    /**
     * @dev view ContractURI
     */
    function contractURI() public view returns (string memory) {
        return _contractURI;
    }

    /**
     * @dev view tokenURI (note: no extension)
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721)
        returns (string memory)
    {
        require(_exists(tokenId), "Cannot query non-existent token");

        return string(abi.encodePacked(_tokenBaseURI, tokenId.toString()));
    }

    /**
     * @dev view BaseURI
     */
    function baseURI() public view returns (string memory) {
        return _tokenBaseURI;
    }
}