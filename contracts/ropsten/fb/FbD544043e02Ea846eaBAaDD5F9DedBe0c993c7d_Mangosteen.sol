pragma solidity ^0.8.4;

import "erc721a/contracts/ERC721A.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev Interface of the CallerAuthenticator using Schnorr protocol
 */
interface CallerAuthenticatorInterface {
    /**
     * @dev Returns the token ID if authenticated. Otherwise, it reverts.
     */
    function processAuthentication(uint256 preprocessed_id, uint256 p1, uint256 p2, uint256 s, uint256 e) external returns (uint256);
}

contract Mangosteen is Ownable, ERC721A {
	using Strings for uint256;

	string private _baseTokenURI;
	uint256 public totalNFTSupply = 100;
    uint256 public maxBatch = 10;

    CallerAuthenticatorInterface private authenticator;

	constructor(string memory name_, string memory symbol_, string memory baseURI_, address authenticatorAddress_) ERC721A(name_, symbol_) {
		_baseTokenURI = baseURI_;
		authenticator = CallerAuthenticatorInterface(authenticatorAddress_);
	}

	function mint(uint256 quantity) public payable {
		require(quantity <= maxBatch, "Over the threashold");
		require(_currentIndex + quantity < totalNFTSupply, "Sold out");
		_safeMint(msg.sender, quantity);
	}

	function mintWithAuthentication(uint256 requestId, uint256 pubkey1, uint256 pubkey2, uint256 s, uint256 e) payable public {
		uint256 quantity = authenticator.processAuthentication(requestId, pubkey1, pubkey2, s, e);

		require(quantity <= maxBatch, "Over the threashold");
		require(_currentIndex + quantity < totalNFTSupply, "Sold out");
		_safeMint(msg.sender, quantity);
	}

	function _baseURI() internal view virtual override returns (string memory) {
		return _baseTokenURI;
	}

	function setBaseURI(string calldata baseURI) external onlyOwner {
		_baseTokenURI = baseURI;
  	}

  	function testAuthentication(uint256 preprocessed_id, uint256 p1, uint256 p2, uint256 s, uint256 e) public returns (uint256) {
        uint256 quantity = authenticator.processAuthentication(preprocessed_id, p1, p2, s, e);
        return quantity;
    }

    function getMaxBatchSize() public returns (uint256) {
    	return maxBatch;
    }
}