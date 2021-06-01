// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LandOrc is ERC20, Ownable {
    address landNFTAddress;

    /**
     * @dev mint with initial token supply (21 Million LORC)
     */
    constructor() ERC20("LandOrc", "LORC") {
        _mint(msg.sender, 21000000 * 10 ** uint(decimals()));
    }

    /**
     * @dev Set LandNFT contract address
     */
    function setLandNFTAddress(address _landNFTAddress) external onlyOwner {
         landNFTAddress = _landNFTAddress;
    }

    /**
     * @dev Throws if called by any account other than the LORC NFT Contract.
     */
    modifier isNFTContract() {
        require(landNFTAddress == _msgSender(), "Caller is not the LORC NFT Contract");
        _;
    }
    
    /**
     * @dev Throws if called by any account other than the LORC NFT Contract.
     */
    modifier onlyMinter() {
        require(landNFTAddress == _msgSender() || owner() == _msgSender(), "Caller is not permited to mint");
        _;
    }

    /**
     * @dev Increase token supply by minting new LORC to the LandNFT Owner.
     */
    function mint(address _account, uint256 _amount) public onlyMinter {
        _mint(_account, _amount);
    }

    /**
     * @notice This function is only for the Contract Owner
     * @dev Burn token 
     * @param _account address of the account 
     * @param _amount amont to be burned
     */
    function burn(address _account, uint256 _amount) public onlyOwner {
        _burn(_account, _amount);
    }
}