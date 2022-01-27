// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Constants.sol";

    struct User {
        address invited_by;
        uint128 n_tokens;
        uint128 to_redeem;
    }

contract AZDAOToken is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    mapping(address => bool) existingUsers;
    mapping(address => bool) whitelist;
    mapping(string => bool) existingURIs;
    mapping(address => User) users;

    event UserCreated(address, address, uint128, uint128);
    event MintedByInvite(address, address, uint128);

    constructor() ERC721("AZDAOToken", "AZT") {}

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://";
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function isContentOwned(string memory uri) public view returns (bool) {
        return existingURIs[uri];
    }

    function isInWhitelist(address addr) public view returns (bool) {
        return whitelist[addr];
    }

    function addToWhitelist(address[] memory addresses) public {
        require(msg.sender == Constants.OWNER, "Nah-nah-nah, not gonna happen");

        for (uint i = 0; i < addresses.length; i++) {
            User memory user = User(address(0), 0, 1);
            emit UserCreated(addresses[i], address(0), 0, 1);
            existingUsers[addresses[i]] = true;
            users[addresses[i]] = user;
            whitelist[addresses[i]] = true;
        }
    }

    function payToMint(address invited_by, string[] memory metadataURIs) public payable {
        require(msg.value >= metadataURIs.length * Constants.PRICE, 'Not enough coins');
        require(metadataURIs.length <= Constants.MAX_TOKENS, 'Too many tokens');
        require(msg.sender != address(0), "Invalid recipient");
        require(msg.sender != invited_by, "You cant invite yourself");

        uint128 n = uint128(metadataURIs.length);

        if (!existingUsers[msg.sender]) {
            User memory new_user = User(invited_by, 0, 0);
            users[msg.sender] = new_user;
            existingUsers[msg.sender] = true;
            emit UserCreated(msg.sender, invited_by, n, new_user.to_redeem);
        }

        User memory user = users[msg.sender];

        if (user.n_tokens + user.to_redeem + n > Constants.MAX_TOKENS) {
            revert('You have reached the maximum number of tokens');
        }

        for (uint i = 0; i < metadataURIs.length; i++) {
            if (existingURIs[metadataURIs[i]]) {
                revert("Token already minted by someone else");
            }

            uint256 newItemId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            existingURIs[metadataURIs[i]] = true;

            _mint(msg.sender, newItemId);
            _setTokenURI(newItemId, metadataURIs[i]);
        }

        payable(Constants.OWNER).transfer(msg.value);

        user.n_tokens += n;
        User memory inviter = users[invited_by];
        inviter.to_redeem += n;
        users[invited_by] = inviter;
        users[msg.sender] = user;
        emit MintedByInvite(msg.sender, invited_by, n);
    }

    function redeem(string[] memory metadataURIs) public {
        require(existingUsers[msg.sender], 'User does not exist');
        User memory user = users[msg.sender];
        require(user.to_redeem > 0, 'No tokens to redeem');
        require(user.to_redeem == metadataURIs.length, 'Either redeem all or none');

        uint128 n = uint128(user.to_redeem);

        user.to_redeem = 0;
        user.n_tokens += n;

        users[msg.sender] = user;

        for (uint256 i = 0; i < n; i++) {
            if (existingURIs[metadataURIs[i]]) {
                revert("Token already minted by someone else!");
            }

            uint256 newItemId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            existingURIs[metadataURIs[i]] = true;

            _mint(msg.sender, newItemId);
            _setTokenURI(newItemId, metadataURIs[i]);
        }
    }

    function getUser(address addr) public view returns (User memory) {
        return users[addr];
    }

    function count() public view returns (uint256) {
        return _tokenIdCounter.current();
    }
}