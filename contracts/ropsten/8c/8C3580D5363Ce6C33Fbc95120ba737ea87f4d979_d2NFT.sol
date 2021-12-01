// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract d2NFT is ERC721Enumerable, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIndex;

    uint256 public constant MAX_ELEMENTS = 5;
    uint256 public constant PRICE = 0.01 ether;

    string public baseTokenURI;

    address public constant devAddress = 0xE05e6350BEb055a206E0AeeA51cB82FCEb0B22fC;

    event welcomeToD2Nft(uint256 indexed id);

    constructor(string memory baseURI) ERC721("d2NFT", "COIN") {
        setBaseURI(baseURI);
    }

    modifier canBuy {
        require(totalToken() <= MAX_ELEMENTS, "SoldOut!");
        _;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

    function totalToken() public view returns (uint256) {
        return _tokenIndex.current();
    }

    function mint(uint256[] memory _tokensId, uint256 _timestamp, bytes memory _signature) public payable canBuy {

        uint256 total = totalToken();
        require(total + _tokensId.length <= MAX_ELEMENTS, "Limit reached");
        require(msg.value >= price(_tokensId.length), "Value below price");

        address wallet = _msgSender();

        address signerOwner = signatureWallet(wallet, _tokensId, _timestamp, _signature);
        require(signerOwner == owner(), "Not authorized to mint");

        for(uint8 i = 0; i < _tokensId.length; i++){
            require(rawOwnerOf(_tokensId[i]) == address(0) && _tokensId[i] > 0 && _tokensId[i] <= MAX_ELEMENTS, "Token already minted");
            _mintOne(wallet, _tokensId[i]);
        }

    }

    function signatureWallet(address wallet, uint256[] memory _tokensId, uint256 _timestamp, bytes memory _signature) public view returns (address){
        return ECDSA.recover(keccak256(abi.encode(wallet, _tokensId, _timestamp)), _signature);
    }

    function _mintOne(address _to, uint256 _tokenId) private {

        _tokenIndex.increment();
        _safeMint(_to, _tokenId);

        emit welcomeToD2Nft(_tokenId);
    }

    function price(uint256 _count) public pure returns (uint256) {
        return PRICE.mul(_count);
    }

    function walletOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokensId;
    }

    function withdrawAll() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0);
        _widthdraw(devAddress, address(this).balance);
    }

    function _widthdraw(address _address, uint256 _amount) private {
        (bool success, ) = _address.call{value: _amount}("");
        require(success, "Transfer failed.");
    }

    function getUnsoldTokens(uint256 offset, uint256 limit) external view returns (uint256[] memory){

        uint256[] memory tokens = new uint256[](limit);

        for (uint256 i = 0; i < limit; i++) {
            uint256 key = i + offset;
            if(rawOwnerOf(key) == address(0)){
                tokens[i] = key;
            }
        }

        return tokens;
    }

    function mintUnsoldTokens(uint256[] memory _tokensId) public onlyOwner {

        for (uint256 i = 0; i < _tokensId.length; i++) {
            if(rawOwnerOf(_tokensId[i]) == address(0)){
                _mintOne(owner(), _tokensId[i]);
            }
        }
    }
}