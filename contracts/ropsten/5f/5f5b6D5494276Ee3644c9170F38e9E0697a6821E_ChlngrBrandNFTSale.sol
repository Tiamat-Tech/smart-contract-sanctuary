// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ChlngrBrandNFT.sol";

contract ChlngrBrandNFTSale is Ownable {
  
    uint8 constant GENERATION_COUNT = 3;
    uint8 constant MAX_PER_WALLET = 3;

    address public nftAddress;

    address payable constant public walletMaster = payable(0xFda97A173ae15750bEd99991CCf63c6221390Ca5);
    address payable constant public walletDevTeam = payable(0xFda97A173ae15750bEd99991CCf63c6221390Ca5);

    uint256 public firstSaleFee = 0.3 ether;

    constructor(address _nftAddress) {
        nftAddress = _nftAddress;
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
            require(msg.value >= firstSaleFee, "NFTSale: Not enough ETH sent");
        }

        // perform minting
        ChlngrBrandNFT nft = ChlngrBrandNFT(nftAddress);
        nft.mint(_toAddress, _genIndex, _uri, _data);

        uint256 feeForDev = (uint256)(msg.value / 40);
        walletDevTeam.transfer(feeForDev);
    }
}