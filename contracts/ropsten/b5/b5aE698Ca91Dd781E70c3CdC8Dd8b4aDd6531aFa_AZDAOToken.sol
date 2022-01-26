// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Constants.sol";

    struct User {
        address invited_by;
        uint8 n_tokens;
        uint8 to_redeem;
    }

contract AZDAOToken is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    mapping(address => uint8) existingUsers;
    mapping(string => uint8) existingURIs;
    mapping(address => User) users;

    event Log(address, address, uint8, uint8);

    constructor() ERC721("AZDAOToken", "AZT") {}

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://";
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function isContentOwned(string memory uri) public view returns (bool) {
        return existingURIs[uri] == 1;
    }

    function payToMint(address recipient, address invited_by, string[] memory metadataURIs) public payable {
        require(msg.value >= metadataURIs.length * Constants.PRICE, 'Not enough coins!');
        require(metadataURIs.length <= Constants.MAX_TOKENS, 'Too many tokens!');
        require(recipient != address(0), 'Invalid recipient!');
        require(recipient != invited_by, 'You cannot invite yourself!');

        uint8 n = uint8(metadataURIs.length);

        if (existingUsers[recipient] == 0) {
            User memory new_user = User({invited_by : invited_by, n_tokens : n, to_redeem : 0});

            users[recipient] = new_user;
            existingUsers[recipient] = 1;
        }

        User memory user = users[recipient];
        emit Log(recipient, user.invited_by, user.n_tokens, user.to_redeem);

        if (user.n_tokens + user.to_redeem + n > Constants.MAX_TOKENS) {
            revert('You have reached the maximum number of tokens!');
        }

        for (uint i = 0; i < metadataURIs.length; i++) {
            if (existingURIs[metadataURIs[i]] == 1) {
                revert("Token already minted by someone else!");
            }

            uint256 newItemId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            existingURIs[metadataURIs[i]] = 1;

            _mint(recipient, newItemId);
            _setTokenURI(newItemId, metadataURIs[i]);
        }

        payable(Constants.OWNER).transfer(msg.value);

        user.n_tokens += n;
        if (existingUsers[invited_by] == 1) {
            users[invited_by].to_redeem += n;
        }
        users[recipient] = user;
    }

    function redeem(address recipient, string[] memory metadataURIs) public {
        require(existingUsers[recipient] != 0, 'User does not exist!');
        User memory user = users[recipient];
        require(user.to_redeem > 0, 'No tokens to redeem!');

        uint8 n = user.to_redeem;

        users[recipient].to_redeem = 0;
        users[recipient].n_tokens += n;


        for (uint i = 0; i < n; i++) {
            if (existingURIs[metadataURIs[i]] == 1) {
                revert("Token already minted by someone else!");
            }

            uint256 newItemId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            existingURIs[metadataURIs[i]] = 1;

            _mint(recipient, newItemId);
            _setTokenURI(newItemId, metadataURIs[i]);
        }
    }

    function count() public view returns (uint256) {
        return _tokenIdCounter.current();
    }
}