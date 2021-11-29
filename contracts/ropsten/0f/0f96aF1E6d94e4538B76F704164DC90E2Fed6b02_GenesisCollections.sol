// SPDX-License-Identifier: MIT

pragma solidity 0.8.3;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "./token/ERC20/IERC20.sol";
import "./token/ERC20/SafeERC20.sol";
import "./token/ERC1155/ERC1155.sol";
import "./token/ERC1155/IERC1155.sol";
import "./utils/Ownable.sol";

import "hardhat/console.sol";

/**
 * @notice Allows each token to be associated with a creator.
 */
contract GenesisCollections is Ownable {
    using SafeERC20 for IERC20;

    AggregatorV3Interface internal priceFeed;

    mapping(uint256 => address) public idExists;

    address public usdt;
    address public tokenCommon;
    address public tokenRare;
    address public tokenGold;
    address private communityWallet;

    uint256 public tokenPriceCommon = 77 ether / 1000; // in ETH 0.077 = USDT 326.76952
    uint256 public tokenPriceRare = 29 ether / 100; // in ETH 0.29 = USDT 1230.6904
    uint256 public tokenPriceGold = 99 ether / 100; // in ETH 0.99 = USDT 4201.3224

    uint256 public limitToMintTokenCommon = 1888;
    uint256 public limitToMintTokenRare = 999;
    uint256 public limitToMintTokenGold = 333;

    uint256 public totalSupplyTokenCommon = 0;
    uint256 public totalSupplyTokenRare = 0;
    uint256 public totalSupplyTokenGold = 0;

    constructor(address _usdt, address[] memory _ids, address _communityWallet) {
        usdt = _usdt;

        require(_ids.length == 3, "GenesisCollections: erc1155 addresses are not setup");
        tokenCommon = _ids[0];
        tokenRare = _ids[1];
        tokenGold = _ids[2];
        for (uint256 i = 0; i < _ids.length; i++) {
            idExists[i] = _ids[i];
        }

        priceFeed = AggregatorV3Interface(
            0x8A753747A1Fa494EC906cE90E9f37563A8AF630e
        ); // Chainlink Eth/Usd Rinkeby

        // require(_communityWallet == type(address), "GenesisCollections: community wallet is not setup");
        communityWallet = _communityWallet;
    }

    function buyTokens(
        uint256 _amount,
        address _paymentToken,
        uint256 _tokenId
    ) public {
        require(_paymentToken == usdt, "GenesisCollections: unsuportted token");
        require(
            idExists[_tokenId] == tokenCommon ||
                idExists[_tokenId] == tokenRare ||
                idExists[_tokenId] == tokenGold,
            "GenesisCollections: this tokenId has not supported"
        );
        require(_amount < 30, "GenesisCollections: max amount tokens pre transaction are 30");

        (, int256 price, , , ) = priceFeed.latestRoundData();

        uint256 priceInToken = 0;
        address token;
        if (idExists[_tokenId] == tokenCommon) {
            token = tokenCommon;
            require(
                totalSupplyTokenCommon + _amount <= limitToMintTokenCommon,
                "GenesisCollections: not enough Common tokens in contract"
            );
            totalSupplyTokenCommon += _amount;
            priceInToken =
                ((_amount * tokenPriceCommon) * uint256(price)) /
                10**20;
        }
        if (idExists[_tokenId] == tokenRare) {
            token = tokenRare;
            require(
                totalSupplyTokenRare + _amount <= limitToMintTokenRare,
                "GenesisCollections: not enough Rare tokens in contract"
            );
            totalSupplyTokenRare += _amount;
            priceInToken =
                ((_amount * tokenPriceRare) * uint256(price)) /
                10**20;
        }
        if (idExists[_tokenId] == tokenGold) {
            token = tokenGold;
            require(
                totalSupplyTokenGold + _amount <= limitToMintTokenGold,
                "GenesisCollections: not enough Rare tokens in contract"
            );
            totalSupplyTokenGold += _amount;
            priceInToken =
                ((_amount * tokenPriceGold) * uint256(price)) /
                10**20;
        }

        require(priceInToken > 0, "GenesisCollections: insufficient amount of token price");
        IERC20(_paymentToken).safeTransferFrom(
            msg.sender,
            communityWallet,
            priceInToken
        );

        IERC1155(token).mint(msg.sender, _tokenId, _amount, "");
    }

    function increaseMintTokenCommon(uint256 _amount) public onlyOwner {
        limitToMintTokenCommon += _amount;
    }

    function increaseMintTokenRare(uint256 _amount) public onlyOwner {
        limitToMintTokenRare += _amount;
    }

    function increaseMintTokenGold(uint256 _amount) public onlyOwner {
        limitToMintTokenGold += _amount;
    }

    function setCommunityWallet(address _communityWallet) public onlyOwner {
        communityWallet = _communityWallet;
    }
}