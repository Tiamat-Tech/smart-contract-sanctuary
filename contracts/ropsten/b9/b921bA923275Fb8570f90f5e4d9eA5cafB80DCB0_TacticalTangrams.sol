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
		Mint,
		Gen1,
		Gen2,
		Gen3,
		Gen4,
		Gen5,
		Gen6,
		Gen7
	}

	address public _creator;

	uint16[] TANS_PER_GENERATION = [
		MAX_MINTS, // Gen 1
		     6300, // Gen 2
		     4823, // Gen 3
		     3346, // Gen 4
		     1869, // Gen 5
		      385, // Gen 6
		       55  // Gen 7
	];

	// _tansPerGeneration is not a value type and therefore not constant. Max tans needs to be hardcoded here.
	tan[7777 + 6300 + 4823 + 3346 + 1869 + 385 + 55] _tans;

	uint8 constant public MAX_GENERATIONS = 7;

	// Mint limits
	uint8 constant public MAX_SHAPES = 7;
	uint16 constant public MAX_MINTS = 7777;
	uint8 constant public MAX_MINTS_PER_ADDRESS = 14;
	uint64 constant public MINT_PRICE = 7 * 1e16;

	// number of tans currently minted
	uint16 public _mintCounter;

	// seeds for all generations
	uint256[7] public _seeds;

	// current generation; 0 for minting period, 1-7 indicates generation 1-7 has been closed.
	Generation public _currentGeneration;

	// uint16 tanId (1-based index)
	mapping(address => uint16[]) public _ownedTans;

	// team share
	address[4] public _payees = [
		0x295cf92fAaE3cf809155850bfCC5cBc742A72b27,
		0x13e6A2dF42E00883b059f852Cb1d0C78Ebe3CBcE,
		0x9ccd31CAE8B047DdEfA522C347886d51fACCEE69,
		0x0C3483e3B355986D6Bb76E3CEbBC8dD8EC20779C
	];

	// shares per team member for mints in ETH per mint
	uint256[4] public _mintShares = [
		3150 * 1e13, // 45.0%
		2100 * 1e13, // 30.0%
		 875 * 1e13, // 12.5%
		 875 * 1e13  // 12.5%
	];

	// shares per team member for secondary sales in ETH per ETH received
	uint256[4] public _secondarySalesShares = [
		1500 * 1e14, // 15.00%
		2834 * 1e14, // 28.34%
		2833 * 1e14, // 28.33%
		2833 * 1e14  // 28.33%
	];

	uint256[4] public _mintSharesPaid;
	uint256[4] public _secondarySalesSharesPaid;

	constructor() ERC721 ("Tactical Tangrams", "TACT") {
		_mintCounter = 0;
		_currentGeneration = Generation.Mint;
		_creator = msg.sender;
	}

	function closeCurrentGeneration(uint256 seed) public {
		require(_creator == msg.sender, "Generation can only be closed by contract creator");
		require(uint8(_currentGeneration) < MAX_GENERATIONS, "All generations already closed");

		_seeds[uint8(_currentGeneration)] = seed;
		_currentGeneration = Generation(uint8(_currentGeneration) + 1);
	}

	function payout() public {
	 	for (uint8 i = 0; i < _payees.length; i++) {
	 		if (_payees[i] == msg.sender) {
	 			uint256 payment;
	 			if (_mintSharesPaid[i] < _mintCounter) {
	 				payment = _mintShares[i] * (_mintCounter - _mintSharesPaid[i]);
	 				_mintSharesPaid[i] = _mintCounter;
	 			}


	 			if (payment > 0) {
 					(bool sent, ) = msg.sender.call{value: payment}("");
 					require(sent, "Can't send payment");
 				}
 				break;
	 		}
	 	}
	}

	function mint() public payable {
		require(_mintCounter < MAX_MINTS, "Minting closed");
		uint8 numberOfTansToMint = uint8(msg.value / MINT_PRICE);
		require(_ownedTans[msg.sender].length + numberOfTansToMint <= MAX_MINTS_PER_ADDRESS, "Max 7 mints per address");
		require(_mintCounter + numberOfTansToMint <= MAX_MINTS, "Max 7777 mints");

		// Guarantee full tangram sets or subsets thereof when minting; no redundant pieces.
		// Within one transaction, IDs are consecutive, the ID defines the shape (ID % MAX_SHAPES).
		for (uint8 mintNum = 1; mintNum <= numberOfTansToMint; mintNum++) {
			_ownedTans[msg.sender].push(_mintCounter + mintNum);
		}

		_mintCounter += numberOfTansToMint;
	}

	function getGenerationForTanId(uint16 tanId) public view returns (uint8) {
		require(tanId > 0 && tanId <= _tans.length, "Invalid tan ID");

		uint16 cumulativeIndex = 0;
		for (uint8 generation = 1; generation <= MAX_GENERATIONS; generation++) {
			if (tanId <= (cumulativeIndex + TANS_PER_GENERATION[generation-1])) {
				return generation;
			}

			cumulativeIndex += TANS_PER_GENERATION[generation-1];
		}

		return MAX_GENERATIONS;
	}

	function getRarityForTanId(uint16 tanId) public view returns (uint8) {
		uint8 generation = getGenerationForTanId(tanId);
		require(generation > 0 && generation <= uint8(_currentGeneration), "Invalid tan ID");

		return uint8(uint256(keccak256(abi.encode(_seeds[generation-1], tanId))) % 100);
	}

	// function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
	// 	require(_exists(tokenId), "URI query for nonexistent token"
	// }
}