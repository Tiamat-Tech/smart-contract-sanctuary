// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.1;
pragma abicoder v2;

import "Ownable.sol";
import "ERC721.sol";
import "ECDSA.sol";
import "Counters.sol";

contract JetsSingularToken is Ownable, ERC721 {
    using ECDSA for bytes32;

    mapping(address => bool) public signers;
    mapping(uint256 => bool) operations;
    mapping(uint256 => string) uris;
    mapping(uint256 => address) public creators;

    uint256 public nextTokenId;

    event SignerAdded(address _address);
    event SignerRemoved(address _address);
    event TokenMinted(uint256 _operationId, uint256 _tokenId);

    constructor() ERC721("Jets", "JETS") {
        address _msgSender = msg.sender;

        transferOwnership(_msgSender);
        signers[_msgSender] = true;
        emit SignerAdded(_msgSender);
    }

    function addSigner(address _address) public onlyOwner {
        signers[_address] = true;
        emit SignerAdded(_address);
    }

    function removeSigner(address _address) public onlyOwner {
        signers[_address] = false;
        emit SignerRemoved(_address);
    }

    function mint(
        uint256 _operationId,
        string memory _uri,
        bytes memory _signature
    ) public {
        require(
            operations[_operationId] == false,
            "SingularToken: Operation is already performed"
        );
        require(bytes(_uri).length > 0, "SingularToken: _uri is required");
        
        address _msgSender = msg.sender;
        uint256 _id = nextTokenId;
        address signer = keccak256(
            abi.encodePacked(_msgSender, _operationId, _uri)
        ).toEthSignedMessageHash().recover(_signature);
        require(signers[signer], "SingularToken: Invalid signature");

        _mint(_msgSender, _id);

        emit TokenMinted(_operationId, _id);

        operations[_operationId] = true;
        uris[_id] = _uri;
        creators[_id] = _msgSender;
        nextTokenId += 1;
    }

    function tokenURI(uint256 _id) public view override returns (string memory) {
        return uris[_id];
    }
}