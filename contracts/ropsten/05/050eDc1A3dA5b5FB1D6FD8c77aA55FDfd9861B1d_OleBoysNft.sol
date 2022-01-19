// Contract based on https://docs.openzeppelin.com/contracts/4.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract OleBoysNft is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    //enum palette {grayscale, twocolor, fullcolor}
    // enum scale {icon, small, medium, large}

    constructor() ERC721("OleBoysNft", "OLEBOYS") {}








    function mintNFT(
        address _recipient,
        string memory _tokenURI,
        string memory _code
    ) public {
        // Increment the number of NFTs minted.
        //_tokenIds.increment();

        // Set the latest Id for the NFT minted here.
      //  uint256 newItemId = _tokenIds.current();

        // Associate the address of the NFT owner with the id of the NFT
       

        uint256 _isAllowedToMintTokenId = isAllowedToMint(_code);

        if (_isAllowedToMintTokenId > 0){
            _setTokenURI(_isAllowedToMintTokenId, _tokenURI);
            _mint(_recipient, _isAllowedToMintTokenId);
        }
        
    }

    function isAllowedToMint(string memory _code)
        private
        pure
        returns (uint256 _tokenId)
    {
        bool _allowed = false;
        if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("61eeca7f1c89834c8cf7032bc7b3779607a0ddfe97a20ad87e7344eb4aca8819"))) {
            _tokenId == 1000;
            _allowed = true; //////////////////
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("b79d2558bf32d9c408e387d2476aa9622e4e76ea445c99a1de28337c1180e352"))) {
            _tokenId == 1; //Alpha of Alphas
            _allowed = true;
        } else if (keccak256(abi.encodePacked(_code)) == 
            keccak256(abi.encodePacked("26c4d484329ec3fa272ee1d4dcc481a23a83aea2dfd8a2363bab7c5c1838751e"))) {
            _tokenId == 2; //Master Chartographer
            _allowed = true;
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("c5cf82dc8edb554b2ec9022d9910ae73642d4b217694cd1da7923dbe1d570c71"))) {
            _tokenId == 3; //Master of Memes
            _allowed = true;
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("29ec75c27634dbdd49d6fa5625af7c2e0278e49718debb6b1e65c4227732f061"))) {
            _tokenId == 4; //Nicest User
            _allowed = true;
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("74e31961dcfa563e45cad940617e1eb8dc75ff59e4e31e424eed3021f0ad3416"))
        ) {
            _tokenId == 5; //Biggest Downfall
            _allowed = true;
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("1ac1b1472f2c5e0fe639540ade5ec3fdddd607ea8d4e8326e394dd32a0081b8c"))
        ) {
            _tokenId == 6; //Most Improved
            _allowed = true;
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("05aac71e9306c9dc76ffeabda2cda3d58952149c68d1b89123f0ae3f9fb3f823"))
        ) {
            _tokenId == 7; //Most Cucked
            _allowed = true;
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("9785f0d5ee691270a561c8a0080551291a061f9848a81bff3878c0ca93b07985"))
        ) {
            _tokenId == 8; //Most Signma
            _allowed = true;
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("e51754c6e18caa9193f48160dd444c1a77322dc4acbadc94421ac9ca47d917bd"))
        ) {
            _tokenId == 9; //Big Dawg
            _allowed = true;
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("4eef20fad75c9eb2ae9de5f40d93c89f52d891f0c8edff84259735d2ee958ba8"))
        ) {
            _tokenId == 10; //Best Foreigner
            _allowed = true;
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("55bd0f8f5b12717bf2baa05e44a02248ab9b9cb5706aec9f25fab05a3d31a0c4"))
        ) {
            _tokenId == 11; //Best Death
            _allowed = true;
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("784dc71db28cea717b0784df2ddddace292d253bec6c87db7e640be86678fb35"))
        ) {
            _tokenId == 12; //Best Ted Talk
            _allowed = true;
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("0745012b9246eaa4563e324fc7ae92c2b6ad99a249c7a4a642ff120741a68488"))
        ) {
            _tokenId == 13; //Most Situationally Aware
            _allowed = true;
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("391b173ee4fa3f06812ac1bde3edc1110f77cd0db6981d23e463f07718cb79ad"))
        ) {
            _tokenId == 14;  //Most Situationally Unaware
            _allowed = true;
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("691b85052ce0e81ef65bb37be4b3309837592658237d9a1360891f0966c12ec0"))
        ) {
            _tokenId == 15; //Monlogue Terrorist
            _allowed = true;
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("3bbabfa4889169b55e77a1008cb7eb0d6066322e2393d45f6a099583d2cbac53"))
        ) {
            _tokenId == 16; //Most likely end up homeless
            _allowed = true;
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("f72d6a47a691b6823be42c844209b9b41fc5a4d1cd5100e1728d8a2ec16347c4"))
        ) {
            _tokenId == 17; //Most likely to end up internet famous
            _allowed = true;
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("22a9dc26e94cda6bb1e36435b069974631f7a868923f7d3d0fbd1f15a3094d37"))
        ) {
            _tokenId == 18; //Most likely to hit 9 figures
            _allowed = true;
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("e7c95ca917ccdbced65f69ee70eac9083795f375e1571654d1bd86e216d03a33"))
        ) {
            _tokenId == 19; //Most likely to be arrested for discord activities
            _allowed = true;
        } else if (
            keccak256(abi.encodePacked(_code)) ==
            keccak256(abi.encodePacked("0d562d4182b9e634f3c8dbd06d3152a31299a00c44e84e1be3ba6038b03e97a6"))
        ) {
            _tokenId == 20; //Best Boomer
            _allowed = true;
        } else {
            _allowed = false;
        }

        if (_allowed) {return _tokenId;}
        else if (!_allowed) {return 0;}

    }
}