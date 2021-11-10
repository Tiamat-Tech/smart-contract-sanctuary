pragma solidity ^0.8.9;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "base64-sol/base64.sol";

contract TacticalTangrams is ERC721 {
	enum Shape {
		TriangleSmall,
		TriangleMedium,
		TriangleLarge,
		Square,
		Rhombus
	}

	struct tan {
		Shape shape;
	}

	enum Generation {
		Gen1,
		Gen2,
		Gen3,
		Gen4,
		Gen5,
		Gen6,
		Gen7,
		END
	}

    uint16 constant MAX_MINTS = 7777;

	uint16[] TANS_PER_GENERATION = [
		MAX_MINTS, // Gen 1
		     6300, // Gen 2
		     4823, // Gen 3
		     3346, // Gen 4
		     1869, // Gen 5
		      385, // Gen 6
		       55  // Gen 7
	];

	// _tansPerGeneration is not a value type and therefore be constant. MAX_TANS needs to be hardcoded here.
	uint16 constant MAX_TANS = MAX_MINTS + 6300 + 4823 + 3346 + 1869 + 385 + 55;

	tan[MAX_TANS] _tans;

	// Mint limits
	uint8 constant MAX_SHAPES = 7;
	uint8 constant MAX_MINTS_PER_ADDRESS = 14;
	uint64 constant MINT_PRICE = 14 * 1e16;
	uint16 public _mintCounter;

	mapping (address => uint16[]) public _ownedTans;

	// Team share
	address[4] public _payees = [
		0x295cf92fAaE3cf809155850bfCC5cBc742A72b27,
		0x13e6A2dF42E00883b059f852Cb1d0C78Ebe3CBcE,
		0x9ccd31CAE8B047DdEfA522C347886d51fACCEE69,
		0x0C3483e3B355986D6Bb76E3CEbBC8dD8EC20779C
	];

	uint256[4] public _mintShares = [
		3150 * 1e13,
		2100 * 1e13,
		 875 * 1e13,
		 875 * 1e13
	];

	uint256[4] public _mintSharesPaid;

	constructor() ERC721 ("Tactical Tangrams", "TACT") {
		_mintCounter = 0;
	}

	function release(address account) public {
	 	for (uint8 i = 0; i < 4; i++) {
	 		if (_payees[i] == account) {
	 			uint256 payment;
	 			if (_mintSharesPaid[i] < _mintCounter) {
	 				payment = _mintShares[i] * (_mintCounter - _mintSharesPaid[i]);
	 				_mintSharesPaid[i] = _mintCounter;
	 			}


	 			if (payment > 0) {
	 				(bool sent, ) = account.call{value: payment}("");
	 				require(sent, "Can't send payment");
	 			}
	 			break;
	 		}
	 	}
	}

	function mint() public payable {
		require(_mintCounter < MAX_MINTS, "No more mints allowed");
		uint8 numberOfTansToMint = uint8(msg.value / MINT_PRICE);
		require(_ownedTans[msg.sender].length + numberOfTansToMint <= MAX_MINTS_PER_ADDRESS, "Max 7 mints per address");
		require(_mintCounter + numberOfTansToMint <= MAX_MINTS_PER_ADDRESS, "Max 7777 mints");

		// Guarantee full tangram sets or subsets thereof when minting; no redundant pieces.
		for (uint8 mintNum = 0; mintNum < numberOfTansToMint; mintNum++) {
			_ownedTans[msg.sender].push((_mintCounter + mintNum) % MAX_SHAPES);
		}

		_mintCounter += numberOfTansToMint;
	}

	function random() public view returns (string memory) {
		bytes32 hash = blockhash(block.number - 1);
		string memory hashEncoded = Base64.encode(bytes(string(abi.encodePacked(hash))));
		return hashEncoded;
	}

	function randomForId(uint256 seed, uint16 id) public pure returns (uint8) {
		return uint8(uint256(keccak256(abi.encode(seed, id))) % 100);
	}

	// function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
	// 	require(_exists(tokenId), "URI query for nonexistent token"
	// }
}