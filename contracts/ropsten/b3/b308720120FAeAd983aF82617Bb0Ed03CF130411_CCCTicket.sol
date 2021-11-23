// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/*


 ▄▄·  ▄▄▄·  ▐ ▄ ·▄▄▄▄  ▪  ·▄▄▄▄       ▄▄·  ▄▄▄·  ▄▄· ▄▄▄▄▄▪       ▄▄· ▄▄▄  ▄▄▄ .▄▄▌ ▐ ▄▌
▐█ ▌▪▐█ ▀█ •█▌▐███▪ ██ ██ ██▪ ██     ▐█ ▌▪▐█ ▀█ ▐█ ▌▪•██  ██     ▐█ ▌▪▀▄ █·▀▄.▀·██· █▌▐█
██ ▄▄▄█▀▀█ ▐█▐▐▌▐█· ▐█▌▐█·▐█· ▐█▌    ██ ▄▄▄█▀▀█ ██ ▄▄ ▐█.▪▐█·    ██ ▄▄▐▀▀▄ ▐▀▀▪▄██▪▐█▐▐▌
▐███▌▐█ ▪▐▌██▐█▌██. ██ ▐█▌██. ██     ▐███▌▐█ ▪▐▌▐███▌ ▐█▌·▐█▌    ▐███▌▐█•█▌▐█▄▄▌▐█▌██▐█▌
·▀▀▀  ▀  ▀ ▀▀ █▪▀▀▀▀▀• ▀▀▀▀▀▀▀▀•     ·▀▀▀  ▀  ▀ ·▀▀▀  ▀▀▀ ▀▀▀    ·▀▀▀ .▀  ▀ ▀▀▀  ▀▀▀▀ ▀▪

                        Candid Cacti Crew | 2021 | version 2.0 | ERC1155

*/

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract CCCTicket is ERC1155, Ownable, ERC1155Burnable {
    using ECDSA for bytes32;

    uint256 public constant CCC_GIFT = 77;
    uint256 public constant CCC_MAX = 7777;
    uint256 public constant CCC_PRICE = 0.01 ether;
    uint256 public constant CCC_PER_WALLET = 20;
    uint256 private constant _tokenId = 1;

    mapping(address => uint256) public walletClaimed;
    uint256 public giftedTickets;
    uint256 public claimedTickets;

    bool public presaleLive = false;
    bool public publicsaleLive = false;
    address private _signerAddress;

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
     * @dev Pre Sale Minting
     */
    function preSaleMint(bytes32 hash, bytes memory signature, uint256 tokenQuantity) external payable {
        uint256 newMinted = walletClaimed[msg.sender] + tokenQuantity;
        require(presaleLive, "PRESALE_CLOSED");
        require(claimedTickets + tokenQuantity <= CCC_MAX - CCC_GIFT, "OUT_OF_STOCK");
        require(newMinted <= CCC_PER_WALLET, "EXCEED_CCC_PER_WALLET");
        require(CCC_PRICE * tokenQuantity <= msg.value, "INSUFFICIENT_ETH");
        require(matchAddressSigner(hash, signature), "SIGNATURE_ERROR");        

        walletClaimed[msg.sender] = newMinted;
        claimedTickets += tokenQuantity;
        _mint(msg.sender, _tokenId, tokenQuantity, "");
    }

    /**
     * @dev Public Sale Minting
     */
    function publicSaleMint(bytes32 hash, bytes memory signature, uint256 tokenQuantity) external payable {
        uint256 newMinted = walletClaimed[msg.sender] + tokenQuantity;
        require(publicsaleLive, "SALE_CLOSED");
        require(claimedTickets + tokenQuantity <= CCC_MAX - CCC_GIFT, "OUT_OF_STOCK");
        require(newMinted <= CCC_PER_WALLET, "EXCEED_CCC_PER_WALLET");
        require(CCC_PRICE * tokenQuantity <= msg.value, "INSUFFICIENT_ETH");
        require(matchAddressSigner(hash, signature), "SIGNATURE_ERROR");        

        walletClaimed[msg.sender] = newMinted;
        claimedTickets += tokenQuantity;
        _mint(msg.sender, _tokenId, tokenQuantity, "");
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
     * @dev Owner minting function
     */
    function ownerMint(uint256 tokenQuantity) external onlyOwner {
        require(claimedTickets + tokenQuantity <= CCC_MAX - CCC_GIFT,"OUT_OF_STOCK");
        require(tokenQuantity <= 100, "TOO_MANY_REQUESTED"); 

        claimedTickets += tokenQuantity;
        _mint(msg.sender, _tokenId, tokenQuantity, "");
    }

    /**
     * @dev gift function
     */
    
    function gift(address giftreceiver, uint256 tokenQuantity) external onlyOwner {
        require(giftedTickets + tokenQuantity <= CCC_GIFT, "INSUFFICIENT_GIFTS");
        
        giftedTickets += tokenQuantity;
        claimedTickets += tokenQuantity;
        _mint(giftreceiver, _tokenId, tokenQuantity, "");
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
     * @dev Change Signer Address
     */
    function setSignerAddress(address addr) external onlyOwner {
        _signerAddress = addr;
    }

      /**
     * @dev Total claimed tickets
     */
    function totalSupply() public view returns (uint256){
        return claimedTickets;
    }
}