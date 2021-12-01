// SPDX-License-Identifier: Unlicensed
pragma solidity ^0.8;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract ContractNFTHandler is ERC721 {
    uint256 public tokenCount;
    mapping (uint256 => address) public tokenIdtoAdderss;
    mapping (uint256 => uint256) public tokenPrices;
    mapping (uint256 => bool) public forSale;
    mapping (address => mapping(address => Swap)) swap;

    struct Swap {
        uint256[] fromIds;
        uint256[] toIds;
        uint256 tipA;
        uint256 tipB;
    }

    struct NFT {
        uint256 id;
        uint256 price;
        bool onSale;
        address owner;
    }
    
    constructor (string memory _name, string memory _symbol) ERC721(_name, _symbol) {
        tokenCount = 1;
    }

    modifier isForSale(uint256 tokenId) {
        require(forSale[tokenId], "Contract is not currently for sale");
        _;
    }

    modifier isOwner(uint256 tokenId) {
        require(msg.sender == ownerOf(tokenId), "This is not owner of the token");
        _;
    }
    
    modifier isOwnerOf(address _address) {
        require(msg.sender == _address, "This is not owner");
        _;
    }

    function _updateOwnershipInNFT(uint256 tokenId, address to) private {
        tokenIdtoAdderss[tokenId] = to;
    }

    function _burn(uint256 tokenId) internal virtual override {
        _updateOwnershipInNFT(tokenId, address(0));
        delete tokenPrices[tokenId];
        delete forSale[tokenId];
        delete tokenIdtoAdderss[tokenId];
        super._burn(tokenId);
    }
    
    /**
     *  Mint the NFT
     */
    function mint(uint256 price) external {
        require(price > 0, "The price should be greater than 0");
        tokenIdtoAdderss[tokenCount] = msg.sender;
        tokenPrices[tokenCount] = price;
        forSale[tokenCount] = true;
        _safeMint(msg.sender, tokenCount);
        tokenCount++;
    }

    function setPrice(uint256 tokenId, uint256 price) external isOwner(tokenId) {
        tokenPrices[tokenId] = price;
    }

    // Change the sale status of an NFT if the sale status of an NFT is false, it can no longer be pruchased using the purchaseNFT function
    function setSaleStatus(uint256 tokenId, bool saleStatus) external isOwner(tokenId) {
        forSale[tokenId] = saleStatus;
    }

    // Change ownership of an NFT currently on sale
    function purchaseNFT(uint256 tokenId, address to) external payable isForSale(tokenId) {
        uint256 price = tokenPrices[tokenId];
        require(msg.value>=price*(1 wei), "Not enough money");

        // Transfer record of ownership
        address currentOwner = ownerOf(tokenId);
        _transfer(currentOwner, to, tokenId);
        _updateOwnershipInNFT(tokenId, to);

        // Pay the original owner and refund the excess money to the buyer
        address payable owner = payable(ownerOf(tokenId));
        address payable buyer = payable(msg.sender);
        owner.transfer(price);
        buyer.transfer(msg.value-price);

        // Set sale status to false
        forSale[tokenId] = false;
    }

    // Overriding base transfer functions to include _updateOwnershipNFT
    function transferFrom(address from, address to, uint256 tokenId) public virtual override isOwner(tokenId) {
        _transfer(from, to, tokenId);
        _updateOwnershipInNFT(tokenId, to);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override isOwner(tokenId) {
        safeTransferFrom(from, to, tokenId, "");
        _updateOwnershipInNFT(tokenId, to);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory _data) public virtual override isOwner(tokenId) {
        _safeTransfer(from, to, tokenId, _data);
        _updateOwnershipInNFT(tokenId, to);
    }

    function getAllNFTDetails() public view returns(NFT[] memory) {
        NFT[] memory nftDetails = new NFT[](tokenCount-1);
        for (uint i = 1; i < tokenCount; i++) {
            nftDetails[i-1] = NFT(i, tokenPrices[i], forSale[i], tokenIdtoAdderss[i]);
        }
        return nftDetails;
    }

    function getNFTDetails(uint256 tokenId) public view returns(NFT memory) {
        NFT memory nftDetails = NFT(tokenId, tokenPrices[tokenId], forSale[tokenId], tokenIdtoAdderss[tokenId]);
        return nftDetails;
    }

    function sendNFT(address from, address to, uint256 tokenId) internal {
        require(from == tokenIdtoAdderss[tokenId], "This is not owner");
        _safeTransfer(from, to, tokenId, "");
        _updateOwnershipInNFT(tokenId, to);
    }

    function compareArrays(uint256[] memory arr1, uint256[] memory arr2) internal pure returns(bool) {
        uint256 len;
        if (arr1.length > arr2.length) {
            len = arr1.length;
        } else {
            arr2.length;
        }

        for(uint256 i = 0; i < len; i ++) {
            if (arr1[i] != arr2[i]) {
                return false;
            }
        }
        return true;
    }

    function validateOwners(address _owner, uint256[] memory _tokenIds) internal view returns(bool) {
        uint256 len = _tokenIds.length;
        for(uint256 i = 0; i < len; i ++) {
            if (_owner != tokenIdtoAdderss[_tokenIds[i]]) {
                return false;
            }
        }
        return true;
    }

    function swapOffer(address _to, uint256[] memory _fromTokenIds, uint256[] memory _toTokenIds, uint256 _tip) external isOwner(_fromTokenIds[0]) returns(bool) {
        if (_fromTokenIds.length == 0 || _toTokenIds.length == 0) {
            revert("You can't swap empty token");
        }

        require(validateOwners(msg.sender, _fromTokenIds), "The owner is not correct");
        require(validateOwners(_to, _toTokenIds), "The owner is not correct");

        if (swap[msg.sender][_to].fromIds.length != 0 || swap[msg.sender][_to].toIds.length != 0) {
            revert("The Swap offer already exists");
        }
        // can only accept one offer between from and to
        if (swap[_to][msg.sender].fromIds.length != 0 || swap[_to][msg.sender].toIds.length != 0) {
            revert("The Swap offer already exists");
        }
        
        swap[msg.sender][_to].fromIds = _fromTokenIds;
        swap[msg.sender][_to].toIds = _toTokenIds;
        swap[msg.sender][_to].tipA = _tip;

        return true;
    }
    
    function swapCancel(address _to) external {
        delete swap[msg.sender][_to];
    }

    function swapReject(address _from) external {
        delete swap[_from][msg.sender];
    }

    function offerExist(address _from, address _to, uint256[] memory _fromTokenIds, uint256[] memory _toTokenIds) public view returns(bool) {
        Swap memory currentOffer = swap[_from][_to];
        if (compareArrays(currentOffer.fromIds, _fromTokenIds) && compareArrays(currentOffer.toIds, _toTokenIds)) {
            return true;
        } else {
            return false;
        }
    }

    // [0] will be the sent offer, [1] will be the recived offer
    // [0] or [1] will be empty
    function getOffer(address _to) public view returns(Swap[] memory) {
        Swap[] memory offers = new Swap[](2);
        offers[0] = swap[msg.sender][_to];
        offers[1] = swap[_to][msg.sender];
        return offers;
    }
    
    function offerAccept(address _from, uint256[] memory _fromTokenIds, uint256[] memory _toTokenIds, uint256 _tip) external {
        uint256 fromTokenCount = _fromTokenIds.length;
        uint256 toTokenCount = _toTokenIds.length;
        require(offerExist(_from, msg.sender, _fromTokenIds, _toTokenIds), "This offer doesn't exist");
        swap[_from][msg.sender].tipB = _tip;
        
        for (uint256 i = 0; i < fromTokenCount; i ++) {
            sendNFT(_from, msg.sender, _fromTokenIds[i]);
        }
    
        for (uint256 j = 0; j < toTokenCount; j ++) {
            sendNFT(msg.sender, _from, _toTokenIds[j]);
        }
    }
}