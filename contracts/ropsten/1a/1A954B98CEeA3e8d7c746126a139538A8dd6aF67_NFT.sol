pragma solidity ^0.8.1;

// This already includes ERC721 and the ownable files
import './721Meta.sol';
// file structure
// 721 -> Meta
// Ownable -> Meta
// Meta -> NFT

contract NFT is ERC721Metadata {
    uint fee =             30000000000000;
    uint weiToEther = 1000000000000000000;
    uint paidBalance = 0;
    // wei
    mapping (address => uint) ethBalances;
    mapping (address => mapping (address => mapping (uint => mapping(uint => uint)))) sales;

    function mintNFT(address _owner, uint tokenId) public onlyOwner {
        require(nftToOwner[tokenId] == address(0), "Id already used");
        nftToOwner[tokenId] = _owner;
        ownerToBalance[_owner]++;
        emit Transfer(address(0), _owner, tokenId);
    }

    function burnNFT(uint _tokenId) public onlyOwner {
        address oldOwner = nftToOwner[_tokenId];
        ownerToBalance[oldOwner]--;
        nftToOwner[_tokenId] = address(0);
        emit Transfer(oldOwner, address(0), _tokenId);
    }

    function withdraw(address _owner) public onlyOwner returns (bytes memory) {
        (bool sent, bytes memory data) = _owner.call{value: address(this).balance}("");
        require(sent);
        return data;
    }

    function updateFee(uint _fee) onlyOwner public {
        fee = _fee;
    }

    // Copy paste - add commision
    function _transfer(address _from, address _to, uint _tokenId) internal override {
        require(_from == nftToOwner[_tokenId]);
        require(_to != address(0));
        require(msg.value >= fee, "Tranaction fee not paid");
        // from is the owner, as of two lines ago
        require(msg.sender == _from || msg.sender == tokenApprovedAddress[_tokenId] || authorizedOperators[_from][msg.sender]);
        emit Transfer(_from, _to, _tokenId);
        emit Approval(_from, address(0), _tokenId);
        ownerToBalance[_from]--;
        ownerToBalance[_to]++;
        nftToOwner[_tokenId] = _to;
        tokenApprovedAddress[_tokenId] = address(0);
    }

    function sellNFT(address _from, address _to, uint _tokenId, uint _price) public {
        require(_from == nftToOwner[_tokenId]);
        require(_to != address(0));
        // from is the owner, as of two lines ago
        require(msg.sender == _from || msg.sender == tokenApprovedAddress[_tokenId] || authorizedOperators[_from][msg.sender]);
        sales[_from][_to][_tokenId][_price] = 1;
    }

    function buyNFT(address _from, address _to, uint _tokenId, uint _price) public {
        require(ethBalances[_to] >= _price * weiToEther, "Insufficient funds");
        require(msg.sender == _to);
        sales[_from][_to][_tokenId][_price] = 2;
    }

    function finishSale(address _from, address _to, uint _tokenId, uint _price) public {
        require(ethBalances[_to] >= _price * weiToEther, "Insufficient funds");
        require(_from == nftToOwner[_tokenId]);
        require(_to != address(0));
        uint s = sales[_from][_to][_tokenId][_price];
        require(s == 1 || s == 2, "No existing request");
        s == 1 ? 
        require(msg.sender == _to)
        : 
        require(msg.sender == _from || msg.sender == tokenApprovedAddress[_tokenId] || authorizedOperators[_from][msg.sender], "No access");
        (bool sent, bytes memory data) = _from.call{value: _price}("");
        require(sent, "Failed to send Ether");
        safeTransferFrom(_from, _to, _tokenId);
    }

    function deposit() public payable {
        ethBalances[msg.sender] += msg.value;
    }

    function withdraw() public returns (bytes memory) {
        uint val = ethBalances[msg.sender];
        ethBalances[msg.sender] = 0;
        (bool sent, bytes memory data) = msg.sender.call{value: val}("");
        require(sent);
        return data;
    }
}