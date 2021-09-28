//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';

contract Zen is ERC721Enumerable, Ownable {

    using Strings for uint256;

    /// @dev Gift maximum supply
    /// uint256 public constant GIFT = 88;
    /// @dev Public sale maximum supply
    /// uint256 public constant SALE_PUBLIC = 10000;
    /// @dev Total maximum supply
    /// uint256 public constant SALE_MAX = GIFT + SALE_PUBLIC;
    uint256 public constant SALE_MAX = 3;
    ///@dev Max mint limit per purchase
    uint256 public constant MAX_MINT = 7;
    /// @dev NFT price
    uint256 public constant PRICE = 0.02 ether;

    /// @dev For calculate remain available.
    /// uint256 public totalGiftSupply;
    uint256 public totalPublicSupply = 0;

    /// @dev Sale active flag
    bool public saleActive = true;
    /// @dev Allow list sale active flag
    /// bool public allowListActive = false;
    /// @dev proof of hash
    string public proof;

    /// @dev allow list max mint limit
    /// uint256 public allowListMaxMint = 2;

    /// mapping(address => bool) private _allowList;
    /// mapping(address => uint256) private _allowListClaimed;

    string private _contractUri = '';
    string private _tokenBaseUri = '';
    string private _tokenRevealedBaseUri = '';

    event TotalMinted(uint256 totalPublicSupply);

    constructor(string memory name, string memory symbol, string memory baseUri) ERC721(name, symbol) {
        _tokenBaseUri = baseUri;
        emit TotalMinted(SALE_MAX - totalPublicSupply);
    }

    // function addToAllowList(address[] calldata addrs) external override onlyOwner {
    //     for (uint256 i = 0; i < addrs.length; i++) {
    //     require(addrs[i] != address(0), "The address is null");
    //     _allowList[addrs[i]] = true;

    //     /// @dev for add someone more than once.
    //     _allowListClaimed[addrs[i]] > 0 ? _allowListClaimed[addrs[i]] : 0;
    //     }
    // }

    // function onAllowList(address addr) external view override returns (bool) {
    //     return _allowList[addr];
    // }

    // function removeFromAllowList(address[] calldata addrs) external override onlyOwner {
    //     for (uint256 i = 0; i < addrs.length; i++) {
    //         require(addrs[i] != address(0), "The address is null");

    //         /// @dev For no need to reset possible _allowListClaimed.
    //         _allowList[addrs[i]] = false;
    //     }
    // }

    /**
    * @dev We want to be able to distinguish tokens bought during allowListActive
    * and tokens bought outside of allowListActive
    */
    // function allowListClaimedBy(address owner) external view override returns (uint256){
    //     require(owner != address(0), 'The address is null on Allow List Claimed By');
    //     return _allowListClaimed[owner];
    // }

    function purchase(uint256 tokenQuantity) external payable {
        require(saleActive, 'Sale is not active');
        /// require(!allowListActive, 'Only allowing from Allow List');
        require(totalSupply() < SALE_MAX, 'All tokens have been minted');
        require(tokenQuantity > 0, 'Purchase Quantity must be greater than 0');
        require(tokenQuantity <= MAX_MINT, 'Purchase limit exceed');
        /**
        * @dev The last person to purchase might pay too much.
        * This way however they can't get sniped.
        * If this happens, we'll refund the Eth for the unavailable tokens.
        */
        /// require(totalPublicSupply < SALE_PUBLIC, 'Public sale exceed');
        require(PRICE * tokenQuantity <= msg.value, 'ETH amount is not sufficient');

        for (uint256 i = 0; i < tokenQuantity; i++) {
            /**
            * @dev Since they can get here while exceeding the SALE_MAX,
            * we have to make sure to not mint any additional tokens.
            */
            if (totalPublicSupply < SALE_MAX) {
                /**
                * @dev Public token numbering starts at 1.
                */
                uint256 tokenId = totalPublicSupply + 1;

                totalPublicSupply += 1;
                _safeMint(msg.sender, tokenId);
            }
        }

        emit TotalMinted(SALE_MAX - totalPublicSupply);

    }

    // function purchaseAllowList(uint256 tokenQuantity) external override payable {
    //     require(saleActive, 'Sale is not active');
    //     require(allowListActive, 'Allow List is not active');
    //     require(_allowList[msg.sender], 'You are not on the Allow List');
    //     require(tokenQuantity <= 0, 'Purchase Quantity must be greater than 0');
    //     require(totalSupply() < SALE_MAX, 'All tokens have been minted');
    //     require(tokenQuantity <= allowListMaxMint, 'Cannot purchase this quantity of tokens on allow list');
    //     require(totalPublicSupply + tokenQuantity <= SALE_PUBLIC, 'Public sale exceed on allow list');
    //     require(_allowListClaimed[msg.sender] + tokenQuantity <= allowListMaxMint, 'Total purchase exceeds max limit');
    //     require(PRICE * tokenQuantity <= msg.value, 'ETH amount is not sufficient');

    //     for (uint256 i = 0; i < tokenQuantity; i++) {
    //         /**
    //         * @dev Public token numbering starts at 1.
    //         */
    //         uint256 tokenId = GIFT + totalPublicSupply + 1;

    //         totalPublicSupply += 1;
    //         _allowListClaimed[msg.sender] += 1;
    //         _safeMint(msg.sender, tokenId);
    //     }
    // }

    // function gift(address[] calldata to) external override onlyOwner {
    //     require(totalSupply() < SALE_MAX, 'All tokens have been minted');
    //     require(totalGiftSupply + to.length <= GIFT, 'Not enough tokens left to gift');

    //     for(uint256 i = 0; i < to.length; i++) {
    //         /// @dev We don't want our tokens to start at 0 but at 1.
    //         uint256 tokenId = totalGiftSupply + 1;

    //         totalGiftSupply += 1;
    //         _safeMint(to[i], tokenId);
    //     }
    // }

    function setSaleActive(bool _saleActive) external onlyOwner {
        saleActive = _saleActive;
    }

    // function setAllowListActive(bool _allowListActive) external override onlyOwner {
    //     allowListActive = _allowListActive;
    // }

    // function setAllowListMaxMint(uint256 maxMint) external override onlyOwner {
    //     allowListMaxMint = maxMint;
    // }

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

    function setRevealedBaseUri(string calldata uri) external onlyOwner {
        _tokenRevealedBaseUri = uri;
    }

    function getContractUri() external view returns (string memory) {
        return _contractUri;
    }

    /// @dev for initial test
    function getSaleMax() external pure returns (uint256) {
        return SALE_MAX;
    }

    function getProof() external view returns (string memory) {
        return proof;
    }

    function getBaseUri() external view returns (string memory) {
        return _tokenBaseUri;
    }

    /// for testnet
    function destroy() external onlyOwner {
        selfdestruct(payable(msg.sender));
    }

    function walletOfOwner(address _owner) external view returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokenIds = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
        }

        return tokenIds;
    }

    function tokenURI(uint256 tokenId) public view override(ERC721) returns (string memory) {
        require(_exists(tokenId), 'Token not found');

        /// @dev Convert string to bytes check if it's empty or not.
        string memory revealedBaseURI = _tokenRevealedBaseUri;
        return bytes(revealedBaseURI).length > 0 ?
        string(abi.encodePacked(revealedBaseURI, tokenId.toString())) :
        _tokenBaseUri;
    }
}