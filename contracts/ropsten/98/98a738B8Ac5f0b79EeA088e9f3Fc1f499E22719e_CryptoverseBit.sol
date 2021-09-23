// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract CryptoverseBit is ERC1155, Ownable {

    /**
     * @dev Emitted when prediction is submitted to the chain.
     */
    event PredictionMinted(address indexed player, uint256 tokenId, string series, uint256 seriesNumber, string nickname,
        uint64 lucky, uint64 predict_1, uint64 predict_2, uint64 predict_3, uint64 predict_4, uint64 predict_5, uint64 predict_6);

    /**
     * @dev Emitted when result is submitted to the chain.
     */
    event ResultSet(address indexed operator, uint256 tokenId, string series, uint64 result_0, uint64 result_1, uint64 result_2, uint64 result_3, uint64 result_4, uint64 result_5, uint64 result_6);

    /**
     * @dev Emitted when series is set.
     */
    event SeriesSet(address indexed operator, string series, uint256 limit, uint256 mintPrice);

    // structure for prediction
    struct Prediction {
        uint256 timestamp;
        string series;
        uint256 seriesNumber;
        string nickname;
        uint64 lucky;
        uint64 predict_1;
        uint64 predict_2;
        uint64 predict_3;
        uint64 predict_4;
        uint64 predict_5;
        uint64 predict_6;
    }

    // structure for result
    struct Result {
        uint64 result_0;
        uint64 result_1;
        uint64 result_2;
        uint64 result_3;
        uint64 result_4;
        uint64 result_5;
        uint64 result_6;
    }
        
    // structure for result with score
    struct ScoredResult {
        uint64 totalScore;
        uint64 result_0;
        uint64 result_1;
        uint64 score_1;
        uint64 result_2;
        uint64 score_2;
        uint64 result_3;
        uint64 score_3;
        uint64 result_4;
        uint64 score_4;
        uint64 result_5;
        uint64 score_5;
        uint64 result_6;
        uint64 score_6;
    }


    // name
    string private _name;

    // number of decimals
    uint8 private _numDecimals;

    // total number of tokens minted so far
    uint256 private _numTokens;
    
    // Mapping from token ID to predictions
    mapping(uint256 => Prediction) private _predictions;

    // Mapping from token ID to results
    mapping(uint256 => Result) private _results;

    // Mapping from series to the maximum amounts that can be minted
    mapping(string => uint256) private _seriesLimits;

    // Mapping from series to the mint prices
    mapping(string => uint256) private _seriesMintPrices;

    // Mapping from series to the number of so far minted tokens
    mapping(string => uint256) private _seriesMints;

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
     * Sets series limit.
     */    
    function setSeries(string memory series, uint256 limit, uint256 mintPrice) public onlyOwner {
        require(bytes(series).length > bytes("").length, "series cannot be empty string");
        _seriesLimits[series] = limit;
        _seriesMintPrices[series] = mintPrice;
        emit SeriesSet(msg.sender, series, limit, mintPrice);
    }

    /**
     * Returns the series limit.
     */
    function seriesLimit(string memory series) public view returns (uint256) {
        return _seriesLimits[series];
    }

    /**
     * Returns the series mint prices.
     */
    function seriesMintPrice(string memory series) public view returns (uint256) {
        return _seriesMintPrices[series];
    }

    /**
     * Returns the number of mints for series.
     */
    function seriesMints(string memory series) public view returns (uint256) {
        return _seriesMints[series];
    }    
    /**
     *
     * Mints the token with predictions.
     */
     function mint(string memory series, string memory nickname, uint64 predict_1, uint64 predict_2, uint64 predict_3, uint64 predict_4, uint64 predict_5, uint64 predict_6)
        public payable
    {   
        require(_seriesMints[series] < _seriesLimits[series], "Series limit has been reached");
        require(msg.value == _seriesMintPrices[series], "ETH value does not match the series mint price");
        bytes memory b = new bytes(0);
        _mint(msg.sender, _numTokens, 1, b);
        uint64 luck = generateLuckyNum(_numTokens, _numDecimals);
        uint256 seriesNumber = _seriesMints[series] + 1;
        _predictions[_numTokens] = Prediction(block.timestamp, series, seriesNumber, nickname, luck, predict_1, predict_2, predict_3, predict_4, predict_5, predict_6);
        emit PredictionMinted(msg.sender, _numTokens, series, seriesNumber, nickname, luck, predict_1, predict_2, predict_3, predict_4, predict_5, predict_6);
        _numTokens = _numTokens + 1;
        _seriesMints[series] = seriesNumber;
    }    
    
    /**
     *
     * Sets the result for the given token.
     */
     function setResult(uint256 tokenId, uint64 result_0, uint64 result_1, uint64 result_2, uint64 result_3, uint64 result_4, uint64 result_5, uint64 result_6)
        public onlyOwner
    {
        require(bytes(_predictions[tokenId].series).length > bytes("").length, "prediction must be minted before result can be set");
        _results[tokenId] = Result(result_0, result_1, result_2, result_3, result_4, result_5, result_6);
        emit ResultSet(msg.sender, tokenId, _predictions[tokenId].series, result_0, result_1, result_2, result_3, result_4, result_5, result_6);
    }
    
    /**
     * Returns the prediction data under the specified token.
     */
    function prediction(uint256 tokenId) public view returns (Prediction memory) {
        return _predictions[tokenId];
    }

    /**
     * Returns the result data under the specified token.
     */
    function result(uint256 tokenId) public view returns (ScoredResult memory) {
        uint64 score_1 = calculateScore(_predictions[tokenId].predict_1, _results[tokenId].result_1, _numDecimals);
        uint64 score_2 = calculateScore(_predictions[tokenId].predict_2, _results[tokenId].result_2, _numDecimals);
        uint64 score_3 = calculateScore(_predictions[tokenId].predict_3, _results[tokenId].result_3, _numDecimals);
        uint64 score_4 = calculateScore(_predictions[tokenId].predict_4, _results[tokenId].result_4, _numDecimals);
        uint64 score_5 = calculateScore(_predictions[tokenId].predict_5, _results[tokenId].result_5, _numDecimals);
        uint64 score_6 = calculateScore(_predictions[tokenId].predict_6, _results[tokenId].result_6, _numDecimals);
        uint64 totalScore = calculateTotalScore(score_1, score_2, score_3, score_4, score_5, score_6);
        return ScoredResult(totalScore, _results[tokenId].result_0,
            _results[tokenId].result_1, score_1,
            _results[tokenId].result_2, score_2,
            _results[tokenId].result_3, score_3,
            _results[tokenId].result_4, score_4,
            _results[tokenId].result_5, score_5,
            _results[tokenId].result_6, score_6);

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
    
    /**
     * Calculates score from prediction and results.
     */
    function calculateScore(uint64 pred, uint64 res, uint8 nd) internal pure returns (uint64) {
        if (pred == 0 && res == 0) {
            return 0;
        }
        uint256 fact = 10**nd;
        if (pred >= res) {
            uint256 p2 = pred;
            uint256 r2 = 100 * res * fact;
            uint256 r = r2 / p2;
            return uint64(r);
        }
        else {
            uint256 p2 = 100 * pred * fact;
            uint256 r2 = res;
            uint256 r = p2 / r2;
            return uint64(r);
        }        
    }
    
    /**
     * Calculates total score from the 6 scores.
     */
    function calculateTotalScore(uint64 s1, uint64 s2, uint64 s3, uint64 s4, uint64 s5, uint64 s6) internal pure returns (uint64) {
        uint256 s1a = s1 * 11;
        uint256 s2a = s2 * 12;
        uint256 s3a = s3 * 13;
        uint256 s4a = s4 * 14;
        uint256 s5a = s5 * 15;
        uint256 s6a = s6 * 16;
        uint256 res = (s1a + s2a + s3a + s4a + s5a + s6a) / 81;
        return uint64(res);
    }
    
}