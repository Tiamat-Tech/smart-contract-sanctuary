// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Metadata.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract DosuInvites is ERC721URIStorage, Ownable {
  using Counters for Counters.Counter;
  using Strings for uint256;
  /// @dev token counter
  Counters.Counter public tokenId;

  /// @dev base URI
  string public baseURI;

  /// @dev max tokens supply
  uint256 public constant MAX_INVITES_SUPPLY = 1000;

  /// @dev addresses whitelist that allowed to mint
  mapping(address => bool) public whitelist;
  /// @dev list of owned tokenId by address
  mapping(address => uint256) public ownedTokenByAddress;

  // mapping(uint256 => string) public handles;

  struct Invite {
    address ethAddress;
    uint256 tokenId;
  }

  event Mint(address to, uint256 tokenId);

  /// @dev array of minted invites includes ethAddress and tokenId
  Invite[] internal mintedInvites;

  constructor() ERC721("Dosu Invites", "DOSU") {}

  /// @notice Mint invite function
  /// @param _to Recipient address
  function mint(address _to) public {
    require(whitelist[_to] == true, "This address is not whitelisted");
    require(balanceOf(_to) == 0, "This address is already have an invite");
    require(tokenId.current() <= MAX_INVITES_SUPPLY, "No invites left");

    uint256 _tokenId = tokenId.current();
    _mint(_to, _tokenId);
    tokenId.increment();

    emit Mint(_to, _tokenId);

    Invite memory invite = Invite({tokenId: _tokenId, ethAddress: _to});
    mintedInvites.push(invite);
    ownedTokenByAddress[_to] = _tokenId;
  }

  function setBaseURI(string memory _baseURI) public onlyOwner {
    baseURI = _baseURI;
  }

  function tokenURI(uint256 _tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _exists(_tokenId),
      "ERC721Metadata: URI query for nonexistent token"
    );

    string memory _baseURI = _baseURI();
    address _tokenOwner = ownerOf(_tokenId);
    return
      bytes(baseURI).length > 0
        ? string(abi.encodePacked(_baseURI, _tokenId.toString()))
        : "";
    // return
    //   bytes(baseURI).length > 0
    //     ? string(
    //       abi.encodePacked(
    //         _baseURI,
    //         "?filename=",
    //         _tokenId.toString(),
    //         "-",
    //         _tokenOwner,
    //         ".png"
    //       )
    //     )
    //     : "";
  }

  /// @notice Mint invite function
  /// @param _owner Owner address
  /// @return Token id that correspond to passed address
  function checkTokenId(address _owner) public view returns (uint256) {
    return ownedTokenByAddress[_owner];
  }

  /// @notice Function for adding address to the whitelist
  /// @param _user Owner address
  function whitelistAddress(address _user) public onlyOwner {
    whitelist[_user] = true;
  }

  /// @notice Function that returns array of Invites structs, includes all minted invites
  /// @return Invite[] array
  function getMintedInvites() public view returns (Invite[] memory) {
    return mintedInvites;
  }
}