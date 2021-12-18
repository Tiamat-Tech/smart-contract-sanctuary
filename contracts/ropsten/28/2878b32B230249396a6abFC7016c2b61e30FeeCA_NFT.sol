// SPDX-License-Identifier: MIT

pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NFT is ERC721, Ownable {
  constructor() ERC721("ANTIPFP", "PFP") {}

  /// @notice Custom Errors
  /// @dev attempted to set baseURI after already being set.
  error BaseUriAlreadySet();
  /// @dev attempted to mint more than allowed.
  error InvalidAmount();
  /// @dev message value is not price * num.
  error InvalidValue();
  /// @dev attempted ito mint more than the maximum supply.
  error MaxSupplyExceeded();
  /// @dev attempted action before provenance hash has been set.
  error ProvenanceNotSet();
  /// @dev attempted to set provenance hash after already being set.
  error ProvenanceAlreadySet();
  /// @dev attempted to ineteract with token that does not exist.
  error NonExistentToken();

  mapping (uint256 => uint256) public colors;
  uint256 public totalSupply = 0;
  string public base = "data:application/json;base64,eyJuYW1lIjoiQU5USVBGUCIsICJkZXNjcmlwdGlvbiI6IkFOVElQRlAgTkZUIiwgImF0dHJpYnV0ZXMiOiBbIHsgInRyYWl0X3R5cGUiOiAiQ29sb3IiLCAidmFsdWU6ICJ";
  string[] public encoded = [
    "DYWxpZm9ybmlhIEdvbGQifSBdIiIsICJpbWFnZSI6ICJkYXRhOmltYWdlL3N2Zyt4bWw7YmFzZTY0LFBITjJaeUIzYVdSMGFEMGlPVEF3SWlCb1pXbG5hSFE5SWprd01DSWdlRzFzYm5NOUltaDBkSEE2THk5M2QzY3Vkek11YjNKbkx6SXdNREF2YzNabklqNDhjbVZqZENCNFBTSXdJaUI1UFNJd0lpQjNhV1IwYUQwaU9UQXdJaUJvWldsbmFIUTlJamt3TUNJZ1ptbHNiRDBpSTJabVlXWXpOaUkrUEM5eVpXTjBQand2YzNablBnPT0ifQ==",
    "Sb3lhbCBQdXJwbGUifSBdIiIsICJpbWFnZSI6ICJkYXRhOmltYWdlL3N2Zyt4bWw7YmFzZTY0LFBITjJaeUIzYVdSMGFEMGlPVEF3SWlCb1pXbG5hSFE5SWprd01DSWdlRzFzYm5NOUltaDBkSEE2THk5M2QzY3Vkek11YjNKbkx6SXdNREF2YzNabklqNDhjbVZqZENCNFBTSXdJaUI1UFNJd0lpQjNhV1IwYUQwaU9UQXdJaUJvWldsbmFIUTlJamt3TUNJZ1ptbHNiRDBpSXpRd01tRTJaQ0krUEM5eVpXTjBQand2YzNablBnPT0ifQ==",
    "Sb3lhbCBSZWQifSBdIiIsICJpbWFnZSI6ICJkYXRhOmltYWdlL3N2Zyt4bWw7YmFzZTY0LFBITjJaeUIzYVdSMGFEMGlPVEF3SWlCb1pXbG5hSFE5SWprd01DSWdlRzFzYm5NOUltaDBkSEE2THk5M2QzY3Vkek11YjNKbkx6SXdNREF2YzNabklqNDhjbVZqZENCNFBTSXdJaUI1UFNJd0lpQjNhV1IwYUQwaU9UQXdJaUJvWldsbmFIUTlJamt3TUNJZ1ptbHNiRDBpSTJWbE1EQXdNQ0krUEM5eVpXTjBQand2YzNablBnPT0ifQ==",
    "CZXJrZWxleSBCbHVlIn0gXSIiLCAiaW1hZ2UiOiAiZGF0YTppbWFnZS9zdmcreG1sO2Jhc2U2NCxQSE4yWnlCM2FXUjBhRDBpT1RBd0lpQm9aV2xuYUhROUlqa3dNQ0lnZUcxc2JuTTlJbWgwZEhBNkx5OTNkM2N1ZHpNdWIzSm5Mekl3TURBdmMzWm5JajQ4Y21WamRDQjRQU0l3SWlCNVBTSXdJaUIzYVdSMGFEMGlPVEF3SWlCb1pXbG5hSFE5SWprd01DSWdabWxzYkQwaUl6QXdNek0yTWlJK1BDOXlaV04wUGp3dmMzWm5QZz09In0=",
    "FbWVyYWxkIEdyZWVuIn0gXSIiLCAiaW1hZ2UiOiAiZGF0YTppbWFnZS9zdmcreG1sO2Jhc2U2NCxQSE4yWnlCM2FXUjBhRDBpT1RBd0lpQm9aV2xuYUhROUlqa3dNQ0lnZUcxc2JuTTlJbWgwZEhBNkx5OTNkM2N1ZHpNdWIzSm5Mekl3TURBdmMzWm5JajQ4Y21WamRDQjRQU0l3SWlCNVBTSXdJaUIzYVdSMGFEMGlPVEF3SWlCb1pXbG5hSFE5SWprd01DSWdabWxzYkQwaUl6QXhOalF4TlNJK1BDOXlaV04wUGp3dmMzWm5QZz09In0=",
    "SaWJib24gUGluayJ9IF0iIiwgImltYWdlIjogImRhdGE6aW1hZ2Uvc3ZnK3htbDtiYXNlNjQsUEhOMlp5QjNhV1IwYUQwaU9UQXdJaUJvWldsbmFIUTlJamt3TUNJZ2VHMXNibk05SW1oMGRIQTZMeTkzZDNjdWR6TXViM0puTHpJd01EQXZjM1puSWo0OGNtVmpkQ0I0UFNJd0lpQjVQU0l3SWlCM2FXUjBhRDBpT1RBd0lpQm9aV2xuYUhROUlqa3dNQ0lnWm1sc2JEMGlJMlptTkdOa01pSStQQzl5WldOMFBqd3ZjM1puUGc9PSJ9",
    "Ccm93biJ9IF0iIiwgImltYWdlIjogImRhdGE6aW1hZ2Uvc3ZnK3htbDtiYXNlNjQsUEhOMlp5QjNhV1IwYUQwaU9UQXdJaUJvWldsbmFIUTlJamt3TUNJZ2VHMXNibk05SW1oMGRIQTZMeTkzZDNjdWR6TXViM0puTHpJd01EQXZjM1puSWo0OGNtVmpkQ0I0UFNJd0lpQjVQU0l3SWlCM2FXUjBhRDBpT1RBd0lpQm9aV2xuYUhROUlqa3dNQ0lnWm1sc2JEMGlJemRrTlRZME55SStQQzl5WldOMFBqd3ZjM1puUGc9PSJ9",
    "ZZWxsb3cifSBdIiIsICJpbWFnZSI6ICJkYXRhOmltYWdlL3N2Zyt4bWw7YmFzZTY0LFBITjJaeUIzYVdSMGFEMGlPVEF3SWlCb1pXbG5hSFE5SWprd01DSWdlRzFzYm5NOUltaDBkSEE2THk5M2QzY3Vkek11YjNKbkx6SXdNREF2YzNabklqNDhjbVZqZENCNFBTSXdJaUI1UFNJd0lpQjNhV1IwYUQwaU9UQXdJaUJvWldsbmFIUTlJamt3TUNJZ1ptbHNiRDBpSTJabFptVTJOeUkrUEM5eVpXTjBQand2YzNablBnPT0ifQ==",
    "CbGFjayJ9IF0iIiwgImltYWdlIjogImRhdGE6aW1hZ2Uvc3ZnK3htbDtiYXNlNjQsUEhOMlp5QjNhV1IwYUQwaU9UQXdJaUJvWldsbmFIUTlJamt3TUNJZ2VHMXNibk05SW1oMGRIQTZMeTkzZDNjdWR6TXViM0puTHpJd01EQXZjM1puSWo0OGNtVmpkQ0I0UFNJd0lpQjVQU0l3SWlCM2FXUjBhRDBpT1RBd0lpQm9aV2xuYUhROUlqa3dNQ0lnWm1sc2JEMGlJekF3TURBd01DSStQQzl5WldOMFBqd3ZjM1puUGc9PSJ9",
    "PcmFuZ2UifSBdIiIsICJpbWFnZSI6ICJkYXRhOmltYWdlL3N2Zyt4bWw7YmFzZTY0LFBITjJaeUIzYVdSMGFEMGlPVEF3SWlCb1pXbG5hSFE5SWprd01DSWdlRzFzYm5NOUltaDBkSEE2THk5M2QzY3Vkek11YjNKbkx6SXdNREF2YzNabklqNDhjbVZqZENCNFBTSXdJaUI1UFNJd0lpQjNhV1IwYUQwaU9UQXdJaUJvWldsbmFIUTlJamt3TUNJZ1ptbHNiRDBpSTJWaE56a3dNQ0krUEM5eVpXTjBQand2YzNablBnPT0ifQ==",
    "UcnVzdG1lIEJsdWUifSBdIiIsICJpbWFnZSI6ICJkYXRhOmltYWdlL3N2Zyt4bWw7YmFzZTY0LFBITjJaeUIzYVdSMGFEMGlPVEF3SWlCb1pXbG5hSFE5SWprd01DSWdlRzFzYm5NOUltaDBkSEE2THk5M2QzY3Vkek11YjNKbkx6SXdNREF2YzNabklqNDhjbVZqZENCNFBTSXdJaUI1UFNJd0lpQjNhV1IwYUQwaU9UQXdJaUJvWldsbmFIUTlJamt3TUNJZ1ptbHNiRDBpSXpBd1lXRm1PU0krUEM5eVpXTjBQand2YzNablBnPT0ifQ=="
 ];

  function mint(uint256 num) public payable {
    if (num < 1) revert InvalidAmount();
    if (69 * num / 1000 != msg.value) revert InvalidValue();
    if (totalSupply + num > 6969) revert MaxSupplyExceeded();
    if (msg.sender != owner()) {
      require(msg.value >= 0.069 ether);
    }
    uint256 supply = totalSupply;

    totalSupply += num;
    for (uint256 i = 0; i < num; i++) {
      colors[supply + i] = randomNum(block.difficulty, supply + i);
      _safeMint(msg.sender, supply + i);
    }
    delete supply;
  }

  function randomNum(uint256 _seed, uint256 _salt) public view returns(uint256) {
    uint256 num = uint256(keccak256(abi.encodePacked(block.timestamp, msg.sender, _seed, _salt))) % 6969;
    if (num < 42) {
      return 0;
    } else if (num < 111) {
      return 1;
    } else if (num < 199) {
      return 2;
    } else if (num < 399) {
      return 3;
    } else if (num < 819) {
      return 4;
    } else if (num < 1319) {
      return 5;
    } else if (num < 1819) {
      return 6;
    } else if (num < 2569) {
      return 7;
    } else if (num < 3469) {
      return 8;
    } else if (num < 4469) {
      return 9;
    } else {
      return 10;
    }
  }

  function getEncoded(uint256 index) public view returns(string memory) {
    return string(abi.encodePacked(base, encoded[index]));
  }

  function tokenURI(uint256 _tokenId)
    public
    view
    virtual
    override
    returns (string memory)
  {
    require(
      _tokenId <= totalSupply,
      "ERC721Metadata: URI query for nonexistent token"
    );

    return getEncoded(colors[_tokenId]);
  }

  function withdraw() public payable onlyOwner {
    payable(owner()).transfer(address(this).balance);
  }
}