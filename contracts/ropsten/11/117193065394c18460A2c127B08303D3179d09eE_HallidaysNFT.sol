// SPDX-License-Identifier: MIT
pragma solidity 0.8.6;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract HallidaysNFT is
    ERC721,
    ERC721Enumerable,
    Ownable
{
    using SafeMath for uint256;
    using Counters for Counters.Counter;
    using EnumerableSet for EnumerableSet.UintSet;

    Counters.Counter private _tokenIdCounter;
    mapping(uint256 => string) _tokenIdToTokenURI;
    uint public InfiniteSounds = 1;
    uint public PureFrequency = 101;
    uint public HigherReverb = 201;
    uint256 constant feePercentage = 100;
    address constant ADDRESS_NULL = address(0);

    struct RoyaltyInfo {
        address recipient;
        uint256 feeAmount;
    }
    RoyaltyInfo[] private _royalties;

    constructor(
        string memory _name,
        string memory _symbol,
        address[] memory recipient,
        uint256[] memory fee
    ) ERC721(_name, _symbol) {
        _tokenIdCounter.increment();

        for (uint256 i = 0; i < recipient.length; i++) {
            _royalties.push(RoyaltyInfo(recipient[i], fee[i]));
        }
    }
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            'ERC721Metadata: URI query for nonexistent token'
        );
        return _tokenIdToTokenURI[tokenId];
    }

    //sub_nft1 mint
    function subNFT1() public payable returns (uint256) {
        require(InfiniteSounds < 101, "InfiniteSounds all sold out.");
        require(msg.value==0.01 ether, "Please check the price.");
        uint256 _tId = InfiniteSounds;
        InfiniteSounds += 1;
        _tokenIdToTokenURI[_tId] = "http://localhost:8080/meta/InfiniteSounds";
        sale();
        _safeMint(msg.sender, _tId);
        return _tId;
    }

    //sub_nft2 mint
    function subNFT2() public payable returns (uint256) {
        require(PureFrequency < 201, "PureFrequency all sold out.");
        require(msg.value==0.01 ether, "Please check the price.");
        uint256 _tId = PureFrequency;
        PureFrequency += 1;
        _tokenIdToTokenURI[_tId] = "http://localhost:8080/meta/PureFrequency";
        sale();
        _safeMint(msg.sender, _tId);
        return _tId;
    }

    //sub_nft3 mint
    function subNFT3() public payable returns (uint256) {
        require(HigherReverb < 301, "HigherReverb all sold out.");
        require(msg.value==0.01 ether, "Please check the price.");
        uint256 _tId = HigherReverb;
        HigherReverb += 1;
        _tokenIdToTokenURI[_tId] = "http://localhost:8080/meta/HigherReverb";
        sale();
        _safeMint(msg.sender, _tId);
        return _tId;
    }

    function sale() internal {
        uint256 sellAmount = msg.value;

        for (uint256 i = 0; i < _royalties.length; i++) {
            uint256 recipientFee = msg.value.mul(_royalties[i].feeAmount).div(feePercentage); // 전달받은 금액에서 로열티 금액을 환산
            sellAmount.sub(recipientFee); // owner(판매자) 가 가져갈 돈에서 환산된 로열티 금액을 제외한다.
            payable(_royalties[i].recipient).transfer(recipientFee); // 로열티 지급
        }

        payable(owner()).transfer(sellAmount); // owner(판매자) 에게 판매금 지급
    }

    // nomal mint
    function safeMint(string memory _tokenURI) public onlyOwner returns(uint256){
        uint256 _tId = 300 + _tokenIdCounter.current();
        _tokenIdCounter.increment();

        _tokenIdToTokenURI[_tId] = _tokenURI;
        _safeMint(msg.sender, _tId);
        return _tId;
    }


    function burn(uint256 tokenId) public onlyOwner {
        require(
            _exists(tokenId),
            'ERC721Metadata: URI query for nonexistent token'
        );
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            'ERC721Burnable: caller is not owner nor approved'
        );

        delete _tokenIdToTokenURI[tokenId];
        _burn(tokenId);
    }
}