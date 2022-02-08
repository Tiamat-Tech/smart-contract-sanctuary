// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

import './IWhitelist.sol';
import './TimeContract.sol';


contract PropyAuction is Ownable, TimeContract {
    using SafeERC20 for IERC20;
    using Address for *;

    uint public constant BID_DEADLINE_EXTENSION = 15 minutes;
    uint public constant ETH_UNLOCK_DELAY = 90 days;
    uint public immutable start;
    uint public immutable minBid;
    uint public immutable deadline;
    uint public immutable finalizeTimeout;
    uint public immutable nftId;
    IERC721 public immutable nft;
    IWhitelist public immutable whitelist;
    uint32 public deadlineExtended;
    bool public finalized;

    mapping(address => uint) public bids;

    event TokensRecovered(address token, address to, uint value);
    event ETHRecovered(address to, uint value);
    event Bid(address user, uint value);
    event Claimed(address user, uint value);
    event Finalize(address winner, uint winnerBid);

    modifier onlyWhitelisted() {
        require(whitelist.whitelist(_msgSender()), "Auction: User is not whitelisted");
        _;
    }

    constructor(
        address _owner,
        uint _start,
        uint32 _deadline,
        uint _minBid,
        uint _finalizeTimeout,
        uint _nftId,
        IERC721 _nft,
        IWhitelist _whitelist
    ) {
        require(notPassed(_start), 'Auction: Start should be more than current time');
        require(_deadline > _start, 'Auction: Deadline should be more than start time');

        _transferOwnership(_owner);
        start = _start;
        deadline = _deadline;
        deadlineExtended = _deadline;
        minBid = _minBid;
        finalizeTimeout = _finalizeTimeout;
        nftId = _nftId;
        nft = _nft;
        whitelist = _whitelist;
    }

    function bid() external payable {
        _bid();
    }

    receive() external payable {
        _bid();
    }

    function _bid() internal onlyWhitelisted {
        require(msg.value > 0, 'Auction: Zero bid not allowed');
        require(passed(start), 'Auction: Not started yet');

        uint bidDeadline = getCurrentDeadline();

        require(notPassed(bidDeadline), 'Auction: Already finished');

        if (passed(bidDeadline - BID_DEADLINE_EXTENSION)) {
            deadlineExtended = uint32(block.timestamp + BID_DEADLINE_EXTENSION);
        }

        uint newBid = bids[_msgSender()] + msg.value;
        require(newBid >= minBid, 'Auction: Can`t bid less than allowed');

        bids[_msgSender()] = newBid;
        emit Bid(_msgSender(), newBid);
    }

    function finalize(address payable _treasury, address _winner) external onlyOwner {
        uint deadlineFinalized = getCurrentDeadline();
        require(!finalized, 'Auction: Already finalized');
        require(passed(deadlineFinalized), 'Auction: Not finished yet');
        require(notPassed(deadlineFinalized + finalizeTimeout), 'Auction: Finalize expired, auction cancelled');
        uint winnerBid = bids[_winner];
        require(winnerBid > 0, 'Auction: Winner did not bid');

        bids[_winner] = 0;
        finalized = true;
        nft.safeTransferFrom(nft.ownerOf(nftId), _winner, nftId);
        _treasury.sendValue(winnerBid);

        emit Finalize(_winner, winnerBid);
    }

    function claim() external {
        uint deadlineFinalized = getCurrentDeadline();
        require(finalized || passed(deadlineFinalized + finalizeTimeout), 'Auction: Not finalized yet');
        uint userBid = bids[_msgSender()];
        require(userBid > 0, 'Auction: Nothing to claim');

        bids[_msgSender()] = 0;
        payable(_msgSender()).sendValue(userBid);
        emit Claimed(_msgSender(), userBid);
    }


    function recoverETH(address payable _to) external onlyOwner {
        require(passed(getCurrentDeadline() + finalizeTimeout + ETH_UNLOCK_DELAY), 'Auction: ETH unlock delay did not pass yet');
        uint balance = address(this).balance;
        _to.sendValue(balance);
        emit ETHRecovered(_to, balance);
    }

    function recoverTokens(IERC20 _token, address _destination) external onlyOwner {
        require(_destination != address(0), 'Auction: Zero address not allowed');

        uint balance = _token.balanceOf(address(this));
        if (balance > 0) {
            _token.safeTransfer(_destination, balance);
            emit TokensRecovered(address(_token), _destination, balance);
        }
    }

    function getCurrentDeadline() public view returns(uint) {
        return notPassed(deadline) ? deadline : uint(deadlineExtended);
    }
}