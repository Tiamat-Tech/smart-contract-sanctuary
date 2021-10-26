//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

contract MainContract is ERC721Enumerable, Ownable {

    using Strings for uint256;

    ///@dev Max mint limit per purchase
    uint256 public constant MAX_MINT = 3;
    /// @dev NFT price
    uint256 public constant PRICE = 0.04 ether;
    /// @dev Gift maximum supply
    uint256 public constant GIFT = 5;
    /// @dev Public sale maximum supply
    uint256 public constant SALE_PUBLIC = 10;
    /// @dev Total maximum supply
    uint256 public constant SALE_MAX = GIFT + SALE_PUBLIC;

    /// @dev Sale active flag
    bool public saleActive = false;
    /// @dev White list sale active flag
    bool public whiteListActive = true;
    /// @dev proof of hash
    string public proof;

    /// @dev White list max mint limit
    uint256 public whiteListMaxMint = 2;

    /// @dev For calculate remain available.
    uint256 public totalGiftSupply;
    uint256 public totalPublicSupply;

    mapping(address => bool) private _whiteList;
    mapping(address => uint256) private _whiteListClaimed;

    string private _contractUri = '';
    string private _tokenBaseUri = '';

    constructor(string memory name, string memory symbol, string memory baseUri) ERC721(name, symbol) {
        _tokenBaseUri = baseUri;
    }

    function addToWhiteList(address[] calldata addrs) external onlyOwner {
        for (uint256 i = 0; i < addrs.length; i++) {
        require(addrs[i] != address(0), "The address is null");
        _whiteList[addrs[i]] = true;

        /// @dev for add someone more than once.
        _whiteListClaimed[addrs[i]] > 0 ? _whiteListClaimed[addrs[i]] : 0;
        }
    }

    function onWhiteList(address addr) external view returns (bool) {
        return _whiteList[addr];
    }

    function removeFromWhiteList(address[] calldata addrs) external onlyOwner {
        for (uint256 i = 0; i < addrs.length; i++) {
            require(addrs[i] != address(0), "The address is null");

            /// @dev For no need to reset possible _whiteListClaimed.
            _whiteList[addrs[i]] = false;
        }
    }

    /**
    * @dev We want to be able to distinguish tokens bought during whiteListActive
    * and tokens bought outside of whiteListActive
    */
    function whiteListClaimedBy(address owner) external view returns (uint256){
        require(owner != address(0), 'The address is null on white list Claimed By');
        return _whiteListClaimed[owner];
    }

    function purchase(uint256 tokenQuantity) external payable {
        require(saleActive, 'Sale is not active');
        require(!whiteListActive, 'Only allowing from white list');
        require(totalSupply() < SALE_MAX, 'All tokens have been minted');
        require(tokenQuantity > 0, 'Purchase Quantity must be greater than 0');
        require(tokenQuantity <= MAX_MINT, 'Purchase limit exceed');
        /**
        * @dev The last person to purchase might pay too much.
        * This way however they can't get sniped.
        * If this happens, we'll refund the Eth for the unavailable tokens.
        */
        require(totalPublicSupply < SALE_PUBLIC, 'Public sale exceed');
        require(PRICE * tokenQuantity <= msg.value, 'ETH amount is not sufficient');

        for (uint256 i = 0; i < tokenQuantity; i++) {
            /**
            * @dev Since they can get here while exceeding the SALE_MAX,
            * we have to make sure to not mint any additional tokens.
            */
            if (totalPublicSupply < SALE_PUBLIC) {
                /**
                * @dev Public token numbering starts at 1.
                */
                uint256 tokenId = totalSupply() + 1;

                totalPublicSupply += 1;
                _safeMint(msg.sender, tokenId);
            }
        }
    }

    function purchaseWhiteList(uint256 tokenQuantity) external payable {
        require(saleActive, 'Sale is not active');
        require(whiteListActive, 'White list is not active');
        require(_whiteList[msg.sender], 'You are not on the white list');
        require(tokenQuantity > 0, 'Purchase Quantity must be greater than 0');
        require(totalSupply() < SALE_MAX, 'All tokens have been minted');
        require(tokenQuantity <= whiteListMaxMint, 'Cannot purchase this quantity of tokens on white list');
        require(totalPublicSupply + tokenQuantity <= SALE_PUBLIC, 'Public sale exceed on white list');
        require(_whiteListClaimed[msg.sender] + tokenQuantity <= whiteListMaxMint, 'Total purchase exceeds max limit');
        require(PRICE * tokenQuantity <= msg.value, 'ETH amount is not sufficient');

        for (uint256 i = 0; i < tokenQuantity; i++) {
            /**
            * @dev Public token numbering starts at 1.
            */
            uint256 tokenId = totalSupply() + 1;

            totalPublicSupply += 1;
            _whiteListClaimed[msg.sender] += 1;
            _safeMint(msg.sender, tokenId);
        }
    }

    function gift(address[] calldata to) external onlyOwner {
        require(totalSupply() < SALE_MAX, 'All tokens have been minted');
        require(totalGiftSupply + to.length <= GIFT, 'Not enough tokens left to gift');

        for(uint256 i = 0; i < to.length; i++) {
            /// @dev We don't want our tokens to start at 0 but at 1.
            uint256 tokenId = totalSupply() + 1;

            totalGiftSupply += 1;
            _safeMint(to[i], tokenId);
        }
    }

    function setSaleActive() external onlyOwner {
        saleActive = !saleActive;
    }

    function setWhiteListActive() external onlyOwner {
        whiteListActive = !whiteListActive;
    }

    function setWhiteListMaxMint(uint256 maxMint) external onlyOwner {
        whiteListMaxMint = maxMint;
    }

    function setProof(string calldata proofHash) external onlyOwner {
        proof = proofHash;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function setContractUri(string calldata uri) external onlyOwner {
        _contractUri = uri;
    }

    function setBaseUri(string calldata uri) external onlyOwner {
        _tokenBaseUri = uri;
    }

    function contractURI() public view returns (string memory) {
        return _contractUri;
    }

    /// @dev for initial test
    /// for testnet
    function destroy() external onlyOwner {
        selfdestruct(payable(msg.sender));
    }

    function getSaleMax() public pure returns (uint256) {
        return SALE_MAX;
    }

    function getProof() public view returns (string memory) {
        return proof;
    }

    function getBaseUri() public view returns (string memory) {
        return _tokenBaseUri;
    }

    function walletOfOwner(address _owner) public view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokenIds = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokenIds;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_exists(tokenId), 'Token not found');

        return string(abi.encodePacked(_tokenBaseUri, tokenId.toString()));
    }
}