//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract BundleNFT is Initializable, OwnableUpgradeable, ERC721URIStorageUpgradeable {

    struct NFT {
        IERC721 token;
        uint256 tokenId;
    }

    mapping(uint256 => NFT[]) public bundles;
    uint256 public bundleFee;

    function __BundleNFT_init(string memory name_, string memory symbol_) public initializer {
        __Ownable_init();
        __ERC721_init(name_, symbol_);
    }

    event MintMessage(uint256 message);
    /**
     * @dev Bundle multiple NFTs into a merged token.
     */
    function bundle(NFT[] memory _tokens) public payable returns(uint256) {
        require(msg.value >= bundleFee, "Bundle fee not paid"); // todo: maybe vulnerable to reentrancy attacks
        uint256 tokenId = uint256(keccak256(abi.encode(_tokens)));
        for (uint i = 0; i < _tokens.length; i++) {
            _tokens[i].token.safeTransferFrom(msg.sender, address(this), _tokens[i].tokenId);
            bundles[tokenId].push(_tokens[i]); // todo: verify safety
        }
        _safeMint(msg.sender, tokenId);
        emit MintMessage(tokenId);
        return tokenId;
    }
    
    /**
     * @dev Bundle multiple NFTs into a merged token with new content.
     */
    function bundleWithTokenURI(NFT[] memory _tokens, string memory tokenURI) public payable returns(uint256) {
        uint256 tokenId = bundle(_tokens);
        _setTokenURI(tokenId, tokenURI);
        emit MintMessage(tokenId);
        return tokenId;
    }

    /**
     * @dev Disassemble a bundle token.
     */
    function unbundle(uint256 _tokenId) public {
        require(ownerOf(_tokenId) == msg.sender, "ERC721: transfer of token that is not own");
        NFT[] memory _bundle = bundles[_tokenId];
        _burn(_tokenId);
        delete(bundles[_tokenId]);
        for (uint i = 0; i < _bundle.length; i++) {
            _bundle[i].token.safeTransferFrom(address(this), msg.sender, _bundle[i].tokenId);
        }
    }

    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721.onERC721Received.selector`.
     */
    function onERC721Received(
        address /* operator */,
        address /* from */,
        uint256 /* tokenId */,
        bytes calldata /* data */
    ) external pure returns (bytes4) {
        // todo: revert if this is not called within `bundle`
        return this.onERC721Received.selector;
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal pure override returns (string memory) {
        return "";
    }

    function setBundleFee(uint256 _fee) public onlyOwner {
        bundleFee = _fee;
    }

    /**
     * @dev Withdraw all fees to the owner address
     */
    function withdrawFees() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    /**
     * @dev Returns list on NFTs in bundle NFT by tokenId
     */
     function bundeledTokensOf(uint256 _tokenId) public view returns (NFT[] memory) {
        require(_exists(_tokenId), "ERC721Metadata: Bundeled tokens query for nonexistent token");
        return bundles[_tokenId];
     }
}