// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./ERC721Enum.sol";

contract dunksPrototype is ERC721Enum, Ownable, PaymentSplitter, Pausable,  ReentrancyGuard {

	using Strings for uint256;
	string public baseURI;
	uint256 public cost = 0.01 ether;
	uint256 public maxSupply = 32;
	uint256 public maxMint = 3;
	bool public status = false;

	address[] private addressList = [
	0x419f080ecb21301f93713FF984a00Ca01Dba79F1,
	0x21fB89858920a3D293ab1c2F9C6fE7919FbF1698,
    0x6236bCC38ba5E6698c37E9993a228422ABEDb872
    ];
	uint[] private shareList = [30, 30, 30];	

	constructor(string memory baseURI) ERC721S("dunksPrototype", "DPunkP") PaymentSplitter( addressList, shareList){
	    setBaseURI(baseURI);
	}

	function _baseURI() internal view virtual returns (string memory) {
	    return baseURI;
	}

	function mint(uint256 _mintAmount) public payable nonReentrant{
		uint256 s = totalSupply();
		//require(status, "Contract Not Enabled" );
		require(_mintAmount > 0, "Cant mint 0" );
		require(_mintAmount <= maxMint, "Cant mint more then maxmint" );
		require(s + _mintAmount <= maxSupply, "Cant go over supply" );
		require(msg.value >= cost * _mintAmount);
		for (uint256 i = 0; i < _mintAmount; ++i) {
			_safeMint(msg.sender, s + i, "");
		}
		delete s;
	}

	function gift(uint[] calldata quantity, address[] calldata recipient) external onlyOwner{
		require(quantity.length == recipient.length, "Provide quantities and recipients" );
		uint totalQuantity = 0;
		uint256 s = totalSupply();
		for(uint i = 0; i < quantity.length; ++i){
			totalQuantity += quantity[i];
		}
		require( s + totalQuantity <= maxSupply, "Too many" );
		delete totalQuantity;
		for(uint i = 0; i < recipient.length; ++i){
			for(uint j = 0; j < quantity[i]; ++j){
			_safeMint( recipient[i], s++, "" );
			}
		}
		delete s;	
	}
	
	function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
	    require(_exists(tokenId), "ERC721Metadata: Nonexistent token");
	    string memory currentBaseURI = _baseURI();
	    return bytes(currentBaseURI).length > 0	? string(abi.encodePacked(currentBaseURI, tokenId.toString())) : "";
	}

	function setCost(uint256 _newCost) public onlyOwner {
	    cost = _newCost;
	}
	function setMaxMintAmount(uint256 _newMaxMintAmount) public onlyOwner {
	    maxMint = _newMaxMintAmount;
	}
	function setmaxSupply(uint256 _newMaxSupply) public onlyOwner {
	    maxSupply = _newMaxSupply;
	}
	function setBaseURI(string memory _newBaseURI) public onlyOwner {
	    baseURI = _newBaseURI;
	}
	function setSaleStatus(bool _status) public onlyOwner {
	    status = _status;
	}
	function withdraw() public payable onlyOwner {
	(bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
	require(success);
	}
	function withdrawSplit() public onlyOwner {
        for (uint256 sh = 0; sh < addressList.length; sh++) {
            address payable wallet = payable(addressList[sh]);
            release(wallet);
        }
    }
}