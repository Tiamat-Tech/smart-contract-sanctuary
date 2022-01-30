// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ChlngrBrandNFT.sol";

contract ChlngrBrandNFTSale is Ownable {
  
    uint8 constant GENERATION_COUNT = 3;
    uint8 constant MAX_PER_WALLET = 3;

    address public nftAddress;

    address payable constant public walletMaster = payable(0x52BD82C6B851AdAC6A77BC0F9520e5A062CD9a78);
    address payable constant public walletDevTeam = payable(0x52BD82C6B851AdAC6A77BC0F9520e5A062CD9a78);

    uint256 public mintFee = 0.1 ether;

    constructor(address _nftAddress) {
        nftAddress = _nftAddress;
    }

    /**
    * get mint fee
    * @return mint fee
    */
    function getMintFee() public view returns (uint256) {
        return mintFee;
    }

    /**
    * set mint fee
    * @param _fee mint fee
    */
    function setMintFee(uint256 _fee) public {
        mintFee = _fee;
    }

    /**
    * check if mint is possible for generation index
    * @param _genIndex generation index
    */
    function canMintForGeneration(uint8 _genIndex) public returns (bool) {
        return ChlngrBrandNFT(nftAddress).canCreateToken(_genIndex);
    }

    /**
    * check if mint is possible for account
    * @param _account account
    */
    function canMintForAccount(address _account) public returns (bool) {
        if (_account == walletMaster) return true;        
        
        return ChlngrBrandNFT(nftAddress).getTokenCountOfOwner(_account) < MAX_PER_WALLET;
    }

   /**
   * mint a new NFT 
   * @param _toAddress token owner
   * @param _genIndex token generation index
   * @param _uri token uri
   * @param _data token data
   */
    function mint(address _toAddress, uint8 _genIndex, string calldata _uri, bytes calldata _data) public payable {

        require(_genIndex < GENERATION_COUNT , "Invalid Generation Index");

        // wallets not master can own only 3 tokens
        if (_toAddress != walletMaster) {
            require(ChlngrBrandNFT(nftAddress).getTokenCountOfOwner(_toAddress) < MAX_PER_WALLET, "Chlngr Brand NFT Sale: Maximum mint reached for address");
        }

        require(ChlngrBrandNFT(nftAddress).canCreateToken(_genIndex) == true, "Tokens are full in the generation");
        
        // generation 0 must pay minting fee
        if (_genIndex == 0) {
            require(msg.value >= mintFee, "NFTSale: Not enough ETH sent");
        }

        // perform minting
        ChlngrBrandNFT nft = ChlngrBrandNFT(nftAddress);
        nft.mint(_toAddress, _genIndex, _uri, _data);

        uint256 feeForDev = (uint256)(msg.value / 200); // 0.5%
        walletDevTeam.transfer(feeForDev);
    }

    /**
    * withdraw balance to only master wallet
    */
    function withdrawAll() public {
        address payable to = payable(msg.sender);
        require(to == walletMaster, "You can't withdraw the ether");
        to.transfer(address(this).balance);
    }
}