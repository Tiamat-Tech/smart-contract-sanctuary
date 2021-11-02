// SPDX-License-Identifier: MIT
// Author: [email protected] 
// Website: https://intro.torum.com

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

//LP XTM REWARD SERIES CONTRACTS
contract LP_FARMING_TORUM is AccessControl, Pausable, ERC1155
{    
    using SafeMath for uint256;
    IERC20 public xtm;
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    //Mapping for NFT Token to Price
    mapping(uint256 => uint256) nftPrice;

    constructor(address _xtmtokenAddress) ERC1155("https://av.cdn.torum.com/nft/uniswap-series/{id}.json") {
        xtm = IERC20(_xtmtokenAddress);
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    //Sets the Price of NFT Series
    function setTokenPrice(uint256 _tokenId, uint256 _price) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "LP_FARMING_TORUM: Caller is not a admin");
        nftPrice[_tokenId] = _price;
    }

    //Gets the Price of NFT Series
    function getTokenPrice(uint256 _tokenId) public view returns(uint256) {
        return nftPrice[_tokenId];
    }

    /**
     * @dev Creates `amount` new tokens for `to`, of token type `id`.
     *
     * See {ERC1155-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(
        uint256 id,
        uint256 amount,
        uint256 price,
        bytes memory data
    ) public virtual {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "LP_FARMING_TORUM: must have minter role to mint"
        );
        nftPrice[id] = price;
        _mint(msg.sender, id, amount, data);
    }

    /**
     * @dev Set new uri.
     *     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function setUri(string memory _uri) public virtual {
        require(
            hasRole(MINTER_ROLE, _msgSender()),
            "LP_FARMING_TORUM: must have minter role to mint"
        );

        _setURI(_uri);
    }

    // Claim back your XTM on burning NFT ID
    function burn(uint256 _tokenId, uint256 _supply) public {
        if(!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)){
            require(!paused(), "LP_FARMING_TORUM: leaving while paused");
        }
        
        //Burn NFT
        _burn(msg.sender, _tokenId, _supply);

        uint256 _amount = _supply.mul(nftPrice[_tokenId]);

        //TRANSFER XTM
        xtm.transfer(msg.sender, _amount);
    }

        /* @dev Pauses all actions.
     *
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public virtual {
        require(
            hasRole(PAUSER_ROLE, _msgSender()),
            "LP_FARMING_TORUM: must have pauser role to pause"
        );
        _pause();
    }

        /* @dev UnPause all actions.
     *
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public virtual {
        require(
            hasRole(PAUSER_ROLE, _msgSender()),
            "LP_FARMING_TORUM: must have pauser role to pause"
        );
        _unpause();
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    uint256[50] private __gap;
}