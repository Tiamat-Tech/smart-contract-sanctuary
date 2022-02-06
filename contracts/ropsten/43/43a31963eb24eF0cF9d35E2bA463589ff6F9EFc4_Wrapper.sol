// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract Wrapper is ERC721URIStorage {
    using ECDSA for bytes32;

    uint64 public totalTokens = 1;

    struct wrappedNFT {
        string tokenContract;
        uint64 tokenId;
        uint256 tokenLockTimestamp; 
    }

    mapping(string => mapping(uint64 => mapping(uint256 => string)))
        public burnedTokens;

    mapping(string => mapping(uint64 => uint64)) public wrappedTokens;
    mapping(uint64 => wrappedNFT) public wrappedId;

    constructor() ERC721("Hashi Ethereum", "hNFT") {}

    function wrap(
        string memory _tokenContract,
        uint64 _tokenId,
        uint256 _tokenLockTimestamp,
        string memory _tokenMetadata,
        address[] memory _signers,
        bytes[] memory _signatures
    ) external {
        require(
            wrappedTokens[_tokenContract][_tokenId] == 0,
            "Token already wrapped"
        );
        require(
            keccak256(
                abi.encodePacked(
                    (
                        burnedTokens[_tokenContract][_tokenId][
                            _tokenLockTimestamp
                        ]
                    )
                )
            ) == keccak256(abi.encodePacked((""))),
            "Token already burned with these signatures"
        );

        bytes32 hashMessage = keccak256(
            abi.encode(
                _tokenContract,
                _tokenId,
                _tokenLockTimestamp,
                msg.sender,
                _tokenMetadata,
                "locked"
            )
        ).toEthSignedMessageHash();

        for (uint64 k; k < _signatures.length; k++) {
            require(
                _signers[k] == hashMessage.recover(_signatures[k]),
                "wrong signature"
            );
        }
        wrappedTokens[_tokenContract][_tokenId] = totalTokens;
        wrappedNFT memory _wrappedNFT = wrappedNFT(_tokenContract,_tokenId,_tokenLockTimestamp);
        wrappedId[totalTokens] = _wrappedNFT;
        _mint(msg.sender, totalTokens);
        _setTokenURI(totalTokens, _tokenMetadata);
        totalTokens++;
    }

    function burn(
        string memory _tokenContract,
        uint64 _tokenId,
        uint256 _tokenLockTimestamp,
        string memory _destinationAddress
    ) external {
        uint64 _wrappedTokenId = wrappedTokens[_tokenContract][_tokenId];
        require(msg.sender == ownerOf(_wrappedTokenId));
        burnedTokens[_tokenContract][_tokenId][
            _tokenLockTimestamp
        ] = _destinationAddress;
        wrappedTokens[_tokenContract][_tokenId] = 0;
        super._burn(_wrappedTokenId); // revert if token _tokenId doesn't exist
    }

    
}