pragma solidity 0.8.4;

import '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';

import '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import '@openzeppelin/contracts/access/Ownable.sol';

//FOR TESTING PURPOSES
import "@openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol";
import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import 'hardhat/console.sol';

contract Market is ERC1155Holder, Ownable {
    IERC1155 public erc1155;
    IERC20 public erc20;

    uint256 public offerCounter = 0;
    uint256 public maxAmountToSell = 1;
    address public addressToSendFee;

    uint256 public feeNuminator = 145;
    uint256 public feeDenuminator = 1000;

    struct Offer {
        uint256 tokenId;
        uint256 price;
        address seller;
        bool status;
    }

    mapping(uint256 => Offer) public offers;

    event OfferCreation(
        address indexed who,
        uint256 indexed id,
        uint256 price,
        uint256 offerId
    );
    event BuyingAnOffer(
        address indexed who,
        uint256 indexed id,
        uint256 price,
        uint256 offerId
    );
    event OfferDeletion(
        address who,
        uint256 indexed id,
        uint256 indexed offerId
    );

    constructor(
        address TOKEN_ERC1155,
        address TOKEN_ERC20,
        address wallet
    ) {
        erc1155 = IERC1155(TOKEN_ERC1155);
        erc20 = IERC20(TOKEN_ERC20);

        addressToSendFee = wallet;
    }

    function makeAnOffer(uint256 tokenId, uint256 price) external {
        require(
            erc1155.balanceOf(msg.sender, tokenId) >= maxAmountToSell,
            "You don't have enough tokens."
        );

        erc1155.safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            maxAmountToSell,
            ''
        );
        offers[offerCounter] = Offer({
            tokenId: tokenId,
            price: price,
            seller: msg.sender,
            status: true
        });

        offerCounter += 1;
        emit OfferCreation(msg.sender, tokenId, price, offerCounter);
    }

    function buy(uint256 offerNumber) external {
        uint256 fee;

        require(offers[offerNumber].status != false, "It's already sold");
        require(
            erc20.balanceOf(msg.sender) >= offers[offerNumber].price,
            "You don't have enough money."
        );
        require(
            erc20.transferFrom(
                msg.sender,
                address(this),
                offers[offerNumber].price
            ),
            'Transfer has been failed!'
        );
        offers[offerNumber].status = false;

        erc1155.safeTransferFrom(
            address(this),
            msg.sender,
            offers[offerNumber].tokenId,
            maxAmountToSell,
            ''
        );
        erc20.transfer(addressToSendFee, _calculateFee(offers[offerNumber].price));

        emit BuyingAnOffer(
            msg.sender,
            offers[offerNumber].tokenId,
            offers[offerNumber].price,
            offerNumber
        );
    }

    function deleteAnOffer(uint256 offerNumber) external {
        require(
            offers[offerNumber].seller == address(msg.sender),
            'You are not the owner of an order.'
        );
        require(offers[offerNumber].status, 'Your item has been sold.');
        offers[offerNumber].status = false;

        erc1155.safeTransferFrom(
            address(this),
            msg.sender,
            offers[offerNumber].tokenId,
            maxAmountToSell,
            ''
        );

        emit OfferDeletion(
            msg.sender,
            offers[offerNumber].tokenId,
            offerNumber
        );
    }

    function getAllOffers()
        external
        view
        onlyOwner
        returns (
            uint256[] memory ids,
            uint256[] memory prices,
            address[] memory addrs,
            bool[] memory statuses
        )
    {
        uint256[] memory ids_ = new uint256[](offerCounter);
        uint256[] memory prices_ = new uint256[](offerCounter);
        address[] memory addrs_ = new address[](offerCounter);
        bool[] memory statuses_ = new bool[](offerCounter);

        for (uint256 i = 0; i < offerCounter; i++) {
            ids_[i] = offers[i].tokenId;
            prices_[i] = offers[i].price;
            addrs_[i] = offers[i].seller;
            statuses_[i] = offers[i].status;
        }

        return (ids_, prices_, addrs_, statuses_);
    }

    function _calculateFee(uint256 bet) internal view returns (uint256 fee) {
    fee = (bet * feeNuminator) / feeDenuminator;

    return fee;
    }
}