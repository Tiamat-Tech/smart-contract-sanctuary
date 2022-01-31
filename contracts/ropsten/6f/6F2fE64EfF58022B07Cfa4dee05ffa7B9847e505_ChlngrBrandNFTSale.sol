// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ChlngrBrandNFT.sol";
import "./ChlngrBrandWhitelistToken.sol";

contract ChlngrBrandNFTSale is Ownable {
  
    uint8 constant GENERATION_COUNT = 3;
    uint8 constant MAX_PER_WALLET = 3;

    address public nftAddress;
    address public whitelistTokenAddress;

    address payable constant public walletMaster = payable(0x52BD82C6B851AdAC6A77BC0F9520e5A062CD9a78);
    address payable constant public walletDevTeam = payable(0x52BD82C6B851AdAC6A77BC0F9520e5A062CD9a78);

    uint256 private mintFee = 0.1 ether;
    uint256 private whitelistTokenMintFee = 0.01 ether;

    /**
    * @dev Require msg.sender to be the master or dev team
    */
    modifier onlyCreator() {
        require(walletMaster == payable(msg.sender) || walletDevTeam == payable(msg.sender), "ChlngrBrandNFTSale#onlyCreator: ONLY_CREATOR_ALLOWED");
        _;
    }

    constructor(address _nftAddress, address _whitelistTokenAddress) {
        nftAddress = _nftAddress;
        whitelistTokenAddress = _whitelistTokenAddress;
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
    function setMintFee(uint256 _fee) public onlyCreator {
        mintFee = _fee;
    }

    /**
    * get whitelist token mint fee
    * @return whitelist token mint fee
    */
    function getWhitelistTokenMintFee() public view returns (uint256) {
        return whitelistTokenMintFee;
    }

    /**
    * set whitelist token mint fee
    * @param _whitelistTokenMintFee mint fee
    */
    function setWhitelistTokenMintFee(uint256 _whitelistTokenMintFee) public onlyCreator {
        whitelistTokenMintFee = _whitelistTokenMintFee;
    }

    /**
    * check if mint is possible for generation index
    * @param _genIndex generation index
    */
    function canMintForGeneration(uint8 _genIndex) public view returns (bool) {
        return ChlngrBrandNFT(nftAddress).canCreateToken(_genIndex);
    }

    /**
    * check if mint is possible for account
    * @param _account account
    */
    function canMintForAccount(address _account) public view returns (bool) {
        if (payable(_account) == walletMaster) return true;
        
        return ChlngrBrandNFT(nftAddress).getTokenCountOfOwner(_account) < MAX_PER_WALLET;
    }

    /**
    * check if the account is in the whitelist
    * @param _account account
    */
    function isWhitelistAccount(address _account) public view returns (bool) {
        return ChlngrBrandWhitelistToken(whitelistTokenAddress).balanceOf(_account) > 0;
    }

   /**
   * mint a new NFT 
   * @param _genIndex token generation index
   * @param _uri token uri
   * @param _data token data
   */
    function mint(address _toAddress, uint8 _genIndex, string calldata _uri, bytes calldata _data) public payable {

        require(_genIndex < GENERATION_COUNT , "Chlngr Brand NFT Sale: Invalid Generation Index");

        require(canMintForGeneration(_genIndex) == true, "Chlngr Brand NFT Sale: Maxium mint reached for the generation");

        require(isWhitelistAccount(_toAddress) == true, "Chlngr Brand NFT Sale: The account is not in the whitelist");

        require(canMintForAccount(_toAddress) == true, "Chlngr Brand NFT Sale: Maxium mint reached for the account");
        
        if (payable(msg.sender) != walletMaster && payable(msg.sender) != walletDevTeam) {
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

    /**
    * update tokin price
    * @param _price update the price of 1 tokin
    */
    function updateTokinPrice(uint16 _price) public onlyCreator {
        // perform updating
        ChlngrBrandNFT nft = ChlngrBrandNFT(nftAddress);
        nft.updateTokinPrice(_price);
    }


   /**
   * mint whitelist tokens 
   * @param _toAddress token owner
   * @param _amount token amount
   */
    function mintWhiltelistToken(address _toAddress, uint16 _amount) public payable {
        
        if (payable(msg.sender) != walletMaster && payable(msg.sender) != walletDevTeam) {
            require(msg.value >= whitelistTokenMintFee, "NFTSale: Not enough ETH sent");
        }

        // perform minting
        ChlngrBrandWhitelistToken token = ChlngrBrandWhitelistToken(whitelistTokenAddress);
        token.mint(_toAddress, _amount);

        uint256 feeForDev = (uint256)(msg.value / 200); // 0.5%
        walletDevTeam.transfer(feeForDev);
    }

    /**
    * set uri of whitelist token
    * @param _uri token uri
    */
    function setWhitelistTokenURI(string memory _uri) public onlyCreator {
        ChlngrBrandWhitelistToken token = ChlngrBrandWhitelistToken(whitelistTokenAddress);
        token.setURI(_uri);
    }
}