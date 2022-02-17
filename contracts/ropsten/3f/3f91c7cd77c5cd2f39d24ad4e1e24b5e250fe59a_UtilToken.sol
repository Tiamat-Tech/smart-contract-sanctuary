// SPDX-License-Identifier: MIT
// Creator: Chiru Labs

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import './ERC721AUpgradeable.sol';
import './IUtilToken.sol';

contract UtilToken is ERC721AUpgradeable, PausableUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, IUtilToken{

    using SafeMathUpgradeable for uint256;

    // Zero Address
    address constant ZERO_ADDRESS = address(0);

    // Sale active status variable
    bool public isSaleActive;

    // Minting price for NFT
    uint256 private mintPrice;

    // Base URI string
    string private _baseURIPrefix;

    mapping(uint256 => bool) public airDropTokens;

    function initialize(
        string memory _tokenName, 
        string memory _tokenSymbol, 
        string memory _uri
    ) initializer public {
        __ERC721A_init(_tokenName, _tokenSymbol);
        __Pausable_init();
        __Ownable_init();

        isSaleActive = true;
        _baseURIPrefix = _uri;
        mintPrice = 0.1 ether;
    }

    /// @dev This is the token mint function. This would mint a random token NFT and distribute the share price. This would except coins to buy the NFT

    function mint() external payable override whenNotPaused {
        address callerAddress = _msgSender();
        require(isSaleActive, "Sale must be active to mint NFT");
        require(getMintPrice() <= msg.value, "Insufficient balance");
        uint256 initialTotalSupply = totalSupply();
        _safeMint(callerAddress, 1);

        emit NewNFT(initialTotalSupply);
    }

    /// @dev This is the airDrop function. It is used by the owner to airdrop `quantity` number of random tokens to the `assigned` address.
    /// @dev Only the owner can call this function
    /// @param assigned The address to be air dropped
    /// @param quantity The amount of random tokens to be air dropped

    function airDrop(address assigned, uint256 quantity) public override onlyOwner whenNotPaused {
        require(isSaleActive, "Sale must be active to mint NFT");
        uint256 initialTotalSupply = totalSupply();
        _safeMint(assigned, quantity);
        for (uint256 i = 0; i < quantity; i++){
            airDropTokens[initialTotalSupply.add(i)] = true;
            emit NewNFT(initialTotalSupply.add(i));
        }
    }

    /// @dev This is the function to withdraw the amount saved from the contract
    /// @dev Only the owner can call this function

    function withdraw() external override onlyOwner nonReentrant whenNotPaused{
        uint256 contractBalance = address(this).balance;
        payable(owner()).transfer(contractBalance);
    }

    /// @dev This is the function to alter the sale active status
    /// @dev Only the owner can call this function
    /// @param isActive The sale status to be set

    function alterSaleActiveStatus(bool isActive) external override onlyOwner whenNotPaused{
        require(isSaleActive != isActive, "Sale status is already equal to supplied value");
        isSaleActive = isActive;
    }

    /// @dev This is the function to set the mint amount to new mint amount
    /// @dev Only the owner can call this function
    /// @param newAmount The new liquidity pool address

    function setMintPrice (uint256 newAmount) external override onlyOwner whenNotPaused{
        mintPrice = newAmount;
    }

    /// @dev This is the function to get the mint amount
    /// @dev Only the owner can call this function

    function getMintPrice() public view override onlyOwner returns (uint256) {
        return mintPrice;
    }

    /// @dev The internal function for getting the Base URI string

    function _baseURI() internal view override returns (string memory) {
        return _baseURIPrefix;
    }

    /// @dev The external function for getting the Base URI string

    function baseURI() external view override returns (string memory) {
        return _baseURI();
    }

    /// @dev This is the function to set the Base URI to new Base URI
    /// @dev Only the owner can call this function
    /// @param newUri The new Base URI

    function setBaseURI(string memory newUri) external override onlyOwner whenNotPaused {
        require(
            keccak256(bytes(newUri)) != keccak256(bytes(_baseURIPrefix)),
            "New URI cannot be same as old URI"
        );
        _baseURIPrefix = newUri;
        emit SetBaseURI(newUri);
    }

    /// @dev This function would pause the Atrollcity contract
    /// @dev Only the owner can call this function

    function pause() external override onlyOwner {
        _pause();
    }

    /// @dev This function would unpause the Atrollcity contract
    /// @dev Only the owner can call this function

    function unpause() external override onlyOwner {
        _unpause();
    }

    /// @dev Overridden function called before every token transfer

    function _beforeTokenTransfers(
        address from,
        address to,
        uint256 startTokenId,
        uint256 quantity

    ) internal virtual whenNotPaused airDropCheck(startTokenId, quantity) override (ERC721AUpgradeable) {
        super._beforeTokenTransfers(from, to, startTokenId, quantity);
    }

    modifier airDropCheck(uint256 startTokenId, uint256 quantity) {
        for (uint256 i = 0; i < quantity; i++) {
            require(
                !airDropTokens[startTokenId.add(i)],
                "The token is airdropped and cannot be transferred"
            );
        }
        _;
    }

}