//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;
import "./Ownable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract myNFT is Ownable, Initializable{

    using CountersUpgradeable for CountersUpgradeable.Counter;
    using StringsUpgradeable for uint256;

    string private _name;
    string private _symbol;

    CountersUpgradeable.Counter private _tokenID;

    mapping(uint256 => string) private _tokenURIs;
    string internal baseURI;

    mapping(uint256 => address) private _owners;

    mapping(address => uint256) private _balances;

    mapping(uint256 => address) _tokenApprovals;

    function initialize(string memory Name,string memory Symbol) public initializer {
        _name = Name;
        _symbol = Symbol;
        init(msg.sender);
    }

    function name() public view returns(string memory){
        return _name;
    }

    function symbol() public view returns(string memory){
        return _symbol;
    }

  function balanceOf(address owner) public view  returns (uint256) {
        require(owner != address(0), "Balance query for the zero address");
        return _balances[owner];
    }

/*Sets TokenURI */
    function _setTokenURI(uint256 tokenID, string memory toknURI) internal {
        require(_exists(tokenID), "Can not add URI to non existent token");

        _tokenURIs[tokenID] = toknURI; 
    }
/*Returns Base URI */
    function _baseURI() internal view returns(string memory){
        return baseURI;
    }
/*this function setBaseURI  only owner can change the base URI*/
    function setBaseURI(string memory base) public onlyOwner{
        baseURI = base;
    }

    function tokenURI(uint256 tokenID) public view returns(string memory){
        require(_exists(tokenID)," Query for non existent token");

        string memory _tokenURI = _tokenURIs[tokenID];
        string memory base = _baseURI();


        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return bytes(base).length>0 ? string(abi.encodePacked(base, tokenID.toString())) : "" ;
    }

/**Mints single token */
    function mint(address to, string memory uri) public onlyOwner {
        require(to != address(0), "Cannot mint to address(0)");
        
        _tokenID.increment();
        uint256 tokenID = _tokenID.current();
        _mint(to, tokenID);
        _setTokenURI(tokenID, uri);
    }

    function _exists(uint256 tokenID) internal view returns(bool){
        return _owners[tokenID] != address(0);
    }

/**Mint tokens in Batch with giving URI as an array */
    function mintBatch(address to, string[] memory batch) public{
        for(uint256 i = 0; i < batch.length; i++){
            _tokenID.increment();
            uint256 tokenID = _tokenID.current();
            _mint(to,tokenID);
            _setTokenURI(tokenID, batch[i]);
        }
    }

    function _mint(address to, uint256 tokenID) internal virtual {
        require(to != address(0), "Cannot mint to address(0)");
        require(!_exists(tokenID), "tokenId already exists");
        
        _balances[to] += 1;
        _owners[tokenID] = to;

        //emit Transfer(address(0), to, tokenID);
    }

    function ownerOf(uint256 tokenId) public view  returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "owner query for nonexistent token");
        return owner;
    }


    function burn(uint256 tokenID) public onlyOwner{
        _burn(tokenID);
    }

    function _burn(uint256 tokenID) internal {
        
        address _owner = ownerOf(tokenID);
        _balances[_owner] -= 1;
        delete _owners[tokenID];

        //emit Transfer(owner,address(0),tokenID);
    }

    function approve(address to, uint256 tokenId) public {
        address owner = ownerOf(tokenId);
        require(to != owner, "approval to current owner");
        require( msg.sender == owner,  "approve caller is not owner");

        _approve(to, tokenId);
    }
    function getApproved(uint256 tokenId) public view returns (address) {
        require(_exists(tokenId), "approved query for nonexistent token");

        return _tokenApprovals[tokenId];
    }
    function _approve(address to, uint256 tokenId) internal virtual {
        _tokenApprovals[tokenId] = to;
        //emit Approval(ERC721.ownerOf(tokenId), to, tokenId);
    }

    function transferFrom(address from, address to,  uint256 tokenId) public {
       
        require(getApproved(tokenId) == msg.sender || ownerOf(tokenId) == msg.sender, "transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    function transferFrom( address to,  uint256 tokenId) public {
       
        require(ownerOf(tokenId) == msg.sender, "transfer caller is not owner ");

        _transfer(msg.sender, to, tokenId);
    }

      function _transfer(address from,address to,uint256 tokenId) internal {
        require(ownerOf(tokenId) == from, "transfer from incorrect owner");
        require(to != address(0), "transfer to the zero address");

        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        //emit Transfer(from, to, tokenId);
    }
}