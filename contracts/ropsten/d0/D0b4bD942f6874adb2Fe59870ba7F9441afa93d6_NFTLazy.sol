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
import "./Voucher.sol";
import "./VoucherStruct.sol";

contract NFTLazy is ERC721URIStorage, EIP712, Ownable, AccessControl, Voucher {
    address private signerAddress;

    mapping(address => uint256) pendingWithdrawals;

    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        //_setupRole(MINTER_ROLE, minter);
    }

    function setSignerAddress(address _address) external onlyOwner {
        signerAddress = _address;
    }

    function redeem(address redeemer, NFTVoucher calldata voucher) public payable returns (uint256) {
        // make sure signature is valid and get the address of the signer
        address signer = _verify(voucher);
        // console.log("-------------------- signature address ----------------");
        // console.log(signer);

        // make sure that the signer is authorized to mint NFTs
        //require(hasRole(MINTER_ROLE, signer), "Signature invalid or unauthorized");
    
        require(signer == signerAddress, "Signature invalid or unauthorized");
        // make sure that the redeemer is paying enough to cover the buyer's cost
        require(msg.value >= voucher.sellingPrice, "Insufficient funds to redeem");
        // first assign the token to the signer, to establish provenance on-chain
        _mint(signer, voucher.tokenId);
        // emit TokenMinted
        _setTokenURI(voucher.tokenId, voucher.tokenUri);
    
        // transfer the token to the redeemer
        _transfer(signer, redeemer, voucher.tokenId);
        // emit TokenTransfered

        // record payment to signer's withdrawal balance
        pendingWithdrawals[signer] += msg.value;
        
        // _splitPayment(signer, voucher, owner());
        return voucher.tokenId;
    }

    // @notice Transfers all pending withdrawal balance to the caller. Reverts if the caller is not an authorized minter.
    function withdraw() public {
        //require(hasRole(MINTER_ROLE, msg.sender), "Only authorized minters can withdraw");
        //todo: withdraw can do just the owner of the balance msg.sender==availableTowithdraw[msg.sender]
        address payable receiver = payable(msg.sender);
        uint amount = pendingWithdrawals[receiver];
        // zero account before transfer to prevent re-entrancy attack
        pendingWithdrawals[receiver] = 0;
        receiver.transfer(amount);
    }

    function availableToWithdraw() public view returns (uint256) {
        return pendingWithdrawals[msg.sender];
    }

    function availableToWithdrawByAddress(address wallet) external view returns (uint256) {
        return pendingWithdrawals[wallet];
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override (AccessControl, ERC721) returns (bool) {
        return ERC721.supportsInterface(interfaceId) || AccessControl.supportsInterface(interfaceId);
    }
}