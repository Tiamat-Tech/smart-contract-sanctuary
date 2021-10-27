// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "hardhat/console.sol";

/////////////////////////////////////////////////////////////
//                _   _ _______ _    _ _____   ____        //
//          /\   | \ | |__   __| |  | |  __ \ / __ \       //
//         /  \  |  \| |  | |  | |__| | |__) | |  | |      //
//        / /\ \ | . ` |  | |  |  __  |  _  /| |  | |      //
//       / ____ \| |\  |  | |  | |  | | | \ \| |__| |      //
//      /_/    \_\_| \_|  |_|  |_|  |_|_|  \_\\____/       //
//                                                         //
//                 #######                                 //
//               #   ####       ####     ###############   //
//      ########  ##  ##      #########################    //
//        ##########        ######################         //
//         ########           ###################          //
//          ###            #####  ##############  #        //
//            #####        #######  ##########             //
//             ######        ####          ##              //
//              #####        #### #           #####        //
//              ###           ##                ###  #     //
//              ##                                         //
/////////////////////////////////////////////////////////////

contract Anthro is ERC721, Ownable, ERC721Enumerable, ERC721URIStorage, IERC2981, AccessControl {
    using SafeMath for uint256;
    using Strings for uint256;
    using Address for address;
    using EnumerableMap for EnumerableMap.UintToAddressMap;
    using EnumerableSet for EnumerableSet.UintSet;
    using Counters for Counters.Counter;

    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    mapping(bytes4 => bool) internal supportedInterfaces;

    Counters.Counter private _tokenIds;

    // Store Hashes for IPFS
    mapping(string => uint8) private hashes;

    // Optional mapping for token URIs
    mapping (uint256 => string) private _tokenURIs;

    // Mapping from holder address to their (enumerable) set of owned tokens
    mapping (address => EnumerableSet.UintSet) private _holderTokens;

    // Mapping from token ID to owner address
    mapping(uint256 => address) private _owners;

    // Mapping owner address to token count
    mapping(address => uint256) private _balances;

    // ONLY 100 ANTHRO WILL EVER EXIST
    uint8 public maxAnthro = 100;

    string private _openseaURI = "https://anthro.mypinata.cloud/ipfs/QmazjjExs9U4XZZDd6Shhs8t6fuNVz2Ze3uNjMuUf3cB38";

    string private _baseURIextended = "https://anthro.mypinata.cloud/ipfs/";

    address private _artist;

    uint16 private _royaltyAmount = 1000; // This is 10%

    constructor(string memory name, string memory symbol, address artist) ERC721(name, symbol) {
      _artist = artist;
      _setupRole(ADMIN_ROLE, artist);
      _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
      supportedInterfaces[this.supportsInterface.selector] = true;
    }

    function updateOpenseaMetadata(string memory newURI) public onlyOwner {
      _openseaURI = newURI;
    }

    function withdraw() public onlyOwner {
        uint balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function updateMetadata(uint256 tokenId, string memory metadata) public {
      require(msg.sender == owner() || msg.sender == _artist);

      _setTokenURI(tokenId, metadata);
    }

    function adminMint(string memory hash, string memory metadata) public onlyRole(ADMIN_ROLE) {
        _mint(msg.sender, hash, metadata);
    }

    function ownerMint(string memory hash, string memory metadata) public onlyOwner {
        _mint(msg.sender, hash, metadata);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override onlyOwner {
      _transfer(from, to, tokenId);
    }

    function updateIpfsURL(string memory newURI) public onlyOwner {
        _baseURIextended = newURI;
    }

    function tokenURI(uint256 tokenId) public view virtual override(ERC721, ERC721URIStorage) returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

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
        // If there is a baseURI but no tokenURI, concatenate the tokenID to the baseURI.
        return string(abi.encodePacked(base, tokenId.toString()));
    }

    function contractURI() public view returns (string memory) {
        return _openseaURI;
    }

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        require(owner != address(0), "ERC721: owner query for nonexistent token");
        return owner;
    }

    function updateRoyalty(uint16 amount) public onlyOwner {
        _royaltyAmount = amount;
    }

    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view override(IERC2981) returns (
        address receiver,
        uint256 royaltyAmount
    ) {
      return (_artist, _royaltyAmount);
    }

    function supportsInterface(bytes4 interfaceID) public view virtual override(
      AccessControl, IERC165, ERC721, ERC721Enumerable) returns (bool) {
        return supportedInterfaces[interfaceID];
    }

    function _mint(address minter, string memory hash, string memory metadata) internal {
        require(minter == owner() || minter == _artist);

        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();

        require(tokenId < maxAnthro, "No More Anthro to create!");

        require(hashes[hash] != 1, "Already exists with IPFS hash");
        hashes[hash] = 1;

        _balances[minter] += 1;
        _owners[tokenId] = minter;

        _holderTokens[minter].add(tokenId);

        _safeMint(minter, tokenId);
        _setTokenURI(tokenId, metadata);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) public virtual override {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: transfer caller is not owner nor approved");
        _transfer(from, to, tokenId);
        require(checkOnERC721Received(from, to, tokenId, _data), "ERC721: transfer to non ERC721Receiver implementer");
    }

    function _transfer(address from, address to, uint256 tokenId) internal virtual override(ERC721) {
        require(ERC721.ownerOf(tokenId) == from, "ERC721: transfer of token that is not own"); // internal owner
        require(to != address(0), "ERC721: transfer to the zero address");

        _beforeTokenTransfer(from, to, tokenId);

        _approve(address(0), tokenId);

        _holderTokens[from].remove(tokenId);
        _holderTokens[to].add(tokenId);

        _balances[from] -= 1;
        _balances[to] += 1;
        _owners[tokenId] = to;

        emit Transfer(from, to, tokenId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _burn(uint256 tokenId) internal virtual override(ERC721, ERC721URIStorage) {
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual override {
        require(_exists(tokenId), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIextended;
    }

    function checkOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        if (to.isContract()) {
            try IERC721Receiver(to).onERC721Received(_msgSender(), from, tokenId, _data) returns (bytes4 retval) {
                return retval == IERC721Receiver.onERC721Received.selector;
            } catch (bytes memory reason) {
                if (reason.length == 0) {
                    revert("ERC721: transfer to non ERC721Receiver implementer");
                } else {
                    assembly {
                        revert(add(32, reason), mload(reason))
                    }
                }
            }
        } else {
            return true;
        }
    }
}