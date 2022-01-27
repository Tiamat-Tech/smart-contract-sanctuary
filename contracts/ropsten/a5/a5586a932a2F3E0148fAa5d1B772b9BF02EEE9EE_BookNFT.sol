// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
pragma abicoder v2; // required to accept structs as function parameters

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/draft-EIP712.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./Voucher.sol";
import "./VoucherStruct.sol";

import './ERC2981/ERC2981PerTokenRoyalties.sol';


contract BookNFT is ERC721URIStorage, EIP712, Ownable, AccessControl, Voucher, ERC2981PerTokenRoyalties {
    address private signerAddress;
    address payable public feeRecipient;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    uint16 public immutable platformFeeBasisPoints;

    event TokenMintedAndSold(uint256 indexed tokenId, address indexed creator, address indexed buyer, uint256 sellingPrice);

    constructor(string memory name, string memory symbol, address payable _feeRecipient, uint16 _platformFeeBasisPoints) ERC721(name, symbol) {
        //_setupRole(MINTER_ROLE, minter);
        feeRecipient = _feeRecipient;
        platformFeeBasisPoints = _platformFeeBasisPoints;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override (AccessControl, ERC721, ERC2981Base) returns (bool) {
        return AccessControl.supportsInterface(interfaceId) || ERC721.supportsInterface(interfaceId)
        || interfaceId == _INTERFACE_ID_ERC2981;
    }

    function setSignerAddress(address _address) external onlyOwner {
        signerAddress = _address;
    }

    // function setPlatformFeeBasisPoints(uint16 _platformFeeBasisPoints) public {
    //     platformFeeBasisPoints = _platformFeeBasisPoints;
    // }

    function redeemToken(address redeemer, NFTVoucher calldata voucher) public payable returns (uint256) {
        // make sure signature is valid and get the address of the signer
        address signer = _verify(voucher);
        // console.log("-------------------- signature address ----------------");
        // console.log(signer);

        // make sure that the signer is authorized to mint NFTs
        //require(hasRole(MINTER_ROLE, signer), "Signature invalid or unauthorized");
    
        require(signer == signerAddress, "Signature invalid or unauthorized");
        // make sure that the redeemer is paying enough to cover the buyer's cost
        require(voucher.sellingPrice > 0, "Token is not listed for sale");
        require(msg.value >= voucher.sellingPrice, "Insufficient funds to redeem");
        // first assign the token to the signer, to establish provenance on-chain
        _mint(signer, voucher.tokenId);
        
        _setTokenURI(voucher.tokenId, voucher.tokenUri);
    
        // transfer the token to the redeemer
        _transfer(signer, redeemer, voucher.tokenId);

        // send funds to the platform owner and seller
        _sendFunds(signer, msg.value);

        // uint256 feeAmount = (msg.value * platformFeeBasisPoints) / 1000;
        // uint256 amount = msg.value - feeAmount;
        // Address.sendValue(payable(feeRecipient), feeAmount);
        // Address.sendValue(payable(signer), msg.value - feeAmount);

        // saveRoyalties
        address payable royaltyRecipient = payable(signer);
        uint16 royaltyValue = voucher.royaltyBasisPoints;
        if (voucher.royaltyBasisPoints > 0) {
            _setTokenRoyalty(voucher.tokenId, royaltyRecipient, royaltyValue);
        }

        emit TokenMintedAndSold(voucher.tokenId, signer, redeemer, msg.value);

        return voucher.tokenId;
    }

    function _sendFunds(address beneficiary, uint256 value) internal returns (bool) {
        // address payable beneficiary  = payable(beneficiary);
        uint256 feeAmount = (value * platformFeeBasisPoints) / 1000;
        // console.log("feeAmount ", feeAmount);
        // uint256 amount = value - feeAmount;
        // console.log("amount ", amount);
        // console.log("amount + feeAmount", amount + feeAmount);

        Address.sendValue(payable(feeRecipient), feeAmount);
        Address.sendValue(payable(beneficiary), value - feeAmount);

        return true;
    }

}