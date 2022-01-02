// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

/// @title gmDAO Token v2
/// @notice Migration of gm token v1 from shared Rarible contract to v2 custom contract
/// @author: 0xChaosbi.eth
/// "Omnia sol temperat" - The sun warms all
/// gmdao.ai

///////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                               //
//               ::::::::  ::::    ::::  ::::    ::: :::::::::::     :::                         //
//              :+:    :+: +:+:+: :+:+:+ :+:+:   :+:     :+:       :+: :+:                       //
//              +:+    +:+ +:+ +:+:+ +:+ :+:+:+  +:+     +:+      +:+   +:+                      //
//              +#+    +:+ +#+  +:+  +#+ +#+ +:+ +#+     +#+     +#++:++#++:                     //
//              +#+    +#+ +#+       +#+ +#+  +#+#+#     +#+     +#+     +#+                     //
//              #+#    #+# #+#       #+# #+#   #+#+#     #+#     #+#     #+#                     //
//               ########  ###       ### ###    #### ########### ###     ###                     //
//                              ::::::::   ::::::::  :::                                         //
//                             :+:    :+: :+:    :+: :+:                                         //
//                             +:+        +:+    +:+ +:+                                         //
//                             +#++:++#++ +#+    +:+ +#+                                         //
//                                    +#+ +#+    +#+ +#+                                         //
//                             #+#    #+# #+#    #+# #+#                                         //
//                              ########   ########  ##########                                  //
//   ::::::::::: :::::::::: ::::    ::::  :::::::::  :::::::::: :::::::::      ::: :::::::::::   //
//       :+:     :+:        +:+:+: :+:+:+ :+:    :+: :+:        :+:    :+:   :+: :+:   :+:       //
//       +:+     +:+        +:+ +:+:+ +:+ +:+    +:+ +:+        +:+    +:+  +:+   +:+  +:+       //
//       +#+     +#++:++#   +#+  +:+  +#+ +#++:++#+  +#++:++#   +#++:++#:  +#++:++#++: +#+       //
//       +#+     +#+        +#+       +#+ +#+        +#+        +#+    +#+ +#+     +#+ +#+       //
//       #+#     #+#        #+#       #+# #+#        #+#        #+#    #+# #+#     #+# #+#       //
//       ###     ########## ###       ### ###        ########## ###    ### ###     ### ###       //
//                                                                                               //
///////////////////////////////////////////////////////////////////////////////////////////////////

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract GmV2Ropsten is
    ERC721,
    IERC1155Receiver,
    IERC2981,
    Ownable,
    ReentrancyGuard
{
    using Strings for uint256;
    using Counters for Counters.Counter;

    Counters.Counter public nextNormalTokenId;
    Counters.Counter public _nextSpecialTokenId;

    address public raribleContractAddress; // 0xF322134563F6Ad2324b0F548cB30eDf2821A8f9D
    uint256 public raribleTokenId = 706480; // gm v1 token id on shared Rarible contract
    address public gmDAOAddress = 0xD18e205b41eEe3D208D3B10445DB95Ff02ba4acA; // gmdao.eth
    uint256 public maxSupply = 9; // Total of all normal and special 1/1 tokens minus burned tokens
    uint256 public maxNormalTokens = 6;
    uint256 public maxSpecialTokens = 3;
    string private baseTokenURI;
    bool private isMigrationActive;

    // @dev When a gm dao member sends their v1 token to this contract, we record that.
    mapping(address => uint256) public sentV1Tokens;

    constructor(string memory baseURI, address raribleAddress)
        ERC721("gmDAO Token v2", "GMV2")
    {
        baseTokenURI = string(abi.encodePacked(baseURI));
        raribleContractAddress = raribleAddress;
    }

    // ☉☉☉ MINT FUNCTIONS ☉☉☉

    /**
     * @dev Mints a gm v2 ERC-721 token.
     * @dev Requires user to have transferred their Rarible ERC-1155 gm v1 token to this contract first.
     */
    function upgradeToken() external migrationActive nonReentrant {
        require(
            (nextNormalTokenId.current() + _nextSpecialTokenId.current()) <
                maxSupply,
            "MAX_TOTAL_SUPPLY"
        );
        require(
            nextNormalTokenId.current() < maxNormalTokens,
            "MAX_NORMAL_SUPPLY"
        );
        // Requires that the minter has sent their v1 token and we have recorded that in sentV1Tokens
        require(sentV1Tokens[msg.sender] > 0, "NO_V1");

        uint256 newItemId = nextNormalTokenId.current();

        // Update state
        nextNormalTokenId.increment();
        sentV1Tokens[msg.sender] -= 1;

        // Mint v2 token
        _safeMint(msg.sender, newItemId);
    }

    /**
     * @dev Mints a batch of gm v2 ERC-721 tokens.
     * @dev Only callable by the owner.
     */
    function upgradeBatch(uint256 qty) external onlyOwner nonReentrant {
        require(
            ((nextNormalTokenId.current() + qty) +
                _nextSpecialTokenId.current()) < maxSupply,
            "MAX_TOTAL_SUPPLY"
        );
        require(
            (nextNormalTokenId.current() + qty) < maxNormalTokens,
            "MAX_NORMAL_SUPPLY"
        );

        for (uint256 i = 0; i < qty; i++) {
            uint256 newItemId = nextNormalTokenId.current();

            // Update state
            nextNormalTokenId.increment();

            // Mint v2 token
            _safeMint(msg.sender, newItemId);
        }
    }

    /**
     * @dev Mints a special edition 1/1 gm v2 ERC-721 token.
     * @dev Only callable by the owner.
     */
    function upgradeSpecialToken() public onlyOwner nonReentrant {
        require(
            (nextNormalTokenId.current() + _nextSpecialTokenId.current()) <
                maxSupply,
            "MAX_TOTAL_SUPPLY"
        );
        require(
            _nextSpecialTokenId.current() < maxSpecialTokens,
            "MAX_SPECIAL_SUPPLY"
        );

        uint256 newItemId = _nextSpecialTokenId.current();

        // Update state
        _nextSpecialTokenId.increment();

        // Mint v2 token
        _safeMint(msg.sender, newItemId);
    }

    // ☉☉☉ RECEIVE FUNCTIONS ☉☉☉

    /**
     * @dev Implements custom onERC1155Received hook.
     * @dev Only allows the gm v1 token (an ERC-1155 with tokenId 706480 on the shared Rarible contract 0xd07dc4262bcdbf85190c01c996b4c06a461d2430) to be sent.
     * @dev Stores the address of the sender so we know who can mint/redeem a gm v2 token.
     * @dev msg.sender is the NFT contract and param 'from' is the owner of the NFT.
     */
    function onERC1155Received(
        address,
        address from,
        uint256 id,
        uint256,
        bytes calldata
    ) external override migrationActive nonReentrant returns (bytes4) {
        require(
            msg.sender == address(raribleContractAddress),
            "WRONG_NFT_CONTRACT"
        );
        require(id == raribleTokenId, "ONLY_GM");

        sentV1Tokens[from] += 1;

        return
            bytes4(
                keccak256(
                    "onERC1155Received(address,address,uint256,uint256,bytes)"
                )
            );
    }

    /**
     * @dev Implements custom onERC1155BatchReceived hook.
     * @dev Only allows batches of the gm v1 token to be sent by checking the ids array.
     * @dev Stores the address of the sender so we know who can mint/redeem a gm v2 token.
     */
    function onERC1155BatchReceived(
        address,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes memory
    ) external override migrationActive nonReentrant returns (bytes4) {
        require(
            msg.sender == address(raribleContractAddress),
            "WRONG_NFT_CONTRACT"
        );
        require(ids[0] == raribleTokenId, "ONLY_GM");
        require(ids.length == 1);

        sentV1Tokens[from] += values[0];

        return
            bytes4(
                keccak256(
                    "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
                )
            );
    }

    // ☉☉☉ ADMIN ACTIONS ☉☉☉

    function setBaseURI(string memory _uri) external onlyOwner {
        baseTokenURI = _uri;
    }

    /**
     * @dev Toggle whether contract is active or not.
     */
    function toggleMigrationActive() public onlyOwner {
        isMigrationActive = !isMigrationActive;
    }

    // ☉☉☉ MODIFIERS ☉☉☉

    modifier migrationActive() {
        require(isMigrationActive, "NOT_ACTIVE");
        _;
    }

    // ☉☉☉ PUBLIC VIEW FUNCTIONS ☉☉☉

    function getTotalTokenCount() public view returns (uint256) {
        return nextNormalTokenId.current() + _nextSpecialTokenId.current();
    }

    function getBaseURI() external view returns (string memory) {
        return baseTokenURI;
    }

    /**
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(_exists(tokenId), "NONEXISTENT_TOKEN");

        return
            string(abi.encodePacked(baseTokenURI, tokenId.toString(), ".json"));
    }

    // ☉☉☉ ROYALTIES ☉☉☉

    /**
     * @dev See {IERC165-royaltyInfo}. Sets a 90% royalty on the token to discourage resales.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        require(_exists(tokenId), "NONEXISTENT_TOKEN");

        return (
            address(gmDAOAddress),
            SafeMath.div(SafeMath.mul(salePrice, 90), 100)
        );
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, IERC165)
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}