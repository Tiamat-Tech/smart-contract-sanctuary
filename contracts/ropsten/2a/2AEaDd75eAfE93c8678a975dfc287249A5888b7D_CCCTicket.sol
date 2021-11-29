// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/*


 ▄▄·  ▄▄▄·  ▐ ▄ ·▄▄▄▄  ▪  ·▄▄▄▄       ▄▄·  ▄▄▄·  ▄▄· ▄▄▄▄▄▪       ▄▄· ▄▄▄  ▄▄▄ .▄▄▌ ▐ ▄▌
▐█ ▌▪▐█ ▀█ •█▌▐███▪ ██ ██ ██▪ ██     ▐█ ▌▪▐█ ▀█ ▐█ ▌▪•██  ██     ▐█ ▌▪▀▄ █·▀▄.▀·██· █▌▐█
██ ▄▄▄█▀▀█ ▐█▐▐▌▐█· ▐█▌▐█·▐█· ▐█▌    ██ ▄▄▄█▀▀█ ██ ▄▄ ▐█.▪▐█·    ██ ▄▄▐▀▀▄ ▐▀▀▪▄██▪▐█▐▐▌
▐███▌▐█ ▪▐▌██▐█▌██. ██ ▐█▌██. ██     ▐███▌▐█ ▪▐▌▐███▌ ▐█▌·▐█▌    ▐███▌▐█•█▌▐█▄▄▌▐█▌██▐█▌
·▀▀▀  ▀  ▀ ▀▀ █▪▀▀▀▀▀• ▀▀▀▀▀▀▀▀•     ·▀▀▀  ▀  ▀ ·▀▀▀  ▀▀▀ ▀▀▀    ·▀▀▀ .▀  ▀ ▀▀▀  ▀▀▀▀ ▀▪

                        Candid Cacti Crew | 2021 | version 2.0a | ERC1155

*/

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

abstract contract CCCInterface {
    function mintBridge(address to, uint256 tokenQuantity) external virtual;
}

contract CCCTicket is ERC1155, Ownable, ERC1155Burnable {
    using ECDSA for bytes32;

    uint256 public constant CCC_MAX = 7777;
    uint256 public constant CCC_PRICE = 0.001 ether;
    uint256 public constant CCC_PER_WALLET = 20;
    uint256 private constant _tokenId = 1;

    mapping(address => uint256) public walletClaimed;
    uint256 public giftedTickets;
    uint256 public claimedTickets;

    bool public presaleLive = false;
    bool public publicsaleLive = false;
    bool public bridgeLive = false;
    address private _signerAddress;
    address private CCC_Address;

    constructor(address signerAddress)
        ERC1155("https://test.com/unrevealedmetadata")
    {
        _signerAddress = signerAddress;
    }

    //**** Purchase functions ****//

    /**
     * @dev checks hash and signature
     */
    function matchAddressSigner(bytes32 hash, bytes memory signature)
        private
        view
        returns (bool)
    {
        return _signerAddress == hash.recover(signature);
    }

    /**
     * @dev minting function
     */
    function mint(
        bytes32 hash,
        bytes memory signature,
        uint256 tokenQuantity
    ) external payable {
        uint256 newMinted = walletClaimed[msg.sender] + tokenQuantity;
        require(presaleLive || publicsaleLive, "SALES_NOT_STARTED");
        require(claimedTickets + tokenQuantity <= CCC_MAX, "OUT_OF_STOCK");
        require(newMinted <= CCC_PER_WALLET, "EXCEED_CCC_PER_WALLET");
        require(CCC_PRICE * tokenQuantity <= msg.value, "INSUFFICIENT_ETH");
        require(matchAddressSigner(hash, signature), "SIGNATURE_ERROR");

        walletClaimed[msg.sender] = newMinted;
        claimedTickets += tokenQuantity;
        _mint(msg.sender, _tokenId, tokenQuantity, "");
    }

    /**
     * @dev bridge function for ERC1155 -> ERC721
     */

    function bridge(uint256 tokenQuantity) external {
        uint256 userTokens = balanceOf(msg.sender, _tokenId);
        require(presaleLive || publicsaleLive, "SALES_NOT_STARTED");
        require(tokenQuantity <= userTokens, "INSUFFICIENT_TOKENS");
        userTokens -= tokenQuantity;
        burn(msg.sender, _tokenId, tokenQuantity);
        CCCInterface CCC_CONTRACT = CCCInterface(CCC_Address);
        CCC_CONTRACT.mintBridge(msg.sender, tokenQuantity);
    }

    //**** onlyOwner functions ****//

    /**
     * @dev Change the URI
     */
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    /**
     * @dev Withdraw ether to distribute
     */
    function withdrawAll() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    /**
     * @dev gift function
     */

    function gift(
        address[] calldata giftreceiver,
        uint256[] calldata tokenQuantity
    ) external onlyOwner {
        for (uint256 i = 0; i < giftreceiver.length; i++) {
            uint256 tokenqty = tokenQuantity[i];
            require(claimedTickets + tokenqty <= CCC_MAX, "OUT_OF_STOCK");

            claimedTickets += tokenqty;
            _mint(giftreceiver[i], _tokenId, tokenqty, "");
        }
    }

    /**
     * @dev toggle PreSale status
     */
    function togglePreSale() external onlyOwner {
        presaleLive = !presaleLive;
    }

    /**
     * @dev toggle Public Sale status
     */
    function togglePublicSale() external onlyOwner {
        publicsaleLive = !publicsaleLive;
    }

    /**
     * @dev toggle ERC721 Bridge Live status
     */
    function toggleBridge() external onlyOwner {
        bridgeLive = !bridgeLive;
    }

    /**
     * @dev Change Signer Address
     */
    function setSignerAddress(address addr) external onlyOwner {
        _signerAddress = addr;
    }

    /**
     * @dev Change CCC Contract Address
     */
    function setCCCAddress(address addr) external onlyOwner {
        CCC_Address = addr;
    }

    /**
     * @dev Total claimed tickets
     */
    function totalSupply() public view returns (uint256) {
        return claimedTickets;
    }
}