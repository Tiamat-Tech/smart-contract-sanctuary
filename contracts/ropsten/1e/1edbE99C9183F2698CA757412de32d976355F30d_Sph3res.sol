//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

/// @creator: sph3res.eth
/// @author: mitch0z
/// gm fren
/// gm pak

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract Sph3res is ERC721, Ownable{

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    uint256 private spheresPerClaim = 2; 
    uint256 private maxOriginClaimers = 21; 
    uint256 private maxSupplyOrigins = 42; 
    uint256 private maxSupply = 1024; 
    uint256 public price = 50000000000000000; 

    string private baseURI;

    uint256 private royaltyBps;
    address payable private royaltyRecipient;
    
    mapping (address => uint256) private sphereCount; 
    mapping (uint256 => address) public sphereToOwner;

    mapping (uint256 => bool) public isSphereFrozen;
    mapping (uint256 => bool) public isOrigin; 

    mapping (uint256 => string) private sphereName; 

    mapping (address => uint) private originClaimers; 
    mapping (address => uint) private claimedOrigins; 

    mapping (address => bool) private admins;

    event freezeSphereEvent(uint256 _tokenid);
    event originClaimersSet(address[]);
    event sphereSpawned(address _owner);
    
    event AdminSet(address _admin);
    event AdminRemoved(address _admin);

    event priceUpdated(uint _price);
    event royaltiesUpdated(address payable _recipient,uint256 bps);
    event nameChanged(uint256 _tokenid,string _name);

    constructor() ERC721("the sph3res","SPH3RES"){
        addAdmin(msg.sender);
        
        royaltyRecipient = payable(msg.sender);
        royaltyBps = 500;
    }
    
    modifier isAdmin
    {
        require(admins[msg.sender] == true, "Sender is not admin");
        _;
    }

    modifier onlyUnclaimedHolder {
        require(originClaimers[msg.sender] >= spheresPerClaim, "Must have at least one possible claim!"); 
        require(claimedOrigins[msg.sender] <= originClaimers[msg.sender], "You cannot claim more than allowed!");
        _;
    }

    modifier supplyNotReached {
         require(totalSupply() < maxSupply, "Maximum supply has been reached!");
        _;
    }

    function setOriginClaimers(address[] memory _originclaimers) public isAdmin onlyOwner
    {
        
        for(uint i = 0;i<_originclaimers.length;i++)
        {
            if(originClaimers[_originclaimers[i]]>=spheresPerClaim)
            {
                originClaimers[_originclaimers[i]] += spheresPerClaim;
            }
            else
            {
                originClaimers[_originclaimers[i]] = spheresPerClaim;
            }
        }

        emit originClaimersSet( _originclaimers);

    }

    function mintOrigins(string calldata _name) external onlyUnclaimedHolder {
        require(_tokenIdCounter.current() <= maxSupplyOrigins, "All origin sph3res have been minted!");

        for(uint i = 0;i<originClaimers[msg.sender];i++)
        {
            spawnNewSphere(msg.sender,true, _name);
        }
    }
    
    function spawnNewSphere(address to, bool _isOrigin, string memory _name) private supplyNotReached {

        uint256 lasttokenId = _tokenIdCounter.current();  
        uint256 newtokenId = lasttokenId + 1;

        require(!_exists(newtokenId),"This tokenid already exists!");

        isSphereFrozen[newtokenId] = false;
        isOrigin[newtokenId]= _isOrigin;

        sphereName[newtokenId] = _name;

        sphereToOwner[newtokenId] = to;

        _tokenIdCounter.increment();
        sphereCount[to]++;   
        
        _safeMint(to, newtokenId);

        emit sphereSpawned(to);
    }

    function shareSphere(address _to, uint _tokenid) public payable supplyNotReached{
        require(price <= msg.value, "Ether value too low!");        
        require(balanceOf(msg.sender) > 0, "No existing sph3re found in sender wallet!");
        require(!isSphereFrozen[_tokenid], "This sph3re is frozen and can't be shared anymore!");
        require(balanceOf(_to) == 0, "You can't share a sph3re with somebody who already has one.");        
        require(msg.sender != _to, "Sir... You cannot share a sph3re with yourself!");
        

        string memory oldname = getName(_tokenid);
        spawnNewSphere(_to, false, oldname);
        freezeSphere(_tokenid);
    }

    function freezeSphere(uint _tokenid) private{
        require(!isSphereFrozen[_tokenid], "Sph3re is already frozen and can't be frozen again!");

        isSphereFrozen[_tokenid] = true;
        emit freezeSphereEvent(_tokenid);
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_tokenId < _tokenIdCounter.current(), "ERC721Metadata: URI query for nonexistent token");
        
        string memory base = _baseURI();

        if (bytes(base).length == 0) {
            return "";
        }
        else{
            return string(abi.encodePacked(base, Strings.toString(_tokenId)));
        }

    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function getBaseURI() public view returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory _uri) public isAdmin {
        baseURI = _uri;
    }

    function updatePrice(uint256 _price) public isAdmin {
        price = _price;
        emit priceUpdated(_price);
    }

    function updateRoyalties(address payable _recipient, uint256 _bps) external isAdmin {
        royaltyRecipient = _recipient;
        royaltyBps = _bps;

        emit royaltiesUpdated(_recipient, _bps);
    }

    function royaltyInfo(uint256, uint256 value) external view returns (address, uint256) {
        return (royaltyRecipient, value*royaltyBps/10000);
    }
   
    function totalSupply() public view returns (uint256) {
        return _tokenIdCounter.current();
    }

    function getCurrentTokenId() public view returns(uint)
    {
        return _tokenIdCounter.current();
    }
    
    function getIsSphereFrozen(uint _tokenid) public view returns(bool){
        return isSphereFrozen[_tokenid];
    }

    function getIsOrigin(uint _tokenid) public view returns(bool)
    {
        return isOrigin[_tokenid];
    }

    function getName(uint _tokenid) public view returns(string memory)
    {
        return sphereName[_tokenid];
    }

    function setName(uint _tokenid, string memory _name) public isAdmin
    {
       sphereName[_tokenid] = _name;
       emit nameChanged(_tokenid, _name);
    }

    function addAdmin(address _admin) public onlyOwner
    {
        admins[_admin] = true;
        emit AdminSet(_admin);
    }

    function removeAdmin(address _admin) public isAdmin
    {
        admins[_admin] = false;
        emit AdminRemoved(_admin);
    }


}