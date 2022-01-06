// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0 <0.8.12;

import "./iBadBeatContract.sol";
import "./utils/Minting.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/SignatureCheckerUpgradeable.sol";
/**
 * @dev Implementation of the {IMonsterBuds} interface.
 * This Contract states the 
 *  
 */

contract BadBeatContract is  ERC721URIStorage, Ownable, IBadbeatContract {
    using Strings for uint256;
    
    // token counter
    uint256 public tokenCounter;

    // token URI
    string private beforeUri;

    string private afterUri;

    // token value
    // uint256 private tokenValue;

    // 
    address payoutAddress1;


    //
    address payoutAddress2;

 
    // address of IMX contract
    address public imx;

    // sets the flag for BuyNFT
    bool public buyOnOff;

    // stores the blueprint for token Id
    mapping(uint256 => bytes) public blueprints;

    // structure's

    struct tokenDetails{
        uint256 noOfTokens;
        bytes32 signKey;
        uint256 catId;
    }


    /**
     * @dev Sets the initialization
    
     */

    // constructor initialisation section

    constructor(address _imx)  ERC721("BadBeat-NFT", "BB") {
        tokenCounter = 1;
        beforeUri = "https://s3.amazonaws.com/assets.metaparadiseisland.com/token-uri/token-uri-";
        afterUri = "-token-uri.json";
        // tokenValue = 99000000000000000;
        payoutAddress1 = payable(0x01A291afF729Ee1Ab5b57c9faD0c722438fEc47c);
        payoutAddress2 = payable(0x0fA2e7b49eD6BE0A5c460f28aeC537a520C3e525);
        imx = _imx;
    }

    // Modifiers
    
    /**
     * @dev only IMX address can call modifier.
    */

    modifier onlyIMX() {
        require(msg.sender == imx, "Function can only be called by IMX");
        _;
    }

    // functions Sections

    /**
     * @dev concates the two string and token id to create new URI. 
          *
     * @param _before token uri before part.
     * @param _after token uri after part.
     * @param _token_id token Id.
     *
     * Returns
     * - token uri
    */

    function uriConcate(string memory _before, uint256 _token_id, string memory _after) private pure returns (string memory){
        string memory token_uri = string( abi.encodePacked(_before, _token_id.toString(), _after));
        return token_uri;
    }

    /**
     * @dev update the default token Uri. 
          *
     * @param _before token uri before part.
     * @param _after token uri after part.
     *
     * Returns
     * - bool
    */

    function updateDefaultUri(string memory _before, string memory _after) external onlyOwner returns (bool){
        beforeUri = _before; // update the before uri for MPI
        afterUri = _after; // update the after uri for MPI
        return true;
    }

    /**
     * @dev updates the mint value for each token. 
          *
     * @param _tokenValue  price in wei.
     *
     * Returns
     * - bool
    */

    // function updateTokenValue(uint256 _tokenValue) external onlyOwner returns(bool){
    //     tokenValue = _tokenValue;
    //     return true;
    // }

    /**
     * @dev updates the Flag of Buy NFT. 
          *
     * @param status flag of buy nft.
     *
     * Returns
     * - bool
    */

    function updateBuyOnOff(bool status) external onlyOwner returns(bool){
        buyOnOff = status;
        return true;
    }

    /**
     * @dev updates the token Uri of Token Id. 
          *
     * @param id  token Id.
     *
     * Returns
     * - bool
    */

    function updateTokenURI(uint256 id) external onlyOwner returns(bool){
        string memory _uri = uriConcate(beforeUri, id, afterUri);
        _setTokenURI(id, _uri);
        return true;
    }

    /**
     * @dev creating new NFT on immutable x. 
     *
     * @param tokens  token details.
     * @param signature signature to verify.
     *
     * Returns
     * - bool
     *
     * Emits a {TransferEth} event.
    */

    function buyNFT(tokenDetails calldata tokens, bytes calldata signature) payable external returns(bool){
        // uint256 value = tokenValue * tokens.noOfTokens; 
        require(buyOnOff == true, "NFT minting is stopped");
        
        bool status = SignatureCheckerUpgradeable.isValidSignatureNow(owner(), tokens.signKey, signature);
        require(status == true, "You cannot mint NFT or a not whitelisted address");
        require(msg.value == 0, "No price is set");

        uint256 payableValue1 = uint256(30) * (msg.value)/ 100;
        payable(payoutAddress1).transfer(payableValue1);


        uint256 payableValue2 = msg.value - payableValue1;
        payable(payoutAddress2).transfer(payableValue2);
        emit TransferEth(msg.sender,payoutAddress1, payableValue1,
         payoutAddress2, payableValue2, tokens.noOfTokens,tokens.catId, msg.value);


        return true;
    }

    /**
     * @dev mintinf function by only IMX. 
     *
     * @param user  msg.sender.
     * @param quantity number of token amount.
     * @param mintingBlob bytes32
     *
     * Returns
     * - bool
     *
     * Emits a {AssetMinted} event.
    */    

    function mintFor(
        address user,
        uint256 quantity,
        bytes calldata mintingBlob
    ) external onlyIMX {
        require(quantity == 1, "Mintable: invalid quantity");
        (uint256 id, bytes memory blueprint) = Minting.split(mintingBlob);
        _mintFor(user, id, blueprint);
        blueprints[id] = blueprint;
        emit AssetMinted(user, id, blueprint);
    }

    /**
     * @dev mint NFT and set URI. 
          *
     * @param user  msg.sender.
     * @param id token id.
     *
     * Returns
     * - bool
     *
    */  

    function _mintFor(
        address user,
        uint256 id,
        bytes memory 
    ) internal {
        _safeMint(user, id, "");
        string memory _uri = uriConcate(beforeUri, id, afterUri);
       _setTokenURI(id, _uri);
    }

}