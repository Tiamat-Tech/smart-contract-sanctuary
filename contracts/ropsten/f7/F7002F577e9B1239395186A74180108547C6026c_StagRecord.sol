// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts/token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/Pausable.sol";


import "@rarible/royalties/contracts/impl/RoyaltiesV2Impl.sol";
import "@rarible/royalties/contracts/LibPart.sol";
import "@rarible/royalties/contracts/LibRoyaltiesV2.sol";

contract StagRecord is ERC721, PaymentSplitter, Ownable, Pausable, RoyaltiesV2Impl {

    using SafeMath for uint256;
    using Counters for Counters.Counter;

    uint256 private _itemPrice;
    uint96 private _royaltyPercentage;
    string private _api_entry;
    address payable private powner;
    bool public saleIsActive = false;

    mapping(uint256 => uint256) private _totalSupply;

    Counters.Counter private _tokenIdCounter;

    uint256[] private _team_shares = [25,25,25,25];

    address[] private _team = [
	    0x93a1168191b0Fc3c3FF5A776B0A8B8Fd129feEb4,  //Calum Share of 25%
	    0x14C73D2749dC00D06EC491bdAF2c2809dD48dabE,  //Ruaridh Share of 25%
	    0x09A4d294c49D1c17bf304D57DCe453DdfcA31539,  // Uisdean Share of 25%
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266   // Business & Royalties
    ];

    constructor() PaymentSplitter(_team, _team_shares) ERC721("StagRecord", "STAG") {
        _api_entry = "https://stag-records-api.azurewebsites.net/MetaData/Record/";
        setRoyaltyPercentage(5000);
        setItemPrice(60000000000000000);
    }

    function flipSaleState() public onlyOwner {
        saleIsActive = !saleIsActive;
    }

    function _baseURI() internal view override returns (string memory) {
        return _api_entry;
    }

    function setBaseURI (string memory _uri) public onlyOwner  {
        _api_entry = _uri;
    }

    function getOneById(uint256 _id) public payable {
        require(saleIsActive, "Sale must be active to mint");
        require(msg.value == getItemPrice(), "insufficient ETH");
        master_mint(_id, msg.sender);
    }

    // function mint(address _to, uint256 _id) public onlyOwner {
    //     master_mint(_id, _to);
    // }

    function totalSupply() public view virtual returns (uint256) {
        return _tokenIdCounter.current();
    }

    function getTotalSupply(uint256 id) public view virtual returns (uint256) {
        return _totalSupply[id];
    }

    function getItemPrice() public view returns (uint256) {
        return _itemPrice;
    }

    function setItemPrice(uint256 _price) public onlyOwner {
        _itemPrice = _price;
    }

    function master_mint(uint256 _id, address _to) private {
            _safeMint(_to, _id);
            _tokenIdCounter.increment();
            setRoyalties(_id, payable(_team[3]), _royaltyPercentage);
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
       return string(abi.encodePacked(super.tokenURI(tokenId)));
    }

    function destroyContract() public onlyOwner {
        selfdestruct(powner);
    }

    function setRoyalties(uint _tokenId, address payable _royaltiesReceipientAddress, uint96 _percentageBasisPoints) public onlyOwner {
        LibPart.Part[] memory _royalties = new LibPart.Part[](1);
        _royalties[0].value = _percentageBasisPoints;
        _royalties[0].account = _royaltiesReceipientAddress;
        _saveRoyalties(_tokenId, _royalties);
    }
    
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721) returns (bool) {
        if(interfaceId == LibRoyaltiesV2._INTERFACE_ID_ROYALTIES) {
            return true;
        }
        return super.supportsInterface(interfaceId);
    }

    function setRoyaltyPercentage(uint256 _val) public onlyOwner {
        _royaltyPercentage = uint96(_val);
    }

    function getRoyaltyPercentage() public view returns (uint96) {
        return _royaltyPercentage;
    }
}