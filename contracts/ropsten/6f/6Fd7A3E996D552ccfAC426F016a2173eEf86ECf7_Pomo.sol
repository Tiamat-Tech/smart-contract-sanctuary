pragma solidity 0.8.11;

import "ERC721A.sol";
import "Ownable.sol";
import "ReentrancyGuard.sol";
import "ECDSA.sol";


contract Pomo is ERC721A, Ownable, ReentrancyGuard {
    using ECDSA for bytes32;

    uint256 public price = 10;
    uint256 public collectionSize = 20;
    uint256 public maxBatchSize = 5;
    string private _baseTokenURI;
    mapping(address => uint256) public _minted;
    string public mintHashPrefix = "Pomo whitelist valid only access";
    uint256 public maxWhitelistSize = 3;

    constructor() ERC721A("Pomo Ultimate 2", "POM") {}

    function mint(bytes memory signature, uint256 quantity) external payable {
        require(quantity * price == msg.value, "Invalid amount.");
        require(quantity <= maxBatchSize, "Quantity to mint too high");
        require(totalSupply() + quantity <= collectionSize, "Sold out.");
        require(_minted[msg.sender] + quantity <= maxWhitelistSize, 'You cannot mint this many.');
        require(isValid(msg.sender, signature), "Invalid signature.");

        _safeMint(msg.sender, quantity);
        _minted[msg.sender] += quantity;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function withdraw() external onlyOwner nonReentrant {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        require(success, "Transfer failed.");
    }

    function isValid(address _address, bytes memory _signature) internal view returns (bool) {
        return keccak256(abi.encodePacked(mintHashPrefix, _address, address(this))).recover(_signature) == owner();
    }

}