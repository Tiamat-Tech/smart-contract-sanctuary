// SPDX-License-Identifier: CC-BY-NC-2.5
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WrappedRainbowCatsNFT is
  ERC721,
  IERC721Receiver,
  Pausable,
  Ownable,
  ERC721Burnable
{
  event Wrapped(uint256 indexed tokenId);
  event Unwrapped(uint256 indexed tokenId);

  IERC721 immutable rainbowCatsNFT;

  constructor(address rainbowCatsNFTContractAddress_)
    ERC721("Official Wrapped Rainbow Cats", "WRCATS")
  {
    rainbowCatsNFT = IERC721(rainbowCatsNFTContractAddress_);
  }

  function _baseURI() internal pure override returns (string memory) {
    return "ipfs://Qmb2S1EmAcrhLAn1vCfgYCv3DVN4czPKUQUCXQVxDp4HnV/";
  }

  function tokenURI(uint256 tokenId)
    public
    view
    override
    returns (string memory)
  {
    return string(abi.encodePacked(super.tokenURI(tokenId), ".json"));
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  /// Wrap Rainbow Cats NFT(s) to get Wrapped Rainbow Cat(s)
  function wrap(uint256[] calldata tokenIds_) external {
    for (uint256 i = 0; i < tokenIds_.length; i++) {
      rainbowCatsNFT.safeTransferFrom(msg.sender, address(this), tokenIds_[i]);
    }
  }

  /// Unwrap to get Rainbow Cats NFT(s) back
  function unwrap(uint256[] calldata tokenIds_) external {
    for (uint256 i = 0; i < tokenIds_.length; i++) {
      _safeTransfer(msg.sender, address(this), tokenIds_[i], "");
    }
  }

  function _flip(
    address who_,
    bool isWrapping_,
    uint256 tokenId_
  ) private {
    if (isWrapping_) {
      // Mint Wrapped Rainbow Cat of same tokenID if not yet minted, otherwise swap for existing Wrapped Rainbow Cat
      if (_exists(tokenId_) && ownerOf(tokenId_) == address(this)) {
        _safeTransfer(address(this), who_, tokenId_, "");
      } else {
        _safeMint(who_, tokenId_);
      }
      emit Wrapped(tokenId_);
    } else {
      rainbowCatsNFT.safeTransferFrom(address(this), who_, tokenId_);
      emit Unwrapped(tokenId_);
    }
  }

  // Notice: You must use safeTransferFrom in order to properly wrap/unwrap your Rainbow Cat.
  function onERC721Received(
    address operator_,
    address from_,
    uint256 tokenId_,
    bytes memory data_
  ) external override returns (bytes4) {
    // Only supports callback from the original RainbowCatsNFTs contract and this contract
    require(
      msg.sender == address(rainbowCatsNFT) || msg.sender == address(this),
      "must be RainbowCatNFT or WrappedRainbowCat"
    );

    bool isWrapping = msg.sender == address(rainbowCatsNFT);
    _flip(from_, isWrapping, tokenId_);

    return this.onERC721Received.selector;
  }

  function _beforeTokenTransfer(
    address from,
    address to,
    uint256 tokenId
  ) internal override whenNotPaused {
    super._beforeTokenTransfer(from, to, tokenId);
  }

  fallback() external payable {}

  receive() external payable {}

  function withdrawETH() external onlyOwner {
    (bool success, ) = owner().call{value: address(this).balance}("");
    require(success, "Transfer failed.");
  }

  function withdrawERC20(address token) external onlyOwner {
    bool success = IERC20(token).transfer(
      owner(),
      IERC20(token).balanceOf(address(this))
    );
    require(success, "Transfer failed");
  }

  // @notice Mints or transfers wrapped rainbow cat nft to owner for users who incorrectly transfer a Rainbow Cat or Wrapped Rainbow Cat directly to the contract without using safeTransferFrom.
  // @dev This condition will occur if onERC721Received isn't called when transferring.
  function emergencyMintWrapped(uint256 tokenId_) external onlyOwner {
    if (rainbowCatsNFT.ownerOf(tokenId_) == address(this)) {
      // Contract owns the Rainbow Cat.
      if (_exists(tokenId_) && ownerOf(tokenId_) == address(this)) {
        // Wrapped Rainbow Cat is also trapped in contract.
        _safeTransfer(address(this), owner(), tokenId_, "");
        emit Wrapped(tokenId_);
      } else if (!_exists(tokenId_)) {
        // Wrapped Rainbow Cat hasn't ever been minted.
        _safeMint(owner(), tokenId_);
        emit Wrapped(tokenId_);
      } else {
        revert("Wrapped Rainbow Cat minted and distributed already");
      }
    } else {
      revert("Rainbow Cat is not locked in contract");
    }
  }
}