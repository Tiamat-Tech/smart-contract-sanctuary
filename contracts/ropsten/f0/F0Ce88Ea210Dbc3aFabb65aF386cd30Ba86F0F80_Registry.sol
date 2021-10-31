// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 *@title Morphware Registry: Holds contract, auction and version information
 *@notice contains methods to set contract addresses, auction durations and client versions
 */

contract Registry is Ownable {

    address public auctionContract;
    string public clientVersion;
    address public jobContract;
    uint public biddingDuration;
    uint public revealDuration;

  /**
   * @notice Constructor
   * @param _auctionContract address of Morphware Auction contract
   * @param _clientVersion string of current Morphware client version
   * @param _jobContract address of Morphware Job contract
   * @param _biddingDuration duration amount for an auction
   * @param _revealDuration duation amount for reveal period after auction end
   */

    constructor(
        address _auctionContract,
        string memory _clientVersion,
        address _jobContract,
        uint _biddingDuration,
        uint _revealDuration
    ) {
        auctionContract = _auctionContract;
        clientVersion = _clientVersion;
        jobContract = _jobContract;
        biddingDuration = _biddingDuration;
        revealDuration = _revealDuration;
    }


  /**
   * @notice sets auction contract address
   * @param _auctionAddress new auction contract address
   */

    function setAuctionContract(address _auctionAddress) public onlyOwner {
        auctionContract = _auctionAddress;
    }

  /**
   * @notice sets job contract address
   * @param _jobAddress new job contract address
   */

    function setJobContract(address _jobAddress) public onlyOwner {
        jobContract = _jobAddress;
    }

  /**
   * @notice sets client version
   * @param _clientVersion new client version
   */

    function setClientVersion(string memory _clientVersion) public onlyOwner {
        clientVersion = _clientVersion;
    }

  /**
   * @notice sets bidding period duration
   * @param _biddingDuration new bidding duration
   */

    function setBiddingDuration(uint _biddingDuration) public onlyOwner {
        biddingDuration = _biddingDuration;
    }

  /**
   * @notice sets reveal period duration
   * @param _revealDuration new reveal duration
   */

    function setRevealDuration(uint _revealDuration) public onlyOwner {
        revealDuration = _revealDuration;
    }
    
}