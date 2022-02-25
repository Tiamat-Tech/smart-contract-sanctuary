// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "./ITrade.sol";
import './libraries/TransferHelper.sol';
import "hardhat/console.sol";

contract PublicTrade is ITrade, ReentrancyGuard, Ownable {
    using SafeMath for uint256;

    event TradeStatusChange(uint256 tradeId, bytes32 tradeType, bytes32 status, uint256 tradeAt);
    event NewOffer(bytes32 tradeType, uint256 tradeId, uint256 offerId, address participant, uint256 tradeAt);
    struct Trade {
        uint256 tradeId;
        address poster;
        NFTContract[] user0NFTs;
        ERC20Contract[] user0ERC20s;
        address refer;
        bytes32 status; // Open, Accepted, Cancelled
    }

    struct Offer {
        uint256 tradeId;
        address participant;
        NFTContract[] offerNFTs;
        ERC20Contract[] offerERC20s;
        bytes32 status; // Pending, Accepted, Cancelled
    }
    mapping(uint256 => Trade) private trades;
    mapping(uint256 => mapping(uint256 => Offer)) private offers;
    mapping (uint256 => uint256) private lastOfferId;
    uint256 private tradeCounter;
    address private manager;

    constructor(){
        tradeCounter = 0;
    }

    function getTradeCounter() external view returns (uint256){
        return tradeCounter;
    }

    function getAllTrades() external view returns (Trade[] memory) {
        Trade[] memory allTrades = new Trade[](tradeCounter);
        for (uint i = 0; i < tradeCounter; i++)
        {
            allTrades[i] = trades[i];
        }
        return allTrades;
    }

    function getTrade(uint256 _tradeId) external view returns(Trade memory) {
        Trade memory trade = trades[_tradeId];
        return trade;
    }


    function getOffer(uint256 _tradeId, uint256 _offerId) external view returns(Offer memory) {
        return offers[_tradeId][_offerId];
    }

    function getOffersByTradeId(uint256 _tradeId) external view returns(Offer[] memory) {
        Offer[] memory tOffers = new Offer[](lastOfferId[_tradeId]);
        for (uint i = 0; i < lastOfferId[_tradeId]; i++)
        {
            tOffers[i] = offers[_tradeId][i];
        }
        return tOffers;
    }

    function getAllOffers() external view returns (Offer[] memory) {
        uint256 allOfferCounts = 0;
        for (uint i = 0; i < tradeCounter; i++) {
            allOfferCounts += lastOfferId[i];
        }
        Offer[] memory allOffers = new Offer[](allOfferCounts);
        uint k = 0;
        for (uint i = 0; i < tradeCounter; i++) {
            for (uint j = 0; j < lastOfferId[i]; j++)
            {
                allOffers[k] = offers[i][j];
                k++;
            }
        }
        return allOffers;
    }

    function initManager(address _manager) public onlyOwner {
        manager = _manager;
    }

    function openTrade(
        NFTContract[] memory _user0NFTs,
        ERC20Contract[] memory _user0ERC20,
        address _poster,
        address _refer
    ) public onlyManager {
        for (uint8 i = 0; i < _user0NFTs.length; i++) {
            trades[tradeCounter].user0NFTs.push(NFTContract({
            _nft: _user0NFTs[i]._nft,
            _tokenId: _user0NFTs[i]._tokenId
            })
            );
        }
        for (uint8 j = 0; j < _user0ERC20.length; j++) {
            trades[tradeCounter].user0ERC20s.push(ERC20Contract({
            _erc20: _user0ERC20[j]._erc20,
            _amount: _user0ERC20[j]._amount
            })
            );
        }
        trades[tradeCounter].poster = _poster;
        trades[tradeCounter].refer = _refer;
        trades[tradeCounter].status = bytes32("Open");
        tradeCounter += 1;
        emit TradeStatusChange(tradeCounter - 1, bytes32("Public"), bytes32("Open"), block.timestamp);
    }

    function makeOffer(
        uint256 _tradeId,
        NFTContract[] memory _offerNFTs,
        ERC20Contract[] memory _offerERC20s,
        address _participant
    ) public onlyManager {
        for (uint8 i = 0; i < _offerNFTs.length; i++) {
            offers[_tradeId][lastOfferId[_tradeId]].offerNFTs.push(NFTContract({
                    _nft: _offerNFTs[i]._nft,
                    _tokenId: _offerNFTs[i]._tokenId
                })
            );
        }
        for (uint8 j = 0; j < _offerERC20s.length; j++) {
            offers[_tradeId][lastOfferId[_tradeId]].offerERC20s.push(ERC20Contract({
                    _erc20: _offerERC20s[j]._erc20,
                    _amount: _offerERC20s[j]._amount
                })
            );
        }
        offers[_tradeId][lastOfferId[_tradeId]].participant = _participant;
        offers[_tradeId][lastOfferId[_tradeId]].status = bytes32("Pending");
        lastOfferId[_tradeId] += 1;
        emit NewOffer(bytes32("Public"), _tradeId, lastOfferId[_tradeId] - 1, _participant, block.timestamp);
    }

    function acceptOffer(uint256 _tradeId, uint256 _offerId, address _recipient) public onlyManager {
        require(trades[_tradeId].status == bytes32("Open"), "Trade is not Open.");
        require(_recipient == trades[_tradeId].poster, "Offer can be accepted only by poster.");
        require(offers[_tradeId][_offerId].status == bytes32("Pending"), "Offer is not Open.");
        for(uint8 i = 0; i < trades[_tradeId].user0NFTs.length; i++)
        {
            address nftAddress = trades[_tradeId].user0NFTs[i]._nft;
            uint256 tokenId = trades[_tradeId].user0NFTs[i]._tokenId;
            require(_recipient == IERC721(nftAddress).ownerOf(tokenId),"Only owners can change this status");
            IERC721(nftAddress).transferFrom(_recipient, address(this), tokenId);
        }
        for(uint8 i = 0; i < trades[_tradeId].user0ERC20s.length; i++)
        {
            address erc20Address = trades[_tradeId].user0ERC20s[i]._erc20;
            uint256 amount = trades[_tradeId].user0ERC20s[i]._amount;
            require(amount <= IERC20(erc20Address).balanceOf(_recipient), "Not enough Token sent; check balance!");
            IERC20(erc20Address).transferFrom(_recipient, address(this), amount);
        }
        trades[_tradeId].status = bytes32("Accepted");
        emit TradeStatusChange(_tradeId, bytes32("Public"), bytes32("Accepted"), block.timestamp);
    }

    function executeOffer(
        address _recipient,
        address _commissionAddress,
        uint256 _tradeId,
        uint256 _offerId,
        uint256 _defaultFee,
        uint256 _referFee,
        uint256 _feeDivider) public onlyManager {
        require(trades[_tradeId].status == bytes32("Accepted"), "Trade is not accepted.");
        require(_recipient == offers[_tradeId][_offerId].participant, "Offer can be executed only by participant.");
        require(offers[_tradeId][_offerId].status == bytes32("Pending"), "Offer is not in Pending");
        uint256 feeToUse = _defaultFee;
        for(uint8 i = 0; i < offers[_tradeId][_offerId].offerNFTs.length; i++)
        {
            address nftAddress = offers[_tradeId][_offerId].offerNFTs[i]._nft;
            uint256 tokenId = offers[_tradeId][_offerId].offerNFTs[i]._tokenId;
            require(_recipient == IERC721(nftAddress).ownerOf(tokenId),"Only owners can change this status");
            IERC721(nftAddress).transferFrom(_recipient, trades[_tradeId].poster, tokenId);
        }
        for(uint8 i = 0; i < offers[_tradeId][_offerId].offerERC20s.length; i++)
        {
            address erc20Address = offers[_tradeId][_offerId].offerERC20s[i]._erc20;
            uint256 amount = offers[_tradeId][_offerId].offerERC20s[i]._amount;
            require(amount <= IERC20(erc20Address).balanceOf(_recipient), "Not enough Token sent; check balance!");
            if (_commissionAddress == address(0))
            {
                IERC20(erc20Address).transferFrom(_recipient, address(trades[_tradeId].poster), amount);
            } else {
                uint256 commissionAmount = amount.mul(feeToUse).div(_feeDivider);
                uint256 referCommission = commissionAmount.mul(_referFee).div(_feeDivider);
                IERC20(erc20Address).transferFrom(_recipient, address(trades[_tradeId].poster), amount.sub(commissionAmount));
                IERC20(erc20Address).transferFrom(_recipient, address(_commissionAddress), commissionAmount.sub(referCommission));
                IERC20(erc20Address).transferFrom(_recipient, address(trades[_tradeId].refer), referCommission);
            }
        }

        for (uint8 i = 0; i < trades[_tradeId].user0ERC20s.length; i++)
        {
            address erc20Address = trades[_tradeId].user0ERC20s[i]._erc20;
            uint256 amount = trades[_tradeId].user0ERC20s[i]._amount;
            IERC20(erc20Address).transfer(_recipient, amount);
        }
        for (uint8 i = 0; i < trades[_tradeId].user0NFTs.length; i++)
        {
            address nftAddress = trades[_tradeId].user0NFTs[i]._nft;
            uint256 tokenId = trades[_tradeId].user0NFTs[i]._tokenId;
            IERC721(nftAddress).transferFrom(address(this), _recipient, tokenId);
        }
        trades[_tradeId].status = bytes32("Closed");
        offers[_tradeId][_offerId].status = bytes32("Executed");
        emit TradeStatusChange(_tradeId, bytes32("Public"), bytes32("Accepted"), block.timestamp);
    }

    function cancelOffer(address _recipient, uint256 _tradeId, uint256 _offerId) public onlyManager {
        require(trades[_tradeId].status == bytes32("Accepted"), "Trade is not accepted.");
        require(_recipient == offers[_tradeId][_offerId].participant, "Offer can be canceled only by participant.");
        require(offers[_tradeId][_offerId].status == bytes32("Pending"), "Offer is not Pending.");
        for(uint8 i = 0; i < trades[_tradeId].user0NFTs.length; i++)
        {
            address nftAddress = trades[_tradeId].user0NFTs[i]._nft;
            uint256 tokenId = trades[_tradeId].user0NFTs[i]._tokenId;
            console.log("recipient: ", _recipient, IERC721(nftAddress).ownerOf(tokenId));
            IERC721(nftAddress).transferFrom(address(this), trades[_tradeId].poster, tokenId);
        }
        for(uint8 i = 0; i < trades[_tradeId].user0ERC20s.length; i++)
        {
            address erc20Address = trades[_tradeId].user0ERC20s[i]._erc20;
            uint256 amount = trades[_tradeId].user0ERC20s[i]._amount;
            IERC20(erc20Address).transfer(trades[_tradeId].poster, amount);
        }
        trades[_tradeId].status = bytes32("Open");
        offers[_tradeId][_offerId].status = bytes32("Canceled");
        emit TradeStatusChange(_tradeId, bytes32("Public"), bytes32("Canceled"), block.timestamp);
    }

    function cancelTrade(address _recipient, uint256 _tradeId) public onlyManager {
        require(_recipient == trades[_tradeId].poster, "Trade can be cancelled only by poster.");
        require(trades[_tradeId].status == bytes32("Open"), "Trade is not Open.");
        trades[_tradeId].status = bytes32("Cancelled");
        emit TradeStatusChange(_tradeId, bytes32("Public"), bytes32("Cancelled"), block.timestamp);
    }

    modifier onlyManager() {
        require(manager == _msgSender(), "Ownable: caller is not the manager");
        _;
    }
}