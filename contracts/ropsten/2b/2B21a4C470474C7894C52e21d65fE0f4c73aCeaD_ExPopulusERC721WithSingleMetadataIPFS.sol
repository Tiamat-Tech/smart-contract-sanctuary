// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 *  /$$$$$$$$                 /$$$$$$$                               /$$
 * | $$_____/                | $$__  $$                             | $$
 * | $$       /$$   /$$      | $$  \ $$ /$$$$$$   /$$$$$$  /$$   /$$| $$ /$$   /$$  /$$$$$$$
 * | $$$$$   |  $$ /$$/      | $$$$$$$//$$__  $$ /$$__  $$| $$  | $$| $$| $$  | $$ /$$_____/
 * | $$__/    \  $$$$/       | $$____/| $$  \ $$| $$  \ $$| $$  | $$| $$| $$  | $$|  $$$$$$
 * | $$        >$$  $$       | $$     | $$  | $$| $$  | $$| $$  | $$| $$| $$  | $$ \____  $$
 * | $$$$$$$$ /$$/\  $$      | $$     |  $$$$$$/| $$$$$$$/|  $$$$$$/| $$|  $$$$$$/ /$$$$$$$/
 * |________/|__/  \__/      |__/      \______/ | $$____/  \______/ |__/ \______/ |_______/
 *                                              | $$
 *                                              | $$
 *                                              |__/
 */
contract ExPopulusERC721WithSingleMetadataIPFS is ERC721, Ownable {

    // use the counters to guarantee unique IDs
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // Base URI
    string private _baseURIExtended;

    // Global base URI, all NFTs share the same TokenURI
    string private _tokenURI;

    // the total balance
    uint256 private _totalAmountAllowedToBeMinted = 0;

    // the price
    uint256 _price = 0;

    // the beneficiary is who gets the eth paid during the mint
    address payable _beneficiary = payable(address(0));

    // events for all the different changes
    event BeneficiaryTransferred(address payable indexed previousBeneficiary, address payable indexed newBeneficiary);
    event BeneficiaryPaid(address payable beneficiary, uint256 amount);
    event PriceChange(uint256 previousPrice, uint256 newPrice);
    event TotalAmountAllowedToBeMintedChanged(uint256 previousAmount, uint256 newAmount);
    event BaseURIChanged(string previousAmount, string newAmount);
    event PermanentURI(string _value, uint256 indexed _id); //https://docs.opensea.io/docs/metadata-standards

    constructor(
        string memory name,
        string memory symbol,
        string memory baseURI,
        string memory defaultTokenURI,
        uint256 totalAmountAllowedToBeMinted,
        uint256 price,
        address payable beneficiary
    ) public ERC721(name, symbol) Ownable() {
        setBaseURI(baseURI);
        setTotalAllowedToBeMinted(totalAmountAllowedToBeMinted);
        setPrice(price);
        setBeneficiary(beneficiary);
        _tokenURI = defaultTokenURI;
    }

    /**
     * @dev create a new token
     */
    function mintToken(address owner) public payable returns (uint256) {

        require(msg.value >= getPrice(), "Not enough was sent. Please check the price variable.");

        _tokenIds.increment();

        uint256 id = _tokenIds.current();
        require(id < _totalAmountAllowedToBeMinted, "You cannot mint anymore of this token");

        _safeMint(owner, id);

        emit PermanentURI(tokenURI(id), id);

        if (msg.value > 0) {
            emit BeneficiaryPaid(_beneficiary, msg.value);
            _beneficiary.transfer(msg.value);
        }

        return id;
    }

    /**
     * @dev gets the current beneficiary that is set
     */
    function getBeneficiary() public view returns (address) {
        return _beneficiary;
    }

    /**
    * @dev the owner can call this to set a new beneficiary
    */
    function setBeneficiary(address payable newBeneficiary) public onlyOwner {
        require(newBeneficiary != address(0), "Beneficiary: new beneficiary is the zero address");
        _beneficiary = newBeneficiary;
        emit BeneficiaryTransferred(_beneficiary, newBeneficiary);
    }

    /**
     * @dev get the current tokenID, which should be equal to the amount minted
     */
    function totalMinted() public view virtual returns (uint256) {
        return _tokenIds.current();
    }

    /**
     * @dev public function for the owner to change the baseURI.
     */
    function getPrice() public view virtual returns (uint256)  {
        return _price;
    }

    /**
    * @dev public function for the owner to change the baseURI.
    */
    function setPrice(uint256 price) public onlyOwner() {
        emit PriceChange(_price, price);
        _price = price;
    }

    /**
     * @dev public function for the owner to change the baseURI.
     */
    function setTotalAllowedToBeMinted(uint256 totalAmountAllowedToBeMinted) public onlyOwner() {
        require(totalAmountAllowedToBeMinted >= _tokenIds.current(), "The total amount allowed to be minted, must be greater than the amount already minted.");
        _totalAmountAllowedToBeMinted = totalAmountAllowedToBeMinted;
    }

    /**
     * @dev public function for the owner to change the baseURI.
     */
    function setBaseURI(string memory baseURI_) public onlyOwner() {
        emit BaseURIChanged(_baseURIExtended, baseURI_);
        _baseURIExtended = baseURI_;
    }

    /**
    * @dev get the current BaseURI
    */
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIExtended;
    }

    /**
    * @dev get the current tokenURI given a tokenID
    */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");

        string memory base = _baseURI();
        return string(abi.encodePacked(base, _tokenURI));
    }

}