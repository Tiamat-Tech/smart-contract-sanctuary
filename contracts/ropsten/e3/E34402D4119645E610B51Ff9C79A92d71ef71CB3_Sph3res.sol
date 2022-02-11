//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

///////////////////////
//                   //
//                   //
//    the sph3res    //
//                   //
//                   //
///////////////////////
/// @creator: sph3res.eth
/// @author: mitch0z
/// gm fren
/// gm pak

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";


contract Sph3res is ERC721, Ownable, ReentrancyGuard{

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter;

    address constant sph3res_ = 0xbD9c96D8570639f4B2BCb8cA55534E0031C0fD11; //UPDATE TODO
    address constant ashToken = 0x101848D5C5bBca18E6b4431eEdF6B95E9ADF82FA; //UPDATE TODO

    uint256 constant private spheresPerClaim = 2; 
    uint256 constant private maxOriginClaimers = 21; 
    uint256 constant private maxSupplyOrigins = 42; 
    uint256 constant private maxSupply = 1024; 
    uint256 public price = 50000000000000000; 
    uint256 public ashPrice = 5000000000000000000;   
    bool public sharingAllowed = false;  
    string private baseURI;    

    uint256 private royaltyBps;
    address payable private royaltyRecipient;
    
    mapping (address => uint256) private sphereCount; 
    mapping (uint256 => string) private tokenURIs;

    mapping (uint256 => bool) private isSphereFrozen;
    mapping (uint256 => bool) private isOrigin; 
    mapping (address => bool) private receivedSphere;

    mapping (uint256 => string) private sphereName; 
    mapping (string => uint256) private spheresPerName;

    mapping (address => uint256) private originClaimers; 
    mapping (address => uint256) private claimedOrigins; 

    mapping(address => mapping (address => uint256)) allowed;

    mapping (address => bool) private admins;

    event sphereFrozen(uint256 _tokenid);
    event originClaimersSet(address[]);
    event originsMinted(address _owner, string _name);
    event sphereSpawned(address _owner, string _name);
    
    event AdminSet(address _admin);
    event AdminRemoved(address _admin);

    event priceUpdated(uint _price);
    event ashPriceUpdated(uint _price);
    event royaltiesUpdated(address payable _recipient,uint256 bps);
    event nameChanged(uint256 _tokenid,string _name);

    constructor() ERC721("the sph3res","SPH3RES"){
        addAdmin(msg.sender);
        
        royaltyRecipient = payable(sph3res_);
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

    function mintOrigins(string calldata _name) external onlyUnclaimedHolder supplyNotReached{
        require(_tokenIdCounter.current() <= maxSupplyOrigins, "All origin sph3res have been minted!");

        for(uint i = 0;i<originClaimers[msg.sender];i++)
        {  
            spawnNewSphere(msg.sender,true, _name);
        }

        originClaimers[msg.sender] = 0;

        emit originsMinted(msg.sender,_name);
    }
    
    function spawnNewSphere(address _to, bool _isOrigin, string memory _name) private supplyNotReached {

        uint256 newtokenId =  _tokenIdCounter.current() + 1;

        require(!_exists(newtokenId),"This tokenid already exists!");

        isSphereFrozen[newtokenId] = false;
        isOrigin[newtokenId]= _isOrigin;

        sphereName[newtokenId] = _name;
        spheresPerName[_name]++;

        sphereCount[_to]++; 

        _tokenIdCounter.increment();

        receivedSphere[_to] = true;
        
        _safeMint(_to, newtokenId);

        emit sphereSpawned(_to, _name);
    }

    function shareSphere(address _to, uint _tokenid) public payable supplyNotReached{
        require(ownerOf(_tokenid) == msg.sender, "This sph3re does not belong to you.");
        require(price <= msg.value, "Price too low!");        
        require(!receivedSphere[_to],"This account already received a shared or origin sph3re.");
        require(!isSphereFrozen[_tokenid], "This sph3re is frozen and can't be shared anymore!");
        require(msg.sender != _to, "You cannot share a sph3re with yourself!");
        require(sharingAllowed, "Sharing is not allowed yet!");

        (bool sent, /* bytes memory data */) = payable(sph3res_).call{value: msg.value}("");
        require(sent, "Failed to transfer ETH!");

        string memory oldname = getName(_tokenid);
        spawnNewSphere(_to, false, oldname);
        freezeSphere(_tokenid);
    }

    function shareSphereWithAsh(address _to, uint _tokenid) public supplyNotReached{
        require(ownerOf(_tokenid) == msg.sender, "This sph3re does not belong to you.");             
        require(!receivedSphere[_to],"This account already received a shared or origin sph3re.");
        require(!isSphereFrozen[_tokenid], "This sph3re is frozen and can't be shared anymore!");
        require(msg.sender != _to, "You cannot share a sph3re with yourself!");
        require(sharingAllowed, "Sharing is not allowed yet!");

        IERC20 ash = IERC20(ashToken); 
        uint256 userBalance = ash.balanceOf(msg.sender);
        require(userBalance >= ashPrice, "Not enough ASH in wallet!");
               
        require(ash.transferFrom(msg.sender,sph3res_,ashPrice),"Unable to transfer enough ASH! Check token allowance.");
        
        string memory oldname = getName(_tokenid);
        spawnNewSphere(_to, false, oldname);
        freezeSphere(_tokenid);
    }

    function freezeSphere(uint _tokenid) private{
        isSphereFrozen[_tokenid] = true;
        emit sphereFrozen(_tokenid);
    }

    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_tokenId <= _tokenIdCounter.current(), "ERC721Metadata: URI query for nonexistent token");
        require(_tokenId > 0, "ERC721Metadata: URI query for nonexistent token");
        
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

    function updateAshPrice(uint256 _price) public isAdmin {
        ashPrice = _price;
        emit ashPriceUpdated(_price);
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

    function getSpheresPerName(string memory _name) public view returns(uint256)
    {
        return spheresPerName[_name];
    }

    function getOriginClaims(address _address) public view returns(uint256)
    {
        return originClaimers[_address];
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
    
    function allowSharing(bool _sharingAllowed) public isAdmin
    {
       sharingAllowed = _sharingAllowed;
    }


}