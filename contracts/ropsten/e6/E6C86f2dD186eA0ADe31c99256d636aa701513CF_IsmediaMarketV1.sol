// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./zeppelin/Pausable.sol";
import "./zeppelin/Ownable.sol";
import "./zeppelin/IERC721.sol";
import "./zeppelin/IERC1155.sol";

contract IsmediaMarketV1 is Pausable, Ownable {

    event Purchase(
        address indexed buyer,
        address indexed seller,
        uint256 indexed tokenId,
        uint256 saleId,
        address tokenContract,
        uint8 tokenType
    );

    event SaleCreated(
        address indexed seller,
        uint256 indexed tokenId,
        uint256 saleId,
        address tokenContract,
        uint8 tokenType
    );

    event SaleCancelled(
        address indexed seller,
        uint256 indexed tokenId,
        address tokenContract,
        uint8 tokenType
    );

    enum SaleStatus {
        Pending,
        Active,
        Complete,
        Canceled,
        Timeout
    }

    enum TokenType {
        ERC721,
        ERC1155
    }

    struct TokenSale {
        address seller;
        uint256 tokenId;
        uint256 unitPrice;
        uint256 quantity;
        uint256 start;
        uint256 end;
        TokenType tokenType;
        bool cancelled;
    }

    IERC721 public erc721;
    IERC1155 public erc1155;
    mapping(uint256 => TokenSale) public sales;
    uint256 public saleCounter = 0;

    constructor(address erc721Address, address erc1155Address) {
        erc721 = IERC721(erc721Address);
        erc1155 = IERC1155(erc1155Address);
        require(erc721.supportsInterface(type(IERC721).interfaceId), "Invalid ERC721");
        require(erc1155.supportsInterface(type(IERC1155).interfaceId), "Invalid ERC1155");
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function tokenFromType(uint8 tokenType) public view returns(address) {
        if(tokenType == uint8(TokenType.ERC1155)) {
            return address(erc1155);
        } else if(tokenType == uint8(TokenType.ERC721)) {
            return address(erc721);
        }
        revert("Invalid token type");
    }

    function buy(uint256 saleId, uint256 quantity) public payable whenNotPaused() {
        TokenSale storage sale = sales[saleId];
        uint256 totalPrice = sale.unitPrice * quantity;
        require(msg.value >= totalPrice, "Payment low");
        require(quantity <= sale.quantity, "Quantity high");
        require(saleStatus(saleId) == uint8(SaleStatus.Active), "Sale inactive");

        sale.quantity -= quantity;
        address tokenAddress = tokenFromType(uint8(sale.tokenType));

        if(sale.tokenType == TokenType.ERC721) {
            erc721.safeTransferFrom(sale.seller, msg.sender, sale.tokenId);
        } else {
            erc1155.safeTransferFrom(sale.seller, msg.sender, sale.tokenId, quantity, "");
        }
        payable(sale.seller).transfer(totalPrice);
        if(msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
        emit Purchase(
            msg.sender,
            sale.seller,
            sale.tokenId,
            saleId,
            tokenAddress,
            uint8(sale.tokenType)
        );
    }

    function _post(
        uint256 tokenId,
        uint256 unitPrice,
        uint256 quantity,
        uint256 start,
        uint256 end,
        TokenType tokenType
    ) private {
        uint256 saleId = saleCounter;
        TokenSale storage sale = sales[saleId];
        address tokenAddress = tokenFromType(uint8(tokenType));

        if(tokenType == TokenType.ERC721) {
            require(msg.sender == erc721.ownerOf(tokenId), "Not token owner");
            require(erc721.getApproved(tokenId) == address(this), "Not approved");
        } else {
            require(erc1155.balanceOf(msg.sender, tokenId) >= quantity, "Not enough tokens");
            require(erc1155.isApprovedForAll(msg.sender, address(this)), "Not approved");
        }
        sale.seller = msg.sender;
        sale.tokenId = tokenId;
        sale.unitPrice = unitPrice;
        sale.quantity = quantity;
        sale.tokenType = tokenType;
        sale.start = start;
        sale.end = end;
        sale.cancelled = false;

        saleCounter += 1;

        emit SaleCreated(
            msg.sender,
            tokenId,
            saleId,
            tokenAddress,
            uint8(tokenType)
        );
    }

    function postERC1155(uint256 tokenId, uint256 unitPrice, uint256 quantity, uint256 start, uint256 end) public whenNotPaused() {
        _post(tokenId, unitPrice, quantity, start, end, TokenType.ERC1155);
    }

    function postERC721(uint256 tokenId, uint256 unitPrice, uint256 start, uint256 end) public whenNotPaused() {
        _post(tokenId, unitPrice, 1, start, end, TokenType.ERC721);
    }

    function cancel(uint256 saleId) public whenNotPaused() {
        TokenSale storage sale = sales[saleId];
        require(sale.seller == msg.sender, "Only sale owner");
        require(saleStatus(saleId) == uint8(SaleStatus.Active), "Sale inactive");

        address tokenAddress = tokenFromType(uint8(sale.tokenType));

        sale.cancelled = true;

        emit SaleCancelled(
            sale.seller,
            sale.tokenId,
            tokenAddress,
            uint8(sale.tokenType)
        );
    }

    function saleStatus(uint256 saleId) public view returns(uint8) {
        TokenSale storage sale = sales[saleId];
        if(sale.cancelled) {
            return uint8(SaleStatus.Canceled);
        }
        if(sale.quantity == 0) {
            return uint8(SaleStatus.Complete);
        }
        if(sale.end != 0 && block.timestamp > sale.end) {
            return uint8(SaleStatus.Timeout);
        }
        if(sale.start != 0 && block.timestamp < sale.start) {
            return uint8(SaleStatus.Pending);
        }
        return uint8(SaleStatus.Active);
    }
}