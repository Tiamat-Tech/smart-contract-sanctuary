// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./Custom/ERC721.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
//import "./@rarible/royalties/contracts/impl/RoyaltiesV2Impl.sol";
//import "./@rarible/royalties/contracts/LibPart.sol";
//import "./@rarible/royalties/contracts/LibRoyaltiesV2.sol";
//import "./Arbitrum/ArbSys.sol";
//import "./Arbitrum/Inbox.sol";

contract EtherCityNFT is ERC721, Pausable, Ownable {
    using Strings for uint256;

    bytes4 private constant _INTERFACE_ID_ERC2981 = 0x2a55205a;

    // --- State variables --- //
    string public baseURI;
    string public baseExtension = ".json";
    uint256 public cost = 0.5 ether;
    uint256 public currentTokenId = 1;
    mapping(address => bool) public whitelisted;
    uint256 constant MAX_SUPPLY = 9000;
    uint256 public MAX_MINT_WHITELIST = 2;
    uint256 public MAX_MINT_NOT_WHITELIST = 1;
    address public TEAM_WALLET = 0xbcCA080E8096AE7D1858E7B24eC3c1547b8eA51D;
    address public LP_WALLET = 0xbcCA080E8096AE7D1858E7B24eC3c1547b8eA51D;
    address public CHARITY_WALLET = 0xbcCA080E8096AE7D1858E7B24eC3c1547b8eA51D;

//    IInbox public inbox;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _initBaseURI
//        address _inbox
    ) ERC721(_name, _symbol) {
        setBaseURI(_initBaseURI);
//        inbox = IInbox(_inbox);
    }

    // --- Internal Functions --- //
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        payRoyalties(tokenId);
        return super._transfer(from,to,tokenId);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // --- Public Functions --- //
    function mint() public payable whenNotPaused {
        uint256 supply = currentTokenId;
        require((supply + 1) <= MAX_SUPPLY, "MAX Supply is 9000");

        if (msg.sender != owner()) {
            require(msg.value >= cost, "Ether value sent is not correct");
            if(whitelisted[msg.sender] != true) {
                require(balanceOf(msg.sender) < MAX_MINT_NOT_WHITELIST, "MAX MINT Limit");
            } else {
                require(balanceOf(msg.sender) < MAX_MINT_WHITELIST, "MAX WHITELIST MINT limit");
            }
            // Half of ether will be sent to team wallet address
            (bool sent, ) = payable(TEAM_WALLET).call{value: (msg.value / 2)}("");
            require(sent, "Failed to send Ether");
            // To-do: 50% needs to be spent through the bridge from Ethereum Mainnet to Arbitrum. _maxSubmissionCost: 0
            // uint256 result = inbox.createRetryableTicket{value: (msg.value / 2)}(msg.sender, 0, 0, msg.sender, msg.sender, 0, 0, '0x');
            // require(result >= 0, "createRetryableTicket");
        }

        _safeMint(msg.sender, currentTokenId);
        currentTokenId++;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, tokenId.toString(), baseExtension))
        : "";
    }

    // --- Administrator Functions --- //
    function startNewSale(string memory _newBaseURI) public onlyOwner {
        setBaseURI(_newBaseURI);
        currentTokenId = 1;
        _increaseStep();
    }

    function setTeamWallet(address _newTeamWallet) public onlyOwner {
        TEAM_WALLET = _newTeamWallet;
    }

    function setMaxLimitWhitelistUser(uint256 _newLimit) public onlyOwner {
        MAX_MINT_WHITELIST = _newLimit;
    }

    function setMaxLimitNotWhitelistUser(uint256 _newLimit) public onlyOwner {
        MAX_MINT_NOT_WHITELIST = _newLimit;
    }

    function setBaseURI(string memory _newBaseURI) public onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension) public onlyOwner {
        baseExtension = _newBaseExtension;
    }

    function setCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    function addAddressesToWhitelist(address _user) public onlyOwner {
        whitelisted[_user] = true;
    }

    function addAddressesToWhitelist(address[] memory _operators) public onlyOwner {
        for (uint256 i = 0; i < _operators.length; i++) {
            whitelisted[_operators[i]] = true;
        }
    }

    function removeWhitelistUser(address _user) public onlyOwner {
        whitelisted[_user] = false;
    }

    function removeWhitelistUser(address[] memory _operators) public onlyOwner {
        for (uint256 i = 0; i < _operators.length; i++) {
            whitelisted[_operators[i]] = false;
        }
    }

    function withdraw() public payable onlyOwner {
        // Do not remove this otherwise you will not be able to withdraw the funds.
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }

    // The following functions are overrides required by Solidity.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721)
        returns (bool)
    {
        if (interfaceId == _INTERFACE_ID_ERC2981) {
            return true;
        }

        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal whenNotPaused override(ERC721) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function payRoyalties(uint256 id) public payable {
        require(_exists(id), "ERC721Metadata: URI query for nonexistent token");
        uint256 royaltyPrice = cost * 250 / 10000;
        payable(TEAM_WALLET).transfer(royaltyPrice);
        payable(LP_WALLET).transfer(royaltyPrice);
        payable(CHARITY_WALLET).transfer(royaltyPrice);
        payable(ownerOf(id)).transfer(cost * 9250 / 10000);
    }
}