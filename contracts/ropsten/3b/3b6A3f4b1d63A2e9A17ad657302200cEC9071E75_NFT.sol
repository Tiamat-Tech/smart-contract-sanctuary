// contracts/NFT.sol
// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.2;

import "hardhat/console.sol";
import "./NFTStorage.sol";

contract NFT is NFTStorage {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    function initialize(address marketplaceAddress, address _acceptedToken, uint256 _mintPrice) initializer public {
        __ERC721_init("BVO - 1.0", "BVO");
        contractAddress = marketplaceAddress;
        acceptedToken = _acceptedToken;
        mintPrice = _mintPrice * 1e18;
        owner = msg.sender;
     }

     function getMintPrice() public view returns (uint256) {
        return mintPrice;
     }

     function getAcceptedToken() public view returns (address) {
        return acceptedToken;
     }

     function getMKPContractAddress() public view returns (address) {
        return contractAddress;
     }

     function setAcceptedToken(address _acceptedToken) public {
        require(msg.sender == owner, "Only owner can set accepted token");
        acceptedToken = _acceptedToken;
     }

     function setMKPContractAddress(address _contractAddress) public {
         require(msg.sender == owner, "Only owner can set marketplace contract address");
        contractAddress = _contractAddress;
     }

     function setMintPrice(uint _mintPrice) public {
        require(msg.sender == owner, "Only owner can set mint price");
        mintPrice = _mintPrice;
     }

    function createToken(string memory tokenURI) public returns (uint) {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();

        require(IERC20Upgradeable(acceptedToken).balanceOf(msg.sender) >= mintPrice, "Not enough token");
        require(IERC20Upgradeable(acceptedToken).allowance(msg.sender, contractAddress) >= mintPrice, "Not enough allowence");
        require(IERC20Upgradeable(acceptedToken).transferFrom(msg.sender, owner, mintPrice), "Transfering the sale amount to the seller failed");

        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI);
        setApprovalForAll(contractAddress, true);
        return newItemId;
    }
}