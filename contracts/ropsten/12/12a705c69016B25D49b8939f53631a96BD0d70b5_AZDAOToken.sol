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

    mapping(address => bool) existingUsers;
    mapping(address => bool) whitelist;
    mapping(string => bool) existingURIs;
    mapping(address => User) users;

    modifier whitelistSetter {
        require(msg.sender == 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4);
        _;
    }

    event UserCreated(address, address, uint8, uint8);
    event MintedByInvite(address, address, uint8);

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

    function addToWhitelist(address addr) public {
        require(!existingUsers[addr], "User exists");
        User memory user = User(address(0), 0, 1);
        emit UserCreated(addr, address(0), 0, 1);
        existingUsers[addr] = true;
        users[addr] = user;
        whitelist[addr] = true;
    }

    function payToMint(address recipient, address invited_by, string[] memory metadataURIs) public payable {
        require(msg.value >= metadataURIs.length * Constants.PRICE, 'Not enough coins!');
        require(metadataURIs.length <= Constants.MAX_TOKENS, 'Too many tokens!');
        require(recipient != address(0), "Invalid recipient");
        require(recipient != invited_by, "You cant invite yourself");

        uint8 n = uint8(metadataURIs.length);

        if (!existingUsers[recipient]) {
            User memory new_user = User(invited_by, 0, 0);
            if (whitelist[recipient]) {
                new_user.to_redeem = 1;
            }
            users[recipient] = new_user;
            existingUsers[recipient] = true;
            emit UserCreated(recipient, invited_by, n, new_user.to_redeem);
        }

        User memory user = users[recipient];

        if (user.n_tokens + user.to_redeem + n > Constants.MAX_TOKENS) {
            revert('You have reached the maximum number of tokens!');
        }

        for (uint i = 0; i < metadataURIs.length; i++) {
            if (existingURIs[metadataURIs[i]]) {
                revert("Token already minted by someone else!");
            }

            uint256 newItemId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            existingURIs[metadataURIs[i]] = true;

            _mint(recipient, newItemId);
            _setTokenURI(newItemId, metadataURIs[i]);
        }

        payable(Constants.OWNER).transfer(msg.value);

        user.n_tokens += n;
        User memory inviter = users[invited_by];
        inviter.to_redeem += n;
        users[invited_by] = inviter;
        users[recipient] = user;
        emit MintedByInvite(recipient, invited_by, n);
    }

    function redeem(address recipient, string[] memory metadataURIs) public {
        require(existingUsers[recipient], 'User does not exist!');
        User memory user = users[recipient];
        require(user.to_redeem > 0, 'No tokens to redeem!');
        require(user.to_redeem == metadataURIs.length, 'Step off bitch');

        uint8 n = user.to_redeem;

        user.to_redeem = 0;
        user.n_tokens += n;

        users[recipient] = user;


        for (uint i = 0; i < n; i++) {
            if (existingURIs[metadataURIs[i]]) {
                revert("Token already minted by someone else!");
            }

            uint256 newItemId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            existingURIs[metadataURIs[i]] = true;

            _mint(recipient, newItemId);
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