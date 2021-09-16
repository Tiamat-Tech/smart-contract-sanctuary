// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Cryptoking is ERC1155, Ownable {

    /**
     * @dev Emitted when guess is submitted to the chain.
     */
    event GuessMinted(address indexed player, uint256 indexed tokenId, string season, string nick, uint64 guesss1, uint64 guesss2, uint64 guesss3, uint64 guesss4, uint64 guesss5, uint64 guesss6, uint64 guesss7, uint64 lucky);

    /**
     * @dev Emitted when result is submitted to the chain.
     */
    event ResultSet(address indexed operator, uint256 indexed tokenId, string season, uint64 result1, uint64 result2, uint64 result3, uint64 result4, uint64 result5, uint64 result6, uint64 result7);

    /**
     * @dev Emitted when season is set.
     */
    event SeasonSet(address indexed operator, string indexed season, uint256 limit, uint256 mintPrice);

    // structure for guess
    struct Guess {
        string season;
        string nick;
        uint64 guess1;
        uint64 guess2;
        uint64 guess3;
        uint64 guess4;
        uint64 guess5;
        uint64 guess6;
        uint64 guess7;
        uint64 lucky;
    }

    // structure for guess
    struct Result {
        uint64 result1;
        uint64 result2;
        uint64 result3;
        uint64 result4;
        uint64 result5;
        uint64 result6;
        uint64 result7;
    }

    // name
    string private _name;

    // number of decimals
    uint8 private _numDecimals;

    // total number of tokens minted so far
    uint256 private _numTokens;
    
    // Mapping from token ID to guesses
    mapping(uint256 => Guess) private _guesses;

    // Mapping from token ID to results
    mapping(uint256 => Result) private _results;

    // Mapping from season to the maximum amounts that can be minted
    mapping(string => uint256) private _seasonLimits;

    // Mapping from season to the mint prices
    mapping(string => uint256) private _seasonMintPrices;

    // Mapping from season to the number of so far minted tokens
    mapping(string => uint256) private _seasonMints;

    /**
     * Creates new instance.
     */
    constructor(string memory name_, uint8 numDecimals_) ERC1155("") {
        _name = name_;
        _numDecimals = numDecimals_;
    }

    /**
     * Returns the contract name.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * Returns the number of decimal places this contract work with.
     */
    function numDecimals() public view returns (uint8) {
        return _numDecimals;
    }
    
    /**
     * Sets uri.
     */    
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }
    
    /**
     * Sets season limit.
     */    
    function setSeason(string memory season, uint256 limit, uint256 mintPrice) public onlyOwner {
        require(bytes(season).length > bytes("").length, "season cannot be empty string");
        _seasonLimits[season] = limit;
        _seasonMintPrices[season] = mintPrice;
        emit SeasonSet(msg.sender, season, limit, mintPrice);
    }

    /**
     * Returns the season limit.
     */
    function seasonLimit(string memory season) public view returns (uint256) {
        return _seasonLimits[season];
    }

    /**
     * Returns the season mint prices.
     */
    function seasonMintPrice(string memory season) public view returns (uint256) {
        return _seasonMintPrices[season];
    }

    /**
     * Returns the number of mints for season.
     */
    function seasonMints(string memory season) public view returns (uint256) {
        return _seasonMints[season];
    }    
    /**
     *
     * Mints the token and returns the id.
     */
     function mint(string memory season, string memory nick, uint64 guess1, uint64 guess2, uint64 guess3, uint64 guess4, uint64 guess5, uint64 guess6, uint64 guess7)
        public payable
    {   
        require(_seasonMints[season] < _seasonLimits[season], "Season limit has been reached");
        require(msg.value == _seasonMintPrices[season], "ETH value does not match the season mint price");
        bytes memory b = new bytes(0);
        _mint(msg.sender, _numTokens, 1, b);
        uint64 luck = generateLuckyNum(_numTokens, _numDecimals);
        _guesses[_numTokens] = Guess(season, nick, guess1, guess2, guess3, guess4, guess5, guess6, guess7, luck);
        emit GuessMinted(msg.sender, _numTokens, season, nick, guess1, guess2, guess3, guess4, guess5, guess6, guess7, luck);
        _numTokens = _numTokens + 1;
        _seasonMints[season] = _seasonMints[season] + 1;
    }    
    
    /**
     *
     * Sets the result for the given token.
     */
     function setResult(uint256 tokenId, uint64 result1, uint64 result2, uint64 result3, uint64 result4, uint64 result5, uint64 result6, uint64 result7)
        public onlyOwner
    {
        require(bytes(_guesses[tokenId].season).length > bytes("").length, "guess must be minted before result can be set");
        _results[tokenId] = Result(result1, result2, result3, result4, result5, result6, result7);
        emit ResultSet(msg.sender, tokenId, _guesses[tokenId].season, result1, result2, result3, result4, result5, result6, result7);
    }
    
    /**
     * Returns the guess data under the specified token.
     */
    function guess(uint256 tokenId) public view returns (Guess memory) {
        return _guesses[tokenId];
    }

    /**
     * Returns the result data under the specified token.
     */
    function result(uint256 tokenId) public view returns (Result memory) {
        return _results[tokenId];
    }

    /**
     * Returns balance of this contract.
     */
    function balance() public view returns (uint256) {
        return address(this).balance;
    }
    
    /**
     * Withdraws the balance.
     */
    function withdraw() public onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }
    
    /**
     * Generates lucky number.
     */
    function generateLuckyNum(uint256 seed, uint8 nd) internal pure returns (uint64) {
        uint256 fact = (100 * (10**nd)) + 1;
        uint256 kc = uint256(keccak256(abi.encodePacked(seed)));
        uint256 rn = kc % fact;
        return uint64(rn);
    }
    
}