// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MalevichToken.sol";

// For debugging only
import "hardhat/console.sol";

contract VideoNFTContract is ERC721, Ownable {
    using Strings for uint256;
    using Counters for Counters.Counter;
    
    struct Ownership {
        address owner;
        uint256 ownershipStartTime;
    }

    struct OwnerReward {
        uint256 rewardPaid;
        uint256 rewardStored;
    }
    
    MalevichToken rewardToken;
    Counters.Counter private _tokenIds;
    mapping(uint256 => Ownership) private _owners;
    mapping(address => OwnerReward) private _ownersReward;
    mapping(address => uint256) private _balances;
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => address) private _tokenApprovals;

    uint256 quantPeriod;
    uint256 rewardPerQuant;
    constructor(address tokenAddress, uint256 _quantPeriod, uint256 _rewardPerQuant) public ERC721("VideoNFTContract", "VNFT") {
        require(tokenAddress != address(0), "VideoNFTContract: address must not be empty");
        rewardToken = MalevichToken(tokenAddress);
        quantPeriod = _quantPeriod;
        rewardPerQuant = _rewardPerQuant;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "VideoNFTContract: URI query for nonexistent token");

        string memory _tokenURI = _tokenURIs[tokenId];
        string memory base = _baseURI();

        // If there is no base URI, return the token URI.
        if (bytes(base).length == 0) {
            return _tokenURI;
        }
        // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
        if (bytes(_tokenURI).length > 0) {
            return string(abi.encodePacked(base, _tokenURI));
        }

        return super.tokenURI(tokenId);
    }

    function balanceOf(address owner) public view override returns (uint256) {
        require(owner != address(0), "VideoNFTContract: balance query for the zero address");
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view override returns (address) {
        address _owner = _owners[tokenId].owner;
        require(_owner != address(0), "VideoNFTContract: owner query for nonexistent token");
        return _owner;
    }

    function approve(address to, uint256 tokenId) public override {
        address owner = ownerOf(tokenId);
        require(to != owner, "VideoNFTContract: approval to current owner");

        require(
            _msgSender() == owner || isApprovedForAll(owner, _msgSender()),
            "VideoNFTContract: approve caller is not owner nor approved for all"
        );

        _approve(to, tokenId);
    }

    function mint(address recipient, string memory tokenURI) public onlyOwner returns (uint256) {
        _tokenIds.increment();

        uint256 newTokenId = _tokenIds.current();
        _mint(recipient, newTokenId);
        _setTokenURI(newTokenId, tokenURI);
         
        return _tokenIds.current();
    }

    function sell(uint256 tokenId, address recipient) public onlyOwner returns (bool) {
        
        require(_owners[tokenId].ownershipStartTime == 0, "VideoNFTContract: token was sold");
        _transfer(_msgSender(), recipient, tokenId);
        _owners[tokenId].ownershipStartTime = block.timestamp;
        //TODO(): ???

        return true;
    }

    function getAvailableReward(uint256 tokenId) public view returns (uint256) {
        require (_owners[tokenId].owner == _msgSender(), "VideoNFTContract: is not own");
        uint256 tokenReward = rewardPerQuant * ((block.timestamp - _owners[tokenId].ownershipStartTime) / quantPeriod);
        return tokenReward + _ownersReward[_msgSender()].rewardStored - _ownersReward[_msgSender()].rewardPaid;
    }

    function withdrawReward(uint256 tokenId, uint256 amount) public returns (bool) {
        require (_owners[tokenId].owner == _msgSender(), "VideoNFTContract: is not own");
       
        uint256 tokenReward = rewardPerQuant * ((block.timestamp - _owners[tokenId].ownershipStartTime) / quantPeriod);
        uint256 availableReward = tokenReward + _ownersReward[_msgSender()].rewardStored - _ownersReward[_msgSender()].rewardPaid;
        require (availableReward >= amount, "VideoNFTContract: available reward is less than amount");

        rewardToken.mint(_msgSender(), amount);
        _ownersReward[_msgSender()].rewardPaid = _ownersReward[_msgSender()].rewardPaid + amount;
        
        return true;
    }

    function isVideoNFTSold(uint256 tokenId) public view returns (bool) {
        if (_owners[tokenId].ownershipStartTime != 0) return true;
        return false;
    }

    function exists(uint256 tokenId) public view returns (bool) {
        return _exists(tokenId);
    }

    function getQuantPeriod() public view returns (uint256) {
        return quantPeriod;
    }

    function setQuantPeriod(uint256 _quantPeriod) public onlyOwner {
        quantPeriod = _quantPeriod;
    }

    function getRewardPerQuant() public view returns (uint256) {
        return rewardPerQuant;
    }

    function setRewardPerQuant(uint256 _rewardPerQuant) public onlyOwner {
        rewardPerQuant = _rewardPerQuant;
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "VideoNFTContract: transfer caller is not owner nor approved");

        _transfer(from, to, tokenId);
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        require(ownerOf(tokenId) == from, "VideoNFTContract: transfer of token that is not own");
        require(to != address(0), "VideoNFTContract: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        // Clear approvals from the previous owner
        _approve(address(0), tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId].owner = to;

        emit Transfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal override {
        address owner = ownerOf(tokenId);

        _beforeTokenTransfer(owner, address(0), tokenId);

        // Clear approvals
        _approve(address(0), tokenId);

        _balances[owner] -= 1;
        delete _owners[tokenId];

        emit Transfer(owner, address(0), tokenId);

        if (bytes(_tokenURIs[tokenId]).length != 0) {
            delete _tokenURIs[tokenId];
        }
    }

    function _mint(address to, uint256 tokenId) internal override {
        require(to != address(0), "VideoNFTContract: mint to the zero address");
        require(!_exists(tokenId), "VideoNFTContract: token already minted");

        _beforeTokenTransfer(address(0), to, tokenId);

        _balances[to] += 1;
        _owners[tokenId].owner = to;

        emit Transfer(address(0), to, tokenId);
    }

    function _approve(address to, uint256 tokenId) internal override {
        _tokenApprovals[tokenId] = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) private {
        require(_exists(tokenId), "VideoNFTContract: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function _exists(uint256 tokenId) internal view override returns (bool) {
        return _owners[tokenId].owner != address(0);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view override returns (bool) {
        require(_exists(tokenId), "VideoNFTContract: operator query for nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || getApproved(tokenId) == spender || isApprovedForAll(owner, spender));
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        if (from == address(0) || to == address(0)) return;
        _ownersReward[from].rewardStored = _ownersReward[from].rewardStored + rewardPerQuant * ((block.timestamp - _owners[tokenId].ownershipStartTime) / quantPeriod); 
    }
}