// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./ERC721URIStorage.sol";
import "./Counters.sol";
import "./Ownable.sol";

contract NFT is ERC721URIStorage,Ownable{

    using Counters for Counters.Counter;

    Counters.Counter private _tokenId;
    Counters.Counter private _whitelisteruserCount;
    Counters.Counter private _nonwhitelisteruserCount;


    constructor(string memory _name, string memory _symbol) ERC721(_name,_symbol){}

    modifier onlyWhitlisters(){
        require(IsAlreadyInWhitelist[msg.sender] == true,'User is not in the whitelist');
        _;
    }


    // variable to keep track of users number
    using Counters for Counters.Counter;
    Counters.Counter private whitelistuserId;
    
    mapping(address => bool) public IsAlreadyInWhitelist;


    function addWhitelistUsers(address _address) external onlyOwner{
        require(whitelistuserId.current() < 5,'more user can not be added');
        require(IsAlreadyInWhitelist[_address] == false,'user is already in the whitelist');
        whitelistuserId.increment();
        IsAlreadyInWhitelist[_address] = true;
    }

    function generate(string memory _tokenUrl) private returns(uint256){
            _tokenId.increment();
            uint256 newtokenId = _tokenId.current();
            _mint(msg.sender,newtokenId);
            _setTokenURI(newtokenId,_tokenUrl);
            return newtokenId;
    }


    // function to mint nft for public users
    function createNFT(string memory _tokenUrl) public returns(uint256){
            if(IsAlreadyInWhitelist[msg.sender] && _whitelisteruserCount.current() < 5){
                _whitelisteruserCount.increment();
                return generate(_tokenUrl);

            }

             else if(!IsAlreadyInWhitelist[msg.sender] && _nonwhitelisteruserCount.current() < 10){
                _nonwhitelisteruserCount.increment();
                return generate(_tokenUrl);
            }

            else{
                revert("Token can not be generated");
            }
        }

    function getdatawhite() public view returns(uint){
        return _whitelisteruserCount.current();
    }


    function getdatanonwhite() public view returns(uint){
        return _nonwhitelisteruserCount.current();
    }

    function getdata() public view returns(uint){
        return _tokenId.current();
    }
    
}