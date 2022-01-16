// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
//import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract HoneyBadgers is ERC721Enumerable, Ownable, PaymentSplitter {
	using Address for address;
	using Strings for uint256;
	//using MerkleProof for bytes32[];
	using Counters for Counters.Counter;

	

	string public _contractBaseURI = "https://metadata-live.radreindeer.com/v1/metadata/";
	string public _contractURI = "ipfs://QmX8tvc1MKv8Ejnai7g32R6s5KKDUSfUjFDtu5CnFj35kY";
	address private devWallet;
	//mapping(address => uint256) public usedAddresses; //max 3 per address for whitelist
	bool public locked; //metadata lock
	uint256 public maxSupply = 10000;
	uint256 public maxSupplyPresale = 3000;

	uint256 public presaleStartTime = 1639893600;
	uint256 public saleStartTime = 1639980000;
    //uint[3][3] public segments=[[0,1000,5],[1001,3000,10],[3001,8000,10]];
	uint[3] public genesis=[1000,5,.035 ether];
	uint[3] public pioneer=[3000,10,.05 ether];
	uint[3] public builder=[8000,10,.06 ether];
	uint[3] public dao=[10000,10,.07 ether];
    //uint256[]  public tokenPrice=[.035 ether,.05 ether,.06 ether];
	address[] private addressList = [
		0x75Ca74CF7238a8D8337ED8c45F584c220b176d55, //d
		0xecf86Cf8689394ED484c5B62f8Dd78ccCc750d41, //h
		0x087233679BB8B0223837914c62a51350c40c8012 //n
	];
	uint256[] private shareList = [50, 49, 1];

	Counters.Counter private _tokenIds;

	//----------- Reward System ----------- //only used in case of emergency
	uint256 public rewardEndingTime = 0; //unix time
	uint256 public maxRewardTokenID = 2000; //can claim if you have < this tokenID
	uint256 public maxFreeNFTperID = 1;
	mapping(uint256 => uint256) public claimedPerID;

	modifier onlyDev() {
		require(msg.sender == devWallet, "only dev");
		_;
	}
	constructor() ERC721("Honey Badger Clan", "HBCD") PaymentSplitter(addressList, shareList) {
		devWallet = msg.sender;
	}
	// //regular public sale
	// function buy(uint256 qty) external payable {
	// 	require(block.timestamp >= saleStartTime, "not live");
	// 	require(_tokenIds.current() + qty <= segments[2][1], "non dao sale out of stock");
    //     for(uint j=0; j<3; j++) {
	// 		if (_tokenIds.current()+1 > segments[j][0] && _tokenIds.current()+1 <= segments[j][1]) {
	// 			require(
	// 				qty <= segments[j][2] && tokenPrice[j] * qty == msg.value,
	// 				"Not in segment"
	// 			);
	// 			break;
	// 		}
    //     }
	// 	tbuy(qty);
	// }
	//genesis sale
	function buyGenesis(uint256 qty) external payable {
		require(block.timestamp >= saleStartTime, "not live");
		require(_tokenIds.current()+qty  <= genesis[0], "genesis sale not live");
		require(qty  <= genesis[1], "genesis qty not correct");
		require(genesis[2] * qty == msg.value, "genesis price not correct");		
		tbuy(qty);
	}
	//pioneer sale
	function buyPioneer(uint256 qty) external payable {
		require(block.timestamp >= saleStartTime, "not live");
		require(_tokenIds.current()+qty  > genesis[0] && _tokenIds.current()+qty<=pioneer[0], "pioneer sale not live");
		require(qty  <= pioneer[1], "pioneer qty <=10");
		require(pioneer[2] * qty == msg.value, "pioneer price not correct");		
		tbuy(qty);
	}
	//builder sale
	function buyBuilder(uint256 qty) external payable {
		require(block.timestamp >= saleStartTime, "not live");
		require(_tokenIds.current()+qty  > pioneer[0] && _tokenIds.current()+qty<=builder[0], "builder sale not live");
		require(qty  <= builder[1], "builder qty <=10");
		require(builder[2] * qty == msg.value, "builder price not correct");		
		tbuy(qty);
	}
	//dao sale
	function buyDao(uint256 qty) external payable {
		require(block.timestamp >= saleStartTime, "not live");
		require(_tokenIds.current()+qty  > builder[0] && _tokenIds.current()+qty<=dao[0], "dao sale not live");
		require(qty  <= builder[1], "dao qty <=10");
		require(dao[2] * qty <= msg.value, "dao price not correct");		
		tbuy(qty);
	}
	function tbuy(uint256 qty) private {
		for (uint256 i = 0; i < qty; i++) {
			_tokenIds.increment();
			_safeMint(msg.sender, _tokenIds.current());
		}
	}
	function eCommerceMint(uint256 qty, address to) external onlyOwner {
		this.adminMint(qty,to);
	}
	// admin can mint them for giveaways, airdrops etc
	function adminMint(uint256 qty, address to) external onlyOwner {
		require(qty <= 10, "no more than 10");
		require(_tokenIds.current() + qty <= maxSupply, "out of stock");
		for (uint256 i = 0; i < qty; i++) {
			_tokenIds.increment();
			_safeMint(to, _tokenIds.current());
		}
	}
	function tokensOfOwner(address _owner) external view returns (uint256[] memory) {
		uint256 tokenCount = balanceOf(_owner);
		if (tokenCount == 0) {
			return new uint256[](0);
		} else {
			uint256[] memory result = new uint256[](tokenCount);
			uint256 index;
			for (index = 0; index < tokenCount; index++) {
				result[index] = tokenOfOwnerByIndex(_owner, index);
			}
			return result;
		}
	}

	function exists(uint256 _tokenId) external view returns (bool) {
		return _exists(_tokenId);
	}

	function isApprovedOrOwner(address _spender, uint256 _tokenId) external view returns (bool) {
		return _isApprovedOrOwner(_spender, _tokenId);
	}

	function tokenURI(uint256 _tokenId) public view override returns (string memory) {
		require(_exists(_tokenId), "ERC721Metadata: URI query for nonexistent token");
		return string(abi.encodePacked(_contractBaseURI, _tokenId.toString(), ".json"));
	}

	function setBaseURI(string memory newBaseURI) external onlyDev {
		require(!locked, "locked functions");
		_contractBaseURI = newBaseURI;
	}

	function setContractURI(string memory newuri) external onlyDev {
		require(!locked, "locked functions");
		_contractURI = newuri;
	}

	function contractURI() public view returns (string memory) {
		return _contractURI;
	}

	function reclaimERC20(IERC20 erc20Token) external onlyOwner {
		erc20Token.transfer(msg.sender, erc20Token.balanceOf(address(this)));
	}

	function reclaimERC721(IERC721 erc721Token, uint256 id) external onlyOwner {
		erc721Token.safeTransferFrom(address(this), msg.sender, id);
	}

	function reclaimERC1155(
		IERC1155 erc1155Token,
		uint256 id,
		uint256 amount
	) external onlyOwner {
		erc1155Token.safeTransferFrom(address(this), msg.sender, id, amount, "");
	}

	//in unix
	function setPresaleStartTime(uint256 _presaleStartTime) external onlyOwner {
		presaleStartTime = _presaleStartTime;
	}

	//in unix
	function setSaleStartTime(uint256 _saleStartTime) external onlyOwner {
		saleStartTime = _saleStartTime;
	}

	function decreaseMaxSupply(uint256 newMaxSupply) external onlyOwner {
		require(newMaxSupply < maxSupply, "decrease only");
		maxSupply = newMaxSupply;
	}

	function decreaseMaxPresaleSupply(uint256 newMaxPresaleSupply) external onlyOwner {
		require(newMaxPresaleSupply < maxSupplyPresale, "decrease only");
		maxSupplyPresale = newMaxPresaleSupply;
	}

	// and for the eternity!
	function lockBaseURIandContractURI() external onlyDev {
		locked = true;
	}

	//if newTime is in the future, start the reward system [only owner]
	function setRewardEndingTime(uint256 _newTime) external onlyOwner {
		rewardEndingTime = _newTime;
	}

	//can claim if < maxRewardTokenID
	function setMaxRewardTokenID(uint256 _newMax) external onlyOwner {
		maxRewardTokenID = _newMax;
	}
	//after voting chage price
	function setDaoPrice(uint256 _price) external onlyOwner {
		dao[2] = _price;
	}
}