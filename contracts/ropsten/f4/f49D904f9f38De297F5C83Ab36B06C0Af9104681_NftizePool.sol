// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.6;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./NftPoolToken.sol";

contract NftizePool is Initializable, IERC721Receiver {
    address public poolToken;
    uint256 public basePrice;
    uint256 public poolSlots;
    mapping(address => mapping(uint => uint)) public nftPrices;

    function initialize(
        string memory name,
        string memory symbol,
        uint256 initialSupply,
        uint256 _basePrice,
        uint256 _poolSlots
    ) public virtual initializer {
        basePrice = _basePrice;
        poolSlots = _poolSlots;

        NftPoolToken poolTokenContract = new NftPoolToken();
        poolTokenContract.initialize(name, symbol, initialSupply);
        poolTokenContract.mint(address(this), poolSlots * basePrice);
        poolToken = address(poolTokenContract);

        IERC20(poolToken).approve(address(this), initialSupply);
        IERC20(poolToken).transferFrom(address(this), msg.sender, initialSupply);
    }

    function depositNFT(
        address nftContractAddress,
        uint256 tokenId,
        uint256 i
    ) public {
        IERC721(nftContractAddress).safeTransferFrom(msg.sender, address(this), tokenId);
        IERC20(poolToken).approve(address(this), basePrice);
        IERC20(poolToken).transferFrom(address(this), msg.sender, basePrice);
        nftPrices[nftContractAddress][tokenId] = basePrice + i;
    }

    function withdrawNFT(address nftContractAddress, uint256 tokenId) public {
        uint256 nftPrice = nftPrices[nftContractAddress][tokenId];
        IERC20(poolToken).approve(address(this), nftPrice);
        //Calling transferFrom here is enough as the poolToken is a new token, unaffected by the OpenZeppelin 2.x ERC20 transfer bug
        IERC20(poolToken).transferFrom(msg.sender, address(this), nftPrice);
        IERC721(nftContractAddress).safeTransferFrom(address(this), msg.sender, tokenId);
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}