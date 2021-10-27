// SPDX-License-Identifier: MIT
pragma experimental ABIEncoderV2;
pragma solidity ^0.8.0;

import "./ERC721Namable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC1155.sol";
//import "./interfaces/IBreedManager.sol";
import "./YieldToken.sol";


contract Lions is ERC721Namable, Ownable {

    struct Lion {
        uint256 bornAt;
    }

	address public constant burn = address(0x000000000000000000000000000000000000dEaD);
	//IERC1155 public constant OPENSEA_STORE = IERC1155(0x495f947276749Ce646f68AC8c248420045cb7b5e);
	//address constant public SIGNER = address(0x900d8D106Ca27Fee14209C7a8D51cF6107be3D86);


	mapping(uint256 => Lion) public lions;
	mapping(address => uint256) public balanceOG;
	//uint256 public bebeCount;

	YieldToken public yieldToken;
	// IBreedManager breedManager;


	// Events
	// event KongIncubated (uint256 tokenId, uint256 matron, uint256 sire);
	// event KongBorn(uint256 tokenId, uint256 genes);
	// event KongAscended(uint256 tokenId, uint256 genes);

	constructor(string memory _name, string memory _symbol) ERC721Namable(_name, _symbol) {
		_setBaseURI("http://lions.youaremetaverse.com//api/lion/");
	}

	function updateURI(string memory _newURI) public onlyOwner {
		_setBaseURI(_newURI);
	}

    function mint(uint256 _id) public payable {
        _mint(msg.sender, _id);
        lions[_id] = Lion(block.timestamp);
        yieldToken.updateRewardOnMint(msg.sender, 1);
        balanceOG[msg.sender]++;
    }

	function setYieldToken(address _yield) external onlyOwner {
		yieldToken = YieldToken(_yield);
	}

	function changeNamePrice(uint256 _price) external onlyOwner {
		nameChangePrice = _price;
	}

	// function isValidKong(uint256 _id) pure internal returns(bool) {
	// 	// making sure the ID fits the opensea format:
	// 	// first 20 bytes are the maker address
	// 	// next 7 bytes are the nft ID
	// 	// last 5 bytes the value associated to the ID, here will always be equal to 1
	// 	// There will only be 1000 kongz, we can fix boundaries and remove 5 ids that dont match kongz
	// 	if (_id >> 96 != 0x000000000000000000000000a2548e7ad6cee01eeb19d49bedb359aea3d8ad1d)
	// 		return false;
	// 	if (_id & 0x000000000000000000000000000000000000000000000000000000ffffffffff != 1)
	// 		return false;
	// 	uint256 id = (_id & 0x0000000000000000000000000000000000000000ffffffffffffff0000000000) >> 40;
	// 	if (id > 1005 || id == 262 || id == 197 || id == 75 || id == 34 || id == 18 || id == 0)
	// 		return false;
	// 	return true;
	// }

	// function returnCorrectId(uint256 _id) pure internal returns(uint256) {
	// 	_id = (_id & 0x0000000000000000000000000000000000000000ffffffffffffff0000000000) >> 40;
	// 	if (_id > 262)
	// 		return _id - 5;
	// 	else if (_id > 197)
	// 		return _id - 4;
    //     else if (_id > 75)
    //         return _id - 3;
    //     else if (_id > 34)
    //         return _id - 2;
    //     else if (_id > 18)
    //         return _id - 1;
	// 	else
	// 		return _id;
	// }

	// function ascend(uint256 _tokenId, uint256 _genes, bytes calldata _sig) external {
	// 	require(isValidKong(_tokenId), "Not valid Kong");
	// 	uint256 id = returnCorrectId(_tokenId);
	// 	require(keccak256(abi.encodePacked(id, _genes)).toEthSignedMessageHash().recover(_sig) == SIGNER, "Sig not valid");
	
	// 	kongz[id] = Kong(_genes, block.timestamp);
	// 	_mint(msg.sender, id);
	// 	OPENSEA_STORE.safeTransferFrom(msg.sender, burn, _tokenId, 1, "");
	// 	yieldToken.updateRewardOnMint(msg.sender, 1);
	// 	balanceOG[msg.sender]++;
	// 	emit KongAscended(id, _genes);
	// }

	// function breed(uint256 _sire, uint256 _matron) external {
	// 	require(ownerOf(_sire) == msg.sender && ownerOf(_matron) == msg.sender);
	// 	require(breedManager.tryBreed(_sire, _matron));

	// 	yieldToken.burn(msg.sender, BREED_PRICE);
	// 	bebeCount++;
	// 	uint256 id = 1000 + bebeCount;
	// 	kongz[id] = Kong(0, block.timestamp);
	// 	_mint(msg.sender, id);
	// 	emit KongIncubated(id, _matron, _sire);
	// }

	// function evolve(uint256 _tokenId) external {
	// 	require(ownerOf(_tokenId) == msg.sender);
	// 	Kong storage kong = kongz[_tokenId];
	// 	require(kong.genes == 0);

	// 	uint256 genes = breedManager.tryEvolve(_tokenId);
	// 	kong.genes = genes;
	// 	emit KongBorn(_tokenId, genes);
	// }

	function changeName(uint256 tokenId, string memory newName) public override {
		yieldToken.burn(msg.sender, nameChangePrice);
		super.changeName(tokenId, newName);
	}

	function changeBio(uint256 tokenId, string memory _bio) public override {
		yieldToken.burn(msg.sender, BIO_CHANGE_PRICE);
		super.changeBio(tokenId, _bio);
	}

	function getReward() external {
		yieldToken.updateReward(msg.sender, address(0), 0);
		yieldToken.getReward(msg.sender);
	}

	function transferFrom(address from, address to, uint256 tokenId) public override {
		yieldToken.updateReward(from, to, tokenId);
		// if (tokenId < 1001)
		// {
			balanceOG[from]--;
			balanceOG[to]++;
		// }
		ERC721.transferFrom(from, to, tokenId);
	}

	function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public override {
		yieldToken.updateReward(from, to, tokenId);
		// if (tokenId < 1001)
		// {
		// 	balanceOG[from]--;
		// 	balanceOG[to]++;
		// }
		ERC721.safeTransferFrom(from, to, tokenId, _data);
	}

	// function onERC1155Received(address _operator, address _from, uint256 _id, uint256 _value, bytes calldata _data) external returns(bytes4) {
	// 	require(msg.sender == address(OPENSEA_STORE), "WrappedKongz: not opensea asset");
	// 	return Kongz.onERC1155Received.selector;
	// }
}