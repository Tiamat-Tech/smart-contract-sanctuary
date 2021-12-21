//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CyanWrappedNFTV1 is
    AccessControl,
    ERC721,
    ReentrancyGuard,
    ERC721Holder
{
    bytes32 public constant CYAN_ROLE = keccak256("CYAN_ROLE");
    bytes32 public constant CYAN_PAYMENT_PLAN_ROLE =
        keccak256("CYAN_PAYMENT_PLAN_ROLE");

    address _cyanAddress;
    address _originalNFT;
    ERC721 _originalNFTContract;

    event Wrap(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );
    event Unwrap(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    // TODO(Naba): Change cyanAddress method

    constructor(
        address originalNFT,
        address cyanAddress,
        address cyanPaymentPlanContractAddress
    ) ERC721("CyanWrappedNFT", "CNFT") {
        // console.log(
        //     "Deploying a CyanWrappedNFT of address: %s, to wrapped address : %s, with cyan address : %s",
        //     originalNFT,
        //     address(this),
        //     cyanAddress
        // );
        _cyanAddress = cyanAddress;
        _originalNFT = originalNFT;
        _originalNFTContract = ERC721(_originalNFT);

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(CYAN_ROLE, msg.sender);
        _setupRole(CYAN_PAYMENT_PLAN_ROLE, cyanPaymentPlanContractAddress);
    }

    function wrap(address to, uint256 tokenId)
        public
        nonReentrant
        onlyRole(CYAN_ROLE)
    {
        // console.log(
        //     "Wrapping nft with tokenid:, to:, msg.sender:",
        //     tokenId,
        //     to,
        //     msg.sender
        // );

        require(to != address(0), "wrap to the zero address");
        require(!_exists(tokenId), "token already wrapped");

        _originalNFTContract.safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );
        _safeMint(to, tokenId);

        emit Wrap(msg.sender, to, tokenId);
    }

    function unwrap(uint256 tokenId, bool isDefaulted)
        public
        nonReentrant
        onlyRole(CYAN_PAYMENT_PLAN_ROLE)
    {
        require(_exists(tokenId), "token is not wrapped");

        // console.log(
        //     "Unwrapping nft with tokenid:, isDefaulted:, msg.sender:",
        //     tokenId,
        //     isDefaulted,
        //     msg.sender
        // );

        address to;
        if (isDefaulted) {
            to = _cyanAddress;
        } else {
            to = this.ownerOf(tokenId);
        }

        _originalNFTContract.safeTransferFrom(address(this), to, tokenId);
        _burn(tokenId);

        emit Unwrap(msg.sender, to, tokenId);
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}