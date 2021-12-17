// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "./ScoreDBInterface.sol";
import "./IInvestor.sol";

/// @title A contract responsible for fetching scores from off chain and executing lending logic leveraging Openzeppelin for upgradability (UUPS).
/// @author Hasan Raza

contract ScoreDB is ChainlinkClient, Pausable, Ownable, ScoreDBInterface {
  struct LoanRequest {
    uint256 loanId;
    bytes32 hash;
    bytes signature;
    address investor;
  }

  using Chainlink for Chainlink.Request;
  // Mapping TokenId to Score; the score cache
  mapping(uint256 => uint16) private scoreCache;
  // Mapping requestId to LoanRequest struct
  mapping(bytes32 => LoanRequest) private loanRequestTracker;
  // Mapping requestId to tokenId so fulfill() can access the correct tokenId
  mapping(bytes32 => uint256) private tokenIdTracker;
  // Mapping LTV to score
  mapping(uint16 => uint256) private LTV;

  LoanRequest private loanRequest;

  // Address of the oracle contract; the intermediary between the chain and off-chain node
  address private oracle;
  bytes32 private jobId;
  uint256 private fee;
  string private baseURI;

  event ScoreRequested(uint256 indexed tokenId);
  event ScoreReceived(uint256 indexed tokenId, uint16 indexed score);
  event ScoreNotGenerated(uint256 indexed tokenId, uint16 indexed score);
  event ScoreGenerationError(uint256 indexed tokenId, uint16 indexed score);

  /**
   * Network: Kovan
   * Kovan_Link: 0xa36085F69e2889c224210F603D836748e7dC0088
   * Oracle: 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8 (Chainlink Devrel
   * Node)
   * Job Id: d5270d1c311941d0b08bead21fea7747
   * Fee: 0.1 LINK
   */

  /**
   * @notice the constrcutor of the contract; initializes values.
   */
  constructor() {
    setPublicChainlinkToken();
    oracle = 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8;
    jobId = "d5270d1c311941d0b08bead21fea7747";
    fee = 0.1 * 10**18; // (Varies by network and job)
    baseURI = "https://cs-api-v1.roci.fi/score/";
  }

  /**
   * @notice triggers the score update request
   */
  function requestScore(uint256 tokenId) internal returns (bytes32 requestId) {
    // Emit an event to show that the score request has been initiated
    emit ScoreRequested(tokenId);
    // Constructing the URI to which the call will be made
    string memory uri = stringConcat(baseURI, Strings.toString(tokenId));
    // Fetch all scores, then filter according to tokenId
    Chainlink.Request memory request = buildChainlinkRequest(
      jobId,
      address(this),
      this.fulfill.selector
    );
    // Set the URL to perform the GET request on
    request.add("get", uri);
    // Tease out the value at this path from the received object
    request.add("path", "CreditScore");
    // Initiate the request and store the returned request Id in reqId
    bytes32 reqId = sendChainlinkRequestTo(oracle, request, fee);
    // Store the tokenId against the requestId (so it can be accessed later in fulfill function)
    tokenIdTracker[reqId] = tokenId;
    return reqId;
  }

  /**
   * @notice sets the latest score of a tokenId, then calls borrowFulfill of Investor.sol to release the loan.
   */
  function fulfill(bytes32 _requestId, uint16 _score)
    public
    recordChainlinkFulfillment(_requestId)
  {
    // Ensure that only the oracle contract may call this function
    require(msg.sender == oracle, "Only Oracle contract may call");

    uint256 tokenId = tokenIdTracker[_requestId];

    // Emit events for scores of 0 and 1000; for "score not yet generated" and "error in generating the score", respectively
    if (_score == uint256(0)) {
      emit ScoreNotGenerated(tokenId, _score);
    } else if (_score == uint256(1000)) {
      emit ScoreGenerationError(tokenId, _score);
    }
    scoreCache[tokenId] = _score;
    // Also emit an event with the tokenId and the score
    emit ScoreReceived(tokenId, _score);
    LoanRequest memory c = loanRequestTracker[_requestId];
    // makes borrow fulfill optional
    if (c.loanId != 0) {
      IInvestor(c.investor).borrowFulfill(c.loanId, c.hash, c.signature);
    }
  }

  /**
   * @notice returns the score of a tokenId from the cache
   */
  function getCurrentScore(uint256 tokenId)
    public
    view
    override
    returns (uint16)
  {
    return scoreCache[tokenId];
  }

  /**
   * @notice requests latest score from off-chain, then initiates the loan request
   */
  function requestUpdatedScoreBorrow(
    uint256 tokenId,
    uint256 loanId,
    bytes32 hash,
    bytes memory signature
  ) public override {
    // Ensure enough link
    require(IERC20(0xa36085F69e2889c224210F603D836748e7dC0088).balanceOf(address(this)) >= fee, "Not enough LINK");
    bytes32 reqId = requestScore(tokenId);
    loanRequestTracker[reqId] = LoanRequest(
      loanId,
      hash,
      signature,
      msg.sender
    );
  }

  function updateScore(uint256 _tokenId) public {
    require(IERC20(0xa36085F69e2889c224210F603D836748e7dC0088).balanceOf(address(this)) >= fee, "Not enough LINK");
    requestScore(_tokenId);
  }

  function setLtv(uint16 _score, uint256 _LTV) public onlyOwner {
    LTV[_score] = _LTV;
  }

  function getLtv(uint16 _score) public view returns (uint256) {
    return LTV[_score];
  } 

  /**
   * @notice concatenates two tokenId with the baseUri
   */
  function stringConcat(string memory baseUri, string memory tokenId)
    internal
    pure
    returns (string memory)
  {
    return string(abi.encodePacked(baseUri, tokenId));
  }

  /**
   * @notice sets the base uri of the off-chain score API
   */
  function setBaseUri(string memory newBaseUri) public override onlyOwner {
    baseURI = newBaseUri;
  }

  function setOracle (address _oracle, bytes32 _jobId, uint256 _fee) public onlyOwner {
    oracle = _oracle;
    jobId = _jobId;
    fee = _fee;
  }

  /**
   * @notice Pauses the whole contract; used as emergency response in case a bug is detected. [OWNER_ONLY]
   */
  function pause() public onlyOwner {
    _pause();
  }

  /**
   * @notice unpauses the contract; resumes functionality. [OWNER_ONLY]
   */
  function unpause() public onlyOwner {
    _unpause();
  }
}