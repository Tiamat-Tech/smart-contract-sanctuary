// SPDX-License-Identifier: SPDX-License
pragma solidity ^0.8.6;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/*
a⚡️c

███╗░░░███╗██╗██████╗░██████╗░░█████╗░██████╗░███████╗██████╗░
████╗░████║██║██╔══██╗██╔══██╗██╔══██╗██╔══██╗██╔════╝██╔══██╗
██╔████╔██║██║██████╔╝██████╔╝██║░░██║██████╔╝█████╗░░██║░░██║
██║╚██╔╝██║██║██╔══██╗██╔══██╗██║░░██║██╔══██╗██╔══╝░░██║░░██║
██║░╚═╝░██║██║██║░░██║██║░░██║╚█████╔╝██║░░██║███████╗██████╔╝
╚═╝░░░░░╚═╝╚═╝╚═╝░░╚═╝╚═╝░░╚═╝░╚════╝░╚═╝░░╚═╝╚══════╝╚═════╝░

* - * - * - * - * - * - * - * - * - * - * - * - * - * - * - *

╗═╔░░░░░╗═╔╗═╔╗═╔░░╗═╔╗═╔░░╗═╔░╗════╔░╗═╔░░╗═╔╗══════╔╗═════╔░
██║░╗═╔░██║██║██║░░██║██║░░██║╗█████╝╔██║░░██║███████╚██████╝╔
██║╗██╝╔██║██║██╝══██╚██╝══██╚██║░░██║██╝══██╚██╝══╔░░██║░░██║
██╝████╝██║██║██████╝╔██████╝╔██║░░██║██████╝╔█████╚░░██║░░██║
████╚░████║██║██╝══██╚██╝══██╚██╝══██╚██╝══██╚██╝════╔██╝══██╚
███╚░░░███╚██╚██████╚░██████╚░░█████╚░██████╚░███████╚██████╚░

ɐ⚡️ɔ
*/

struct Sale {
    address artistAddress;
    uint256 saleAmount;
}

