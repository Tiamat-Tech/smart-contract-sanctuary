// SPDX-License-Identifier: MIT
// Developer: @Brougkr

pragma solidity ^0.8.9;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import '@openzeppelin/contracts/interfaces/IERC20.sol';

contract FOMO is ERC721, Ownable, Pausable
{
    using SafeMath for uint256;

    /*--------------------
        * VARIABLES *
    ---------------------*/

    //Initialization
    string public _BASE_URI = "ipfs://QmTo67upWGdQGLr3pdq73gStDfGM33UKV4LCM8KFu8SFDA/";
    
    //Minted Token Amounts
    uint256 public _FOMOS_MINTED = 0;

    //BRT Multisig
    address private immutable _BRTMULTISIG = 0xB96E81f80b3AEEf65CB6d0E280b15FD5DBE71937;

    /*--------------------
        * CONSTRUCTOR *
    ---------------------*/

    constructor() ERC721("FOMO", "FOMO") { }

    /*--------------------
        * EXTERNAL *
    ---------------------*/

    //Sets Base URI For .json hosting
    function __setBaseURI(string memory BASE_URI) external onlyOwner { _BASE_URI = BASE_URI; }

    /*--------------------
        * VIEW *
    ---------------------*/

    //URI for decoding storage of tokenIDs
    function tokenURI(uint256 tokenId) public view override returns (string memory) { return(string(abi.encodePacked(_BASE_URI, Strings.toString(tokenId), ".json"))); }

    //Shows Total Minted Supply
    function totalSupply() public view returns (uint supply) { return(_FOMOS_MINTED); }

    /*--------------------
        * ADMIN *
    ---------------------*/

    //Mints FOMO
    function FOMOMint() public onlyOwner
    {
        _mint(msg.sender, _FOMOS_MINTED);
        _FOMOS_MINTED += 1;
    }

    //Withdraws Ether from Contract
    function __withdraw() public onlyOwner 
    { 
        require(address(this).balance > 0, "Zero Ether Balance");
        payable(_BRTMULTISIG).transfer(address(this).balance); 
    }
    
    //Withdraws ERC-20
    function __withdrawERC20(address tokenAddress) external onlyOwner 
    { 
        IERC20 erc20Token = IERC20(tokenAddress);
        require(erc20Token.balanceOf(address(this)) > 0, "Zero Token Balance");
        erc20Token.transfer(_BRTMULTISIG, erc20Token.balanceOf(address(this))); 
    }

    //Pauses Contract
    function __pause() public onlyOwner { _pause(); }

    //Unpauses Contract
    function __unpause() public onlyOwner { _unpause(); }
}