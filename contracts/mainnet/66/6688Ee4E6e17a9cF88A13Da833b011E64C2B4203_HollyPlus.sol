// SPDX-License-Identifier: GPL-v3

/**

               .-://///:`                                                                 
            .:/-.`   `-+/-             `.....                                             
          -/:`         -+/             `./++-                            .-.              
        ./:`           `++`              /+:                             -+-              
      `:/-             `+/              -+/          ``  `               .+.              
     .//.              -+:              /+.       .:/+/:/+-              .+.              
    -+/`               /+.             -+:         `/+.`++.              .+.              
   :+/`               -+:             `//`          /+. ++.              .+.              
  :+/`               `//`             :+.           /+. ++.              .+.              
 /++:................:/:.............-+/......----  /+. ++. .---.........-+-........---::-
.-------------------:+:--------------//---:::::////`/+. ++.:///::::::----:+:--:::::::::/- 
                   .+/`             :+- `-::://:.   /+. ++.--::.    `:::..+.              
                  `/+.             .+/`:/.    `:+/. /+. ++.`-++.     //` .+.              
                 `/+:              //`:+-       :+/`/+. ++.  -+/`   :/`  .+.              
                 /+/              -+- /+:       `++-/+. ++.   :+/  -/`   .+.              
                :+/`             `//  :+/`      `+/`/+. ++.    :+:./.    .+.              
              ./++-              /+.   ://-`   .//. /+- ++.     /+/.     .+-              
             -::::.             -+:     `-:::::-.  -:::::::.    .+-      -/-              
                               `//`                            `/-  ``` -`  ` ``          
                               :+.                    ``      ./-   --.::-. /-::.         
                              .+:                     //:-..-:/.    -:-.-`---.--`         
                             `//`                      `.----`      `                     
                             :+-                                                          
                            .+/                                                           
                           `//`                                                           
                           :+:                                                            
                          .+/`                                                            
                         `/+.                                                             
                         /+/                                                              
                        :++.                                                              
                       -++/                                                               
                     `:////                                                               


*/

pragma solidity 0.8.5;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./royalties/RoyaltyConfig.sol";
import "./utils/ISubmitterPayoutInformation.sol";

/**
 * author: iain
 * org: zora
 * project: holly+ artist contract
 *
 *
 * ERC721 token contract, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *  - integration into royalty standards
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter and admin
 * roles, as well as the default admin role.
 */
contract HollyPlus is
    Context,
    AccessControl,
    ERC721,
    ERC721Enumerable,
    RoyaltyConfig,
    ISubmitterPayoutInformation
{
    using Counters for Counters.Counter;
    event URIsUpdated(uint256, string, string);
    event Mint(address indexed, uint256 indexed, address indexed, string, bytes32, string, bytes32);

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant MAINTAINER_ROLE = keccak256("MAINTAINER_ROLE");

    Counters.Counter private _tokenIdTracker;
    struct TokenInfo {
        bytes32 metadataHash;
        bytes32 contentHash;
        address submitterAddress;
        string metadataURI;
        string contentURI;
    }
    mapping(uint256 => TokenInfo) private tokenInfo;

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE` and `MAINTAINER_ROLE` to the
     * account that deploys the contract.
     *
     * Token URIs will be autogenerated based on `baseURI` and their token IDs.
     * See {ERC721-tokenURI}.
     */
    constructor(string memory name, string memory symbol) ERC721(name, symbol) {
        // start at token 1 not 0
        _tokenIdTracker.increment();

        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function getURIs(uint256 tokenId)
        public
        view
        returns (string memory, bytes32, string memory, bytes32)
    {
        TokenInfo memory info = tokenInfo[tokenId];
        return (info.metadataURI, info.metadataHash, info.contentURI, info.contentHash);
    }

    /**
      Only minter can burn.
    */
    function burn(uint256 tokenId) public onlyRole(MINTER_ROLE) {
        require(_exists(tokenId));
        require(ERC721.ownerOf(tokenId) == _msgSender(), "Not Contract Owner");
        _burn(tokenId);
    }
    
    function tokenContentURI(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        return tokenInfo[tokenId].contentURI;
    }

// TODO: should be creator or submitter?
    function submitter(uint256 tokenId)
        public
        view
        override
        returns (address)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        return tokenInfo[tokenId].submitterAddress;
    }

    /**
     * @dev Creates a new token for `to`. Its token ID will be automatically
     * assigned (and available on the emitted {IERC721-Transfer} event), and the token
     * URI autogenerated based on the base URI passed at construction.
     *
     * See {ERC721-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(
        address to,
        string memory _metadataURI,
        bytes32 metadataHash,
        string memory _contentURI,
        bytes32 contentHash,
        address submitterAddress,
        address royaltyPayoutAddress,
        uint256 royaltyBPS
    ) public onlyRole(MINTER_ROLE) {
        require(royaltyBPS < 10000, "Royalty needs to be less than 10000 bps");
        uint256 tokenId = _tokenIdTracker.current();
        _mint(to, tokenId);
        tokenInfo[tokenId] = TokenInfo({
            metadataURI: _metadataURI,
            metadataHash: metadataHash,
            contentURI: _contentURI,
            contentHash: contentHash,
            submitterAddress: submitterAddress
        });
        emit Mint(_msgSender(), tokenId, submitterAddress, _metadataURI, metadataHash, _contentURI, contentHash);
        _setRoyaltyForToken(royaltyPayoutAddress, royaltyBPS, tokenId);
        _tokenIdTracker.increment();
    }

    function updateRoyaltyInfo(
        uint256 tokenId,
        address royaltyPayoutAddress
    ) public onlyRole(MAINTAINER_ROLE) {
        _setRoyaltyPayoutAddressForToken(royaltyPayoutAddress, tokenId);
    }

    function updateTokenURIs(
        uint256 tokenId,
        string memory _metadataURI,
        string memory _contentURI
    ) public onlyRole(MAINTAINER_ROLE) {
        tokenInfo[tokenId].metadataURI = _metadataURI;
        tokenInfo[tokenId].contentURI = _contentURI;
        emit URIsUpdated(tokenId, _metadataURI, _contentURI);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        return tokenInfo[tokenId].metadataURI;
    }

    // Needed to call multiple supers.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // Needed to call multiple supers.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(AccessControl, ERC721, ERC721Enumerable, RoyaltyConfig)
        returns (bool)
    {
        return super.supportsInterface(interfaceId) || interfaceId == type(ISubmitterPayoutInformation).interfaceId;
    }
}