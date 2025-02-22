pragma solidity ^0.8.0;

// Import contracts.
import "./CitizenERC721.sol";
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';

//@title Kong Land Alpha $CITIZEN Token
contract CtznERC20 is ERC20, ERC20Burnable {

    CitizenERC721 public _citizenERC721;

    // Mapping for claim status token.
    mapping(address => bool) public _claimedERC721;

    constructor(CitizenERC721 citizenERC721) ERC20('KONG Land Citizenship', 'CTZN') {
        _citizenERC721 = citizenERC721;
        _mint(msg.sender, 4644 * 10 ** 18);
    }

    function claim(uint256 tokenId) external {
        address from = msg.sender;

        // Verify that token holder is 178 or lower.
        require(tokenId <= 178, "Only token holder 178 or lower can claim.");

        // Require that the account calling is the same as the owner of the tokenId.
        require(_citizenERC721.ownerOf(tokenId) == from, "Only token holder can claim.");

        // Verify that this token has not minted yet.
        require(_claimedERC721[from] == false, 'Already claimed.');

        _mint(msg.sender, 2 * 10 ** 18);
    }

}