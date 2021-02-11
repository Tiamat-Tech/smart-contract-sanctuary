// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "openzeppelin-solidity/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-solidity/contracts/access/Ownable.sol";
import "openzeppelin-solidity/contracts/math/SafeMath.sol";

contract VipPaw is ERC721, Ownable
{
    using SafeMath for uint256;

    uint256 public tokenPrice;
    uint256 public softCapInTokens;
    uint256 public moneyCollected;

    uint256 private lastTokenId;
    uint256 public maxSupply;

    bool public isOpenedCrowdsale;
    bool public isClosedCrowdsaleOwner;

    string public defaultTokenURI;

    uint256 public maxTokensToBuyInTx = 100;

    bool public isOpenTransfers = false;

    address payable feeAddress;

    event TokensPurchased(
        address user,
        uint256 count,
        uint256 timestamp
    );

    constructor(
        string memory name,
        string memory symbol,
        uint256 _tokenPrice,
        uint256 _softCapInTokens,
        uint256 _maxSupply,
        uint256 _maxTokensToBuyInTx,
        address payable _feeAddress
    )
        ERC721(name, symbol)
    {
        require(
            _softCapInTokens <= _maxSupply,
            "VipPaw: Wrong soft cap"
        );

        tokenPrice = _tokenPrice;
        softCapInTokens = _softCapInTokens;
        maxSupply = _maxSupply;
        maxTokensToBuyInTx = _maxTokensToBuyInTx;
        feeAddress = _feeAddress;
    }

    function setBaseUri(string memory newBaseUri) external onlyOwner
    {
        _setBaseURI(newBaseUri);
    }

    function setTokenURI(uint256 tokenId, string memory newTokenUri) external onlyOwner
    {
        _setTokenURI(tokenId, newTokenUri);
    }

    function setDefaultTokenURI(string memory newDefaultTokenUri) external onlyOwner
    {
        defaultTokenURI = newDefaultTokenUri;
    }

    function setMaxTokensToBuyInTx(uint256 newMax) external onlyOwner
    {
        maxTokensToBuyInTx = newMax;
    }

    function openTransfers() external onlyOwner
    {
        require(
            isOpenTransfers == false,
            "VipPaw: Transfers is already opened"
        );
        isOpenTransfers = true;
    }

    function openCrowdsale() external onlyOwner
    {
        require(
            isOpenedCrowdsale == false,
            "VipPaw: Crowdsale is already opened"
        );
        isOpenedCrowdsale = true;
    }

    function closeCrowdsale() external onlyOwner
    {
        require(
            isClosedCrowdsale() == false,
            "VipPaw: Crowdsale is already closed"
        );
        require(
            isOpenedCrowdsale == true,
            "VipPaw: Crowdsale is not opened yet"
        );
        isClosedCrowdsaleOwner = true;
    }

    function buyToken(uint256 count) external payable
    {
        require(
            isOpenedCrowdsale == true,
            "VipPaw: Crowdsale is not opened yet"
        );
        require(
            isClosedCrowdsale() == false,
            "VipPaw: Crowdsale is already closed"
        );
        require(
            count <= maxTokensToBuyInTx,
            "VipPaw: count must be not bigger than maxTokensToBuyInTx"
        );

        address sender = _msgSender();
        uint256 rawAmount = msg.value;

        require(
            count > 0 && count <= maxSupply.sub(lastTokenId),
            "VipPaw: Wrong amount of tokens to purchase"
        );
        require(
            rawAmount == tokenPrice.mul(count),
            "VipPaw: Wrong amount of money"
        );

        for(uint256 token = 0; token < count; token = token.add(1))
        {
            // mint token
            _mint(sender, lastTokenId);

            _setTokenURI(lastTokenId, defaultTokenURI);

            lastTokenId = lastTokenId.add(1);
        }

        uint256 fee = rawAmount.mul(5).div(100);
        feeAddress.transfer(fee);

        moneyCollected = moneyCollected.add(rawAmount.sub(fee));

        emit TokensPurchased(sender, count, block.timestamp);
    }

    function withdraw() external onlyOwner
    {
        require(
            isClosedCrowdsale() == true,
            "VipPaw: Crowdsale is not closed"
        );
        require(
            isRefund() == false,
            "VipPaw: Owner can not withdraw when it is refund"
        );
        uint256 amountToReturn = moneyCollected;
        require(
            amountToReturn > 0,
            "VipPaw: Nothing to return"
        );
        payable(owner()).transfer(amountToReturn);
        moneyCollected = 0;
    }

    function burnTokensToRefund(uint256 count) external
    {
        require(
            isClosedCrowdsale() == true,
            "VipPaw: Crowdsale is not closed"
        );
        require(
            isRefund() == true,
            "VipPaw: Can not refund"
        );
        require(
            count <= maxTokensToBuyInTx,
            "VipPaw: count must be not bigger than maxTokensToBuyInTx"
        );
        address payable sender = _msgSender();
        uint256 len = balanceOf(sender);
        require(
            len > 0,
            "VipPaw: Need to have vip paw cards to refund"
        );

        uint256 amountToBurn;
        if (count == 0)
            amountToBurn = len;
        else
            amountToBurn = count;
        require(
            len >= count,
            "VipPaw: Does not have this much tokens"
        );

        uint256 amountToRefund;
        uint256 tokenId;
        for(uint256 ind = 0; ind < amountToBurn; ind = ind.add(1))
        {
            tokenId = tokenOfOwnerByIndex(sender, 0);

            _burn(tokenId);
        }

        amountToRefund = tokenPrice.mul(amountToBurn).mul(95).div(100);
        moneyCollected = moneyCollected.sub(amountToRefund);

        sender.transfer(amountToRefund);
    }

    function isClosedCrowdsale() public view returns(bool)
    {
        if (isOpenedCrowdsale == false)
            return true;
        else if (isClosedCrowdsaleOwner == false)
        {
            if (lastTokenId >= maxSupply)
                return true;
            else
                return false;
        }
        else
            return true;
    }

    function isRefund() public view returns(bool)
    {
        if (isOpenedCrowdsale == false)
            return false;
        else if (isClosedCrowdsaleOwner == false)
        {
            require(
                lastTokenId >= maxSupply,
                "VipPaw: Crowdsale is not ended"
            );
            return false;
        }
        else
        {
            if (lastTokenId >= softCapInTokens)
                return false;
            else
                return true;
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal virtual override
    {
        if (from == address(0) || to == address(0))
            return;
        require(
            isOpenTransfers == true,
            "VipPaw: Transfers is not opened yet"
        );
    }
}