contract Mirrored is ERC721, Ownable, Pausable {
    address public sweetCooper; // a⚡️c gnosis safe
    address public sweetAndy = 0x21868fCb0D4b262F72e4587B891B4Cf081232726;

    string public baseURI;

    // Pack these two 128s
    uint128 private nullPremintTokenId = 777; // Placeholder for null premint
    uint128 public maxSupply = 18; // Max supply, accounting for designated premints
    uint256 public listPrice = 200000000000000000; // 0.2 eth initial list price
    mapping(address => uint256) public premintDesignated; // Address paired w token ids for minting
    mapping(uint256 => address) public artistToken; // Collaborator paired w token id
    Sale[] public pastSales; // List of past sales

    // Keep track of state
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIdCounter; // For regular sales
    Counters.Counter private _premintCounter; // For designated sales

    constructor(string memory _baseURI) ERC721("Mirrored", "Mirrored") {
        baseURI = _baseURI;
    }

    // General contract state
    /*------------------------------------*/

    /**
     * Escape hatch to update price.
     */
    function setPrice(uint256 _listPrice) public onlyOwner {
        listPrice = _listPrice;
    }

    /**
     * Update sweet baby cooper's address in the event of an emergency
     */
    function setSweetCooper(address _sweetCooper) public {
        require(msg.sender == sweetAndy, "NOT_ANDY");
        sweetCooper = _sweetCooper;
    }

    /**
     * # TODO => DEFINITELY DELETE THIS LOL
     */
    function setSweetAndy(address _sweetAndy) public onlyOwner {
        console.log("this should not be set");
        sweetAndy = _sweetAndy;
    }

    /**
     * Add a user's address to premint mapping.
     */
    function addToPremint(address _address, uint128 _reservedTokenId) public onlyOwner {
        premintDesignated[_address] = _reservedTokenId;
    }

    /**
     * Remove a user's address from premint mapping.
     */
    function removeFromPremint(address _address) public onlyOwner {
        delete premintDesignated[_address];
    }

    /**
     * Add a collaborators's address to royalty mapping.
     */
    function addToArtistToken(address _address, uint128 _tokenId) public onlyOwner {
        artistToken[_tokenId] = _address;
    }

    /**
     * Remove a collaborators's address from mint royalty.
     */
    function removeFromArtistToken(uint128 _tokenId) public onlyOwner {
        delete artistToken[_tokenId];
    }

    /*
    * Withdraw, sends:
    * 50% of all past sales to artist.
    * ~45% of all past sales to collaborator.
    * ~5% of all past sales to devs.
    */
    function withdraw() public onlyOwner {
        // Pass collaborators their cut
        uint256 balance = address(this).balance;

        for (uint i = 0; i < pastSales.length; i++) {
            Sale memory pastSale = pastSales[pastSales.length - 1 - i];
            uint collaboratorCut = pastSale.saleAmount * 45/100;
            balance = balance - collaboratorCut;

            (bool artistSuccess, ) = pastSales[pastSales.length - 1 - 0]
                .artistAddress
                .call{ value: collaboratorCut }("");
            require(artistSuccess, "FAILED_SEND_ARTIST");

            pastSales.pop();
        }

        // Send devs 4.95%
        (bool success, ) = sweetCooper.call{ value: balance * 9/100 }("");
        require(success, "FAILED_SEND_DEV");

        // Send owner remainder
        (success, ) = owner().call{ value: balance * 91/100 }("");
        require(success, "FAILED_SEND_OWNER");
    }

    // Minting
    /*------------------------------------*/

    /**
     * Mint, updating storage of sales.
     */
    function handleSale(uint256 _tokenId) private {
        _safeMint(msg.sender, _tokenId);
        pastSales.push(Sale({
            artistAddress: artistToken[_tokenId],
            saleAmount: listPrice
        }));
    }

    /**
     * Handle minting depending if user address is stored within our designated
     * address mapping.
     */
    function handleDesignatedMint() private {
        // Handle designated mints, if an address is associated with a specific token id.
        if (premintDesignated[_msgSender()] != nullPremintTokenId) {
            require(!_exists(premintDesignated[_msgSender()]), "TOKEN_ALLOCATED");
            handleSale(premintDesignated[_msgSender()]);
            removeFromPremint(_msgSender());
            _premintCounter.increment();
        // Otherwise, this is a regular mint.
        } else {
            handleSale(_tokenIdCounter.current());
            _tokenIdCounter.increment();
        }
    }

    /**
     * Premint
     * # TODO => There is probably an OBO in MAX_REACHED
     */
    function premint() public payable whenNotPaused {
        require(premintDesignated[_msgSender()] != 0, "NOT_PREMINT");
        require(
            premintDesignated[_msgSender()] != 0 ||
            _tokenIdCounter.current() + 1 <= maxSupply,
            "MAX_REACHED"
        );
        require(listPrice <= msg.value, "LOW_ETH");

        handleDesignatedMint();
    }

    /**
     * Mint
     * # TODO => There is probably an OBO in MAX_REACHED
     */
    function publicMint() public payable whenNotPaused {
        require(
            premintDesignated[_msgSender()] != 0 ||
            _tokenIdCounter.current() + 1 <= maxSupply,
            "MAX_REACHED"
        );
        require(listPrice <= msg.value, "LOW_ETH");

        handleDesignatedMint();
    }

    // ERC721 Things
    /*------------------------------------*/

    /**
     * Get total token supply
     */
    function totalSupply() public view returns(uint256){
        return _tokenIdCounter.current() + _premintCounter.current();
    }

    /**
     * Get token URI
     */
    function tokenURI(uint256 _tokenId) public view override returns (string memory) {
        require(_exists(_tokenId), "TOKEN_DNE");
        return string(abi.encodePacked(baseURI, Strings.toString(_tokenId)));
    }

    // Pausable things
    /*------------------------------------*/

    /**
     * Handle pausing.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * Handle unpausing.
     */
    function unpause() public onlyOwner {
        _unpause();
    }
}