pragma solidity >=0.6.0 <0.9.0;

import "@openzeppelin/contracts/access/AccessControl.sol"; //https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol
import "./fixtures/modifiedOz/IERC721.sol";

import "hardhat/console.sol";

interface IDadaNFT is IERC721 {}

interface IDadaReserve {
    function transfer(
        address to,
        uint256 drawingId,
        uint256 printIndex
    ) external;

    function offerCollectibleForSaleToAddress(
        uint256 drawingId,
        uint256 printIndex,
        uint256 minSalePriceInWei,
        address toAddress
    ) external;

    function acceptBidForCollectible(
        uint256 drawingId,
        uint256 minPrice,
        uint256 printIndex
    ) external;

    function offerCollectibleForSale(
        uint256 drawingId,
        uint256 printIndex,
        uint256 minSalePriceInWei
    ) external;

    function withdrawOfferForCollectible(uint256 drawingId, uint256 printIndex)
        external;

    function withdraw() external;
}

interface IDadaCollectible {
    function drawingIdToCollectibles(uint256)
        external
        returns (
            uint256 drawingId,
            string memory checkSum,
            uint256 totalSupply,
            uint256 nextPrintIndexToAssign,
            bool allPrintsAssigned,
            uint256 initialPrice,
            uint256 initialPrintIndex,
            string memory collectionName,
            uint256 authorUId,
            string memory scarcity
        );

    function DrawingPrintToAddress(uint256) external returns (address);

    function alt_buyCollectible(uint256 drawingId, uint256 printIndex)
        external
        payable;

    function transfer(
        address to,
        uint256 drawingId,
        uint256 printIndex
    ) external returns (bool success);

    function makeCollectibleUnavailableToSale(
        address to,
        uint256 drawingId,
        uint256 printIndex,
        uint256 lastSellValue
    ) external;
}

