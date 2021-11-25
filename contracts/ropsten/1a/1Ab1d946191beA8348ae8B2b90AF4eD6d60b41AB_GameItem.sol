// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract GameItem is ERC721URIStorage, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address gameContract;
    
    constructor() ERC721("GameItem", "ITM") {}


    function setAddressGame(address _game) public onlyOwner{
        gameContract = _game;
    }
    
    function awardItem(address player, string memory tokenURI)
        public
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(player, newItemId);
        _setTokenURI(newItemId, tokenURI);
        setApprovalForAll(gameContract,true);
        return newItemId;
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }

}


contract Game is ChainlinkClient {
    using Chainlink for Chainlink.Request;
  
    uint256 public volume;
    string public url;
    address private oracle;
    bytes32 private jobId;
    uint256 private fee;
    string private api_token;
    
    GameItem public nft;
    
    struct WaitPlayer {
        address player2;
        uint256 nftPlayer2;
        uint256 nftPlayer1;
    }
    
     struct LoadGame {
        address player2;
        uint256 nftPlayer2;
        address player1;
        uint256 nftPlayer1;
    }
    
    mapping(address => WaitPlayer) public waitList;
    mapping(bytes32 => LoadGame) public games;
    
    /**
     * Network: Kovan
     * Oracle: 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8 (Chainlink Devrel   
     * Node)
     * Job ID: d5270d1c311941d0b08bead21fea7747
     * Fee: 0.1 LINK
     */
    constructor(GameItem _nft) {
        setPublicChainlinkToken();
        oracle = 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8;
        jobId = "d5270d1c311941d0b08bead21fea7747";
        fee = 0.1 * 10 ** 18; // (Varies by network and job)
        api_token="1d33b6a732d7dce8b2beadf5fe44c3d380d9bc4af15d24dc9a77bbe6aad2d3cc";
        nft = _nft;
    }
    
    function startGame(address player2, uint256 nftPlayer2, uint256 nftPlayer1) public{
        //require(nft.ownerOf(nftPlayer1) == msg.sender);
        //nft.setApprovalForAll(address(this),true);
        //nft.approve(address(this),nftPlayer1);
        nft.transferFrom(msg.sender,address(this), nftPlayer1);
        if(waitList[player2].player2 != address(0x0)){
            require(waitList[player2].player2 == msg.sender &&  waitList[player2].nftPlayer2 == nftPlayer1 && waitList[player2].nftPlayer1 == nftPlayer2 );
            requestVolumeData(LoadGame(player2,nftPlayer2,msg.sender,nftPlayer1));
            delete waitList[player2];
        }
        else{
            waitList[msg.sender] = WaitPlayer(player2,nftPlayer2,nftPlayer1);
        }
    }

    
 
function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }
 
 
        function concatenate(string memory s1, string memory  s2, string memory s3, string memory s4, string memory s5, string memory s6) public pure returns (string memory) {
        return string(abi.encodePacked(s1, s2,s3,s4,s5,s6));
    }
    
    
    
    
    
    function requestVolumeData(LoadGame memory contentGame) internal 
    {
        Chainlink.Request memory request = buildChainlinkRequest(jobId, address(this), this.fulfill.selector);
        
        // Set the URL to perform the GET request on
        request.add("get",  concatenate("https://f4064b54cdd2.ngrok.io/api/game?player1=",uint2str(contentGame.nftPlayer1),"&player2=",uint2str(contentGame.nftPlayer2),"&api_token=", api_token));
        
        // Set the path to find the desired data in the API response, where the response format is:
        // {"RAW":
        //   {"ETH":
        //    {"USD":
        //     {
        //      "VOLUME24HOUR": xxx.xxx,
        //     }
        //    }
        //   }
        //  }
        request.add("path", "result");
    
        
        // Sends the request
        games[sendChainlinkRequestTo(oracle, request, fee)] = contentGame;
    }
    
    /**
     * Receive the response in the form of uint256
     */ 
    function fulfill(bytes32 _requestId, uint256 _volume) public recordChainlinkFulfillment(_requestId)
    {
        LoadGame memory state = games[_requestId];
        if(_volume == 1){
             nft.transferFrom(address(this),state.player1, state.nftPlayer1);
             nft.transferFrom(address(this),state.player1, state.nftPlayer2);
        }
        else{
         nft.transferFrom(address(this),state.player2, state.nftPlayer1);
             nft.transferFrom(address(this),state.player2, state.nftPlayer2);
        }
        
        volume = _volume;
    }

    // function withdrawLink() external {} - Implement a withdraw function to avoid locking your LINK in the contract
}