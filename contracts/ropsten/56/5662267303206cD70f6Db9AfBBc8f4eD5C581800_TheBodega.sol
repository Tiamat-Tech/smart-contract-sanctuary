// SPDX-License-Identifier: MIT
/*
 * TheBodega.sol
 *
 * Created: February 4, 2022
 *
 * Price: 0.088 ETH
 * Rinkeby: 0x422702e51f3F09289Caa80BCa7F0ae289E057BC5
 * Ropsten: 0x5662267303206cD70f6Db9AfBBc8f4eD5C581800
 * Mainnet: 
 *
 * - 535 total supply
 * - Pause/unpause minting
 * - Limited to 3 mints per wallet
 */

pragma solidity ^0.8.0;

import "./ERC721A16.sol";
import "./access/Pausable.sol";
import "./utils/ReentrancyGuard.sol";
import "./utils/LibPart.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

//@title The Bodega
//@author Jack Kasbeer (git:@jcksber, tw:@satoshigoat)
contract TheBodega is ERC721A16, Pausable, ReentrancyGuard {
	using SafeMath for uint256;

	//@dev Supply
	uint16 constant MAX_NUM_TOKENS = 535;//number of plug holders

	//@dev Properties
	string internal _contractURI;
	string internal _baseTokenURI;
	string internal _tokenHash;
	address public payoutAddress;
	uint256 public weiPrice;
	uint256 constant public royaltyFeeBps = 1500;//15%

	bytes32 private _secret;

	// ---------
	// MODIFIERS
	// ---------

	modifier onlyValidTokenId(uint256 tid)
	{
		require(
			0 <= tid && tid < MAX_NUM_TOKENS, 
			"TheBodega: tid OOB"
		);
		_;
	}

	modifier enoughSupply(uint16 qty)
	{
		require(
			uint16(totalSupply()) + qty < MAX_NUM_TOKENS, 
			"TheBodega: not enough left"
		);
		_;
	}

	modifier notEqual(string memory str1, string memory str2)
	{
		require(
			!_stringsEqual(str1, str2),
			"TheBodega: must be different"
		);
		_;
	}

	// ------------
	// CONSTRUCTION
	// ------------

	constructor() ERC721A16("The Bodega", "") {
		_baseTokenURI = "https://ipfs.io/ipfs/";
		_tokenHash = "QmYeRvkQV7HXvMXpocTsEdgw5gQZc7ySDpq6gJsPphkjbh";//token metadata ipfs hash
		_contractURI = "https://ipfs.io/ipfs/QmQRGrTBgjJf72DxJL52ZvkH9WqCZ6s7dMjX6jWJKRXUst";
		weiPrice = 88000000000000000;//0.088 ETH
		payoutAddress = address(0x6b8C6E15818C74895c31A1C91390b3d42B336799);//logik
	}

	// ----------
	// MAIN LOGIC
	// ----------

	// @dev See {ERC721A16-_baseURI}
	function _baseURI() internal view virtual override returns (string memory)
	{
		return _baseTokenURI;
	}

	// @dev See {ERC721A16-tokenURI}.
    function tokenURI(uint256 tid) public view virtual override
    	returns (string memory) 
    {
        require(_exists(tid), "ERC721Metadata: URI query for nonexistent token");
        return string(abi.encodePacked(_baseTokenURI, _tokenHash));
    }

    //@dev Controls the contract-level metadata to include things like royalties
	function contractURI() external view returns (string memory)
	{
		return _contractURI;
	}

	//@dev Allows owners to mint for free whenever
    function mint(address to, uint16 qty) 
    	external isSquad enoughSupply(qty)
    {
    	_safeMint(to, uint256(qty));
    }

    //@dev Allows public addresses (non-owners) to purchase
    function purchase(address payable to, uint16 qty, bytes32 secret) 
    	external payable enoughSupply(qty) saleActive
    {
    	uint8 maxMintPerWallet = 3;
    	require(
    		qty <= maxMintPerWallet, 
    		"TheBodega: batch must be 3 or less"
    	);
    	require(
    		_secret == secret, 
    		"TheBodega: invalid secret"
    	);
    	require(
    		numberMinted(to) + qty <= maxMintPerWallet, 
    		"TheBodega: max 3 per wallet"
    	);
    	require(
    		msg.value >= weiPrice*qty, 
    		"TheBodega: not enough ether"
    	);
    	require(!_isContract(to), "TheBodega: silly rabbit :P");

    	_safeMint(to, uint256(qty));
    }

	//@dev Allows us to withdraw funds collected
	function withdraw(address payable wallet, uint256 amount) 
		external isSquad nonReentrant
	{
		require(
			amount <= address(this).balance,
			"TheBodega: insufficient funds to withdraw"
		);

		wallet.transfer(amount);
	}

	//@dev Destroy contract and reclaim leftover funds
    function kill() external onlyOwner 
    {
        selfdestruct(payable(_msgSender()));
    }

    //@dev See `kill`; protects against being unable to delete a collection on OpenSea
    function safe_kill() external onlyOwner
    {
    	require(
    		balanceOf(_msgSender()) == totalSupply(),
    		"TheBodega: caught a potential error - not all tokens owned"
    	);
    	selfdestruct(payable(_msgSender()));
    }

    //@dev Only way to obtain secret bytes
    function getSecret() external isSquad view returns (bytes32)
	{
		return _secret;
	}

	/// -------
	/// SETTERS
	// --------

    //@dev Ability to change the base token URI
	function setBaseTokenURI(string calldata newBaseURI) 
		external isSquad notEqual(_baseTokenURI, newBaseURI) { _baseTokenURI = newBaseURI; }

	//@dev Ability to update the token metadata
    function setTokenHash(string calldata newHash) 
    	external isSquad notEqual(_tokenHash, newHash) { _tokenHash = newHash; }

	//@dev Ability to change the contract URI
	function setContractURI(string calldata newContractURI) 
		external isSquad notEqual(_contractURI, newContractURI) { _contractURI = newContractURI; }

	//@dev Change the secret word
	function setSecret(string calldata newSecret) external isSquad
	{
		bytes32 newSecret32 = _disguise(newSecret);
		require(
			_secret != newSecret32,
			"TheBodega: newSecret must be different"
		);
		_secret = newSecret32;
	}

	//@dev Change the price
	function setPrice(uint256 newWeiPrice) external isSquad
	{
		require(
			weiPrice != newWeiPrice, 
			"TheBodega: newWeiPrice must be different"
		);
		weiPrice = newWeiPrice;
	}

    // -------
    // HELPERS
    // -------

    //@dev Gives us access to the otw internal function `_numberMinted`
	function numberMinted(address owner) public view returns (uint256) 
	{
		return _numberMinted(owner);
	}

	//@dev Determine if two strings are equal using the length + hash method
	function _stringsEqual(string memory a, string memory b) 
		internal pure returns (bool)
	{
		bytes memory A = bytes(a);
		bytes memory B = bytes(b);

		if (A.length != B.length) {
			return false;
		} else {
			return keccak256(A) == keccak256(B);
		}
	}

	//@dev Determine if an address is a smart contract 
	function _isContract(address a) internal view returns (bool)
	{
		uint32 size;
		assembly {
			size := extcodesize(a)
		}
		return size > 0;
	}

	function _disguise(string memory word) private view returns (bytes32)
	{
		string memory xFactor = _getRandomWord();
		bytes memory hide = abi.encodePacked(word, xFactor);
		return keccak256(hide);
	}

	function _getRandomWord() private view returns (string memory)
	{
		string[36] memory words = ["shoe", "house", "idiot", "juice", "chicago", "california",
								   "mouse", "lamp", "cherish", "saliva", "pronto", "roger", 
								   "copy", "container", "purposeful", "react", "tailwind", "drag",
								   "viscosity", "velocity", "acceleration", "propel", "turbine", 
								   "bolt", "corner", "homie", "studio", "blunt", "joint", "crack",
								   "scotch", "vodka", "cherry", "berry", "kiwi", "lemon"];//36
		uint8 rnd = _random() % 35;

		return words[rnd];
	}

	//@dev Pseudo-random number generator
	function _random() private view returns (uint8 rnd)
	{
		uint8[4] memory weights = [60, 23, 15, 2];
		return uint8(uint(keccak256(abi.encodePacked(block.difficulty, block.timestamp, weights))));
	}

	// ---------
	// ROYALTIES
	// ---------

	//@dev Rarible Royalties V2
    function getRaribleV2Royalties(uint256 tid) 
    	external view onlyValidTokenId(tid) 
    	returns (LibPart.Part[] memory) 
    {
        LibPart.Part[] memory royalties = new LibPart.Part[](1);
        royalties[0] = LibPart.Part({
            account: payable(payoutAddress),
            value: uint96(royaltyFeeBps)
        });
        return royalties;
    }

    // @dev See {EIP-2981}
    function royaltyInfo(uint256 tid, uint256 salePrice) 
    	external view onlyValidTokenId(tid) 
    	returns (address, uint256) 
    {
        uint256 ourCut = SafeMath.div(SafeMath.mul(salePrice, royaltyFeeBps), 10000);
        return (payoutAddress, ourCut);
    }
}