/// @title DadaSale - Sale contract that interfaces with Reserve contract
/// @dev DadaSale must be granted Owner role on the reserve to transfer tokens
/// @author Isaac Patka
contract DadaSale is AccessControl {
    // Roles
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Reserve contract holding collectibles
    IDadaReserve dadaReserve;

    // Modified ERC20 contract
    IDadaCollectible dadaCollectible;

    // NFT interface for token swaps
    IERC721 dadaNFT;

    // Dada Multisig
    address dadaConservatory;

    enum ContractState {
        Swap,
        Discount,
        Whitelist
    }

    mapping(ContractState => bool) public state;

    // Swap data structures
    struct Drawing {
        uint256 DrawingId;
        uint256 PrintIndex;
    }

    mapping(uint256 => Drawing) public swapList; // tokenId => drawingId
    mapping(uint256 => bool) public swapReserved; // print => isReserved

    // Sale data structures

    // Mapping to keep track of prices for drawings in the discount purchase round
    mapping(uint256 => uint256) public discountPriceList;
    // Mapping to keep track of prices for drawings in the public purchase round
    mapping(uint256 => uint256) public priceList;
    // Mapping to keep track of whitelited addresses for the public sale
    mapping(address => bool) public whitelist;

    /// @dev constructor sets the interfaces to external contracts and grants admin and operator roles to deployer
    /// @param _dadaReserveAddress Contract holding the collectibles purchased from the ERC20 DadaCollectible contract
    /// @param _dadaCollectibleAddress ERC20 DadaCollectible contract
    /// @param _dadaNftAddress ERC721 DadaCollectible contract
    /// @param _dadaConservatoryAddress Dada managed multisig
    constructor(
        address _dadaReserveAddress,
        address _dadaCollectibleAddress,
        address _dadaNftAddress,
        address _dadaConservatoryAddress
    ) {
        dadaReserve = IDadaReserve(_dadaReserveAddress);
        dadaCollectible = IDadaCollectible(_dadaCollectibleAddress);
        dadaNFT = IERC721(_dadaNftAddress);
        dadaConservatory = _dadaConservatoryAddress;
        _setupRole(OPERATOR_ROLE, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Prevent ETH from getting stuck here
    receive() external payable {}

    // Operator role functions

    /// @dev Withdraw allows operator to retrieve ETH from the sale or sent directly to contract
    /// @param _to Address to receive the ETH
    function withdraw(address payable _to) external {
        require(hasRole(OPERATOR_ROLE, msg.sender), "!operator");
        (bool success, ) = _to.call{value: address(this).balance}("");
        require(success, "!transfer");
    }

    /// @dev Set the current active contract state
    ///  Paused: Operator functions are allowed but nothing else
    ///  Discount: Operator functions & discounted purchases enabled
    ///  Whitelist: Operator functions & public purchases enabled
    ///  Swap: Operator functions & NFT to ERC20 swaps enabled
    /// @param _stateEnabled bool array to enable different features: [swap, discount, whitelist]
    function setContractState(bool[3] calldata _stateEnabled) external {
        require(hasRole(OPERATOR_ROLE, msg.sender), "!operator");
        for (uint256 index = 0; index < _stateEnabled.length; index++) {
            state[ContractState(index)] = _stateEnabled[index];
        }
    }

    /// @dev Set the list of NFTs that can be swapped for specific prints
    ///  Reserved prints can not be purchased
    ///  Requires that the reserve contract has the print specified. Reverts if not
    /// @param _tokenDrawingPrint 2D array with [NFT tokenId, ERC20 DrawingId, ERC20 PrintIndex]
    function setSwapList(uint256[3][] calldata _tokenDrawingPrint, bool enabled)
        external
    {
        require(hasRole(OPERATOR_ROLE, msg.sender), "!operator");
        for (uint256 index = 0; index < _tokenDrawingPrint.length; index++) {
            if (enabled) {
                swapReserved[_tokenDrawingPrint[index][2]] = true;
                swapList[_tokenDrawingPrint[index][0]] = Drawing(
                    _tokenDrawingPrint[index][1],
                    _tokenDrawingPrint[index][2]
                );
            } else {
                swapReserved[_tokenDrawingPrint[index][2]] = false;
                delete swapList[_tokenDrawingPrint[index][0]];
            }
        }
    }

    /// @dev Set the price list for the discounted round by drawingId
    /// @param _drawingPrice 2D array with [ERC20 DrawingId, Price in ETH]
    function setDiscountPriceList(uint256[2][] calldata _drawingPrice)
        external
    {
        require(hasRole(OPERATOR_ROLE, msg.sender), "!operator");
        for (uint256 index = 0; index < _drawingPrice.length; index++) {
            discountPriceList[_drawingPrice[index][0]] = _drawingPrice[index][
                1
            ];
        }
    }

    /// @dev Set the price list for the public round by drawingId
    /// @param _drawingPrice 2D array with [ERC20 DrawingId, Price in ETH]
    function setPriceList(uint256[2][] calldata _drawingPrice) external {
        require(hasRole(OPERATOR_ROLE, msg.sender), "!operator");
        for (uint256 index = 0; index < _drawingPrice.length; index++) {
            priceList[_drawingPrice[index][0]] = _drawingPrice[index][1];
        }
    }

    /// @dev Set the whitelist status for specific buyers
    /// @param _buyers Array of buyer addresses
    /// @param _whitelisted State that applies to all buyers in this contract call
    function setWhitelist(address[] calldata _buyers, bool _whitelisted)
        external
    {
        require(hasRole(OPERATOR_ROLE, msg.sender), "!operator");
        for (uint256 index = 0; index < _buyers.length; index++) {
            whitelist[_buyers[index]] = _whitelisted;
        }
    }

    /// @dev Purchase a discounted drawing by a buyer with active allocations, during the discount phase
    /// @notice _tokenId can only be used once as a discount coupon or swapped for an ERC20
    /// @param _drawingId ERC20 drawing ID to purchase
    /// @param _printIndex ERC20 print index to purchase
    /// @param _tokenId ERC721 token ID to use as a discount coupon
    function purchaseDiscount(
        uint256 _drawingId,
        uint256 _printIndex,
        uint256 _tokenId
    ) external payable {
        require(state[ContractState.Discount], "!discount-state");

        // Retrieve printIndex reserved for this tokenId if swapped
        uint256 reservedPrintIndex = swapList[_tokenId].PrintIndex;

        // Ensure there is a reserved print
        require(swapReserved[reservedPrintIndex], "!swap-eligible");

        // Sender must send exact discounted price
        require(msg.value == discountPriceList[_drawingId], "!value");

        // Sender must own the specified tokenId
        require(dadaNFT.ownerOf(_tokenId) == msg.sender, "!eligible");

        // Prints that are reserved for swaps cannot be purchased by anyone
        require(!swapReserved[_printIndex], "reserved");

        // Mark this tokenID as used so it can't be used again for a discount or for a swap
        delete swapList[_tokenId];

        // Remove reservation on print index
        swapReserved[reservedPrintIndex] = false;
        
        // Manually set the last purchase price and seller in the ERC20 contract
        dadaReserve.transfer(address(this), _drawingId, _printIndex);
        dadaCollectible.makeCollectibleUnavailableToSale(
            address(this),
            _drawingId,
            _printIndex,
            discountPriceList[_drawingId]
        );
        dadaCollectible.transfer(msg.sender, _drawingId, _printIndex);
    }

    /// @dev Purchase a discounted drawing by a buyer on whitelist, during the whitelist phase
    /// @param _drawingId ERC20 drawing ID to purchase
    /// @param _printIndex ERC20 print index to purchase
    function purchaseWhitelist(uint256 _drawingId, uint256 _printIndex)
        external
        payable
    {
        require(state[ContractState.Whitelist], "!whitelist-state");

        // Sender must send exact price
        require(msg.value == priceList[_drawingId], "!value");

        // Sender must be on whitelist
        require(whitelist[msg.sender], "!whitelist");

        // Prints that are reserved for swaps cannot be purchased by anyone
        require(!swapReserved[_printIndex], "reserved");

        // Manually set the last purchase price and seller in the ERC20 contract
        dadaReserve.transfer(address(this), _drawingId, _printIndex);
        dadaCollectible.makeCollectibleUnavailableToSale(
            address(this),
            _drawingId,
            _printIndex,
            priceList[_drawingId]
        );
        dadaCollectible.transfer(msg.sender, _drawingId, _printIndex);
    }

    /// @dev Swap an NFT for an ERC20, during the swap phase
    /// @param _tokenId ERC721 tokenID to swap
    function swapToken(uint256 _tokenId) external {
        require(state[ContractState.Swap], "!swap-state");

        // Retrieve specific drawingId and Print to swap
        uint256 drawingId = swapList[_tokenId].DrawingId;
        uint256 printIndex = swapList[_tokenId].PrintIndex;

        // Ensure there is a reserved print
        require(swapReserved[printIndex], "!swap-eligible");

        // Ensure the reserve still owns this print
        require(
            dadaCollectible.DrawingPrintToAddress(printIndex) ==
                address(dadaReserve),
            "!available"
        );

        // Remove from the swap list
        delete swapList[_tokenId];
        swapReserved[printIndex] = false;

        // Transfer NFT to multisig
        dadaNFT.transferFrom(msg.sender, dadaConservatory, _tokenId);

        // Transfer ERC20 from reserve to swapper
        dadaReserve.transfer(msg.sender, drawingId, printIndex);
    }
}