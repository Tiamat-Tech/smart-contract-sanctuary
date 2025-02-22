// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import "hardhat/console.sol";

// TODO: check against https://swcregistry.io/
// TODO: Use automatic ETH <-> WETH conversion from uniswap-v2-periphery
// TODO: Optimize contract storage by removing filled offers, withdrawn offers, withdrawn positions? (- indexes might change)
contract Coliquidity is Ownable {
    // NOTE: Contract functions use Uniswap-style error codes (shorthands like "WEXP", "RAMP"). The error codes should be converted to human-readable error messages in UI.
    // NOTE: Contract functions protect against reentrancy by setting protection status before calling external contracts

    struct Offer {
        address maker;
        address makerToken;
        uint makerAmount;
        address taker; // address of a taker that could create a position from this offer (if zero address - anybody can create)
        address[] takerTokens; // addresses of tokens at the other side of the pool (allows to offer coliquidity for multiple token pairs)
        bool reinvest;
        uint lockedUntil; // UNIX timestamp
    }

    struct IndexedOffer {
        uint index;
        Offer offer;
    }

    struct Position {
        uint offerIndex;
        address maker;
        address taker;
        address makerToken; // SHLD, BULL, LINK, ...
        address takerToken; // USDT, WETH, WBTC, ...
        uint makerAmount; // needed to calculate the fee
        uint takerAmount; // needed to calculate the fee
        uint liquidityAmount;
        uint lockedUntil; // UNIX timestamp
    }

    struct IndexedPosition {
        uint index;
        Position position;
    }

    Offer[] public offers;
    Position[] public positions;

    uint public feeNumerator = 1;
    uint public feeDenominator = 100;

    // Store the factory address to save gas on external call to the router
    address public immutable router;
    address public immutable factory;
    address public immutable WETH;

    event CreateOffer(address indexed sender, uint indexed offerIndex);
    event CreatePosition(address indexed sender, uint indexed offerIndex, uint indexed positionIndex);
    event WithdrawOffer(address indexed sender, uint indexed offerIndex);
    event WithdrawPosition(address indexed sender, uint indexed offerIndex, uint indexed positionIndex);

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'Coliquidity: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    constructor(address _router, address _factory, address _WETH) {
        router = _router;
        factory = _factory;
        WETH = _WETH;
    }

    // only accept ETH via fallback from the WETH contract
    receive() external payable {
        assert(msg.sender == WETH);
    }

    function setFee(uint _feeNumerator, uint _feeDenominator) public onlyOwner {
        require(_feeNumerator > 0, "Coliquidity: SFNZ");
        require(_feeDenominator > 0, "Coliquidity: SFDZ");
        feeNumerator = _feeNumerator;
        feeDenominator = _feeDenominator;
    }

    function createOffer(address makerToken, uint makerAmount, address taker, address[] calldata takerTokens, bool reinvest, uint lockedUntil) lock public {
        require(makerToken != address(0), "Coliquidity: COTNZ");
        require(makerAmount > 0, "Coliquidity: COAGZ");
        require(takerTokens.length > 0, "Coliquidity: COPLG");
        require(lockedUntil == 0 || lockedUntil > block.timestamp, "Coliquidity: COLBT");
        // allow taker address to be zero (anybody can take the offer)
        TransferHelper.safeTransferFrom(makerToken, msg.sender, address(this), makerAmount);
        offers.push(
            Offer({maker : msg.sender, makerToken : makerToken, makerAmount : makerAmount, taker : taker, takerTokens : takerTokens, reinvest : reinvest, lockedUntil : lockedUntil})
        );
        emit CreateOffer(msg.sender, offers.length - 1);
    }

    function createPosition(uint offerIndex, address takerToken, uint makerAmountDesired, uint takerAmountDesired, uint makerAmountMin, uint takerAmountMin, uint deadline) lock public {
        Offer storage offer = offers[offerIndex];
        // NOTE: _pairingToken is validated within addLiquidity call by UniswapV2Library
        // NOTE: _*Amount* are validated within addLiquidity call by UniswapV2Library
        // NOTE: _deadline is validated within addLiquidity call by ensure modifier
        require(offer.taker == address(0) || offer.taker == msg.sender, "Coliquidity: CPAGD");
        TransferHelper.safeTransferFrom(takerToken, msg.sender, address(this), takerAmountDesired);
        IERC20(offer.makerToken).approve(router, makerAmountDesired);
        IERC20(takerToken).approve(router, takerAmountDesired);
        (uint makerAmountDeposited, uint takerAmountDeposited, uint liquidityAmountReceived) = IUniswapV2Router02(router).addLiquidity(
            offer.makerToken,
            takerToken,
            makerAmountDesired,
            takerAmountDesired,
            makerAmountMin,
            takerAmountMin,
            address(this),
            deadline
        );
        offer.makerAmount -= makerAmountDeposited;
        TransferHelper.safeTransfer(takerToken, msg.sender, takerAmountDesired - takerAmountDeposited);
        positions.push(
            Position({offerIndex : offerIndex, maker : offer.maker, taker : msg.sender, makerToken : offer.makerToken, takerToken : takerToken, makerAmount : makerAmountDeposited, takerAmount : takerAmountDeposited, liquidityAmount : liquidityAmountReceived, lockedUntil : offer.lockedUntil})
        );
        emit CreatePosition(msg.sender, offerIndex, positions.length - 1);
    }

    function withdrawOffer(uint offerIndex) lock public {
        Offer storage offer = offers[offerIndex];
        require(offer.maker == msg.sender, "Coliquidity: WOMES");
        require(offer.lockedUntil <= block.timestamp, "Coliquidity: WOLLT");
        require(offer.makerAmount > 0, "Coliquidity: WOMAZ");
        uint makerAmount = offer.makerAmount;
        offer.makerAmount = 0;
        TransferHelper.safeTransfer(offer.makerToken, offer.maker, makerAmount);
        emit WithdrawOffer(msg.sender, offerIndex);
    }

    function withdrawPosition(uint positionIndex, uint liquidityAmount, uint makerAmountMin, uint takerAmountMin, uint deadline) lock public {
        Position storage position = positions[positionIndex];
        Offer storage offer = offers[position.offerIndex];
        require(position.maker == msg.sender || position.taker == msg.sender, "Coliquidity: WPMTS");
        require(position.lockedUntil <= block.timestamp, "Coliquidity: WPLLT");
        require(position.liquidityAmount >= liquidityAmount, "Coliquidity: WPLGL");
        // liquidity is validated within removeLiquidity call
        // makerAmountMin is validated within removeLiquidity call
        // takerAmountMin is validated within removeLiquidity call
        // deadline is validated within removeLiquidity call
        position.liquidityAmount -= liquidityAmount;
        address pair = pairFor(factory, position.makerToken, position.takerToken);
        IERC20(pair).approve(router, liquidityAmount);
        (uint makerAmountWithdrawn, uint takerAmountWithdrawn) = IUniswapV2Router02(router).removeLiquidity(
            position.makerToken,
            position.takerToken,
            liquidityAmount,
            makerAmountMin,
            takerAmountMin,
            address(this),
            deadline
        );
        if (makerAmountWithdrawn > position.makerAmount) {
            uint makerFee = (makerAmountWithdrawn - position.makerAmount) * feeNumerator / feeDenominator;
            // should be `position.makerAmount -= makerAmountWithdrawn`, but the result is less than 0, so setting it to 0
            position.makerAmount = 0;
            if (offer.reinvest) {
                offer.makerAmount += makerAmountWithdrawn - makerFee;
            } else {
                TransferHelper.safeTransfer(position.makerToken, position.maker, makerAmountWithdrawn - makerFee);
            }
            TransferHelper.safeTransfer(position.makerToken, owner(), makerFee);
        } else {
            position.makerAmount -= makerAmountWithdrawn;
            if (offer.reinvest) {
                offer.makerAmount += makerAmountWithdrawn;
            } else {
                TransferHelper.safeTransfer(position.makerToken, position.maker, makerAmountWithdrawn);
            }
        }
        if (takerAmountWithdrawn > position.takerAmount) {
            uint takerFee = (takerAmountWithdrawn - position.takerAmount) * feeNumerator / feeDenominator;
            // should be `position.takerAmount -= takerAmountWithdrawn`, but the result is less than 0, so setting it to 0            position.takerAmount = 0;
            position.takerAmount = 0;
            // reinvest is not available for the taker
            TransferHelper.safeTransfer(position.takerToken, position.taker, takerFee);
            TransferHelper.safeTransfer(position.takerToken, owner(), takerFee);
        } else {
            position.takerAmount -= takerAmountWithdrawn;
            TransferHelper.safeTransfer(position.takerToken, position.taker, takerAmountWithdrawn);
        }
        emit WithdrawPosition(msg.sender, position.offerIndex, positionIndex);
    }

    /* Views */

    function offersLength() public view returns (uint) {
        return offers.length;
    }

    function positionsLength() public view returns (uint) {
        return positions.length;
    }

    function offersTakerTokens(uint offerIndex) public view returns (address[] memory) {
        return offers[offerIndex].takerTokens;
    }

    function offersByMaker(address maker, uint length) public view returns (IndexedOffer[] memory) {
        IndexedOffer[] memory _offersByMaker = new IndexedOffer[](length);
        uint _offersByMakerIndex = 0;
        for (uint i = 0; i < offers.length; i++) {
            if (offers[i].maker == maker) {
                _offersByMaker[_offersByMakerIndex] = IndexedOffer({index : i, offer : offers[i]});
                _offersByMakerIndex++;
                if (_offersByMakerIndex > length) break;
            }
        }
        return _offersByMaker;
    }

    function positionsByMaker(address maker, uint length) public view returns (IndexedPosition[] memory) {
        IndexedPosition[] memory _positionsByMaker = new IndexedPosition[](length);
        uint _positionsByMakerIndex = 0;
        for (uint i = 0; i < positions.length; i++) {
            if (positions[i].maker == maker) {
                _positionsByMaker[_positionsByMakerIndex] = IndexedPosition({index : i, position : positions[i]});
                _positionsByMakerIndex++;
                if (_positionsByMakerIndex > length) break;
            }
        }
        return _positionsByMaker;
    }

    function positionsByTaker(address taker, uint length) public view returns (IndexedPosition[] memory) {
        IndexedPosition[] memory _positionsByTaker = new IndexedPosition[](length);
        uint _positionsByTakerIndex = 0;
        for (uint i = 0; i < positions.length; i++) {
            if (positions[i].taker == taker) {
                _positionsByTaker[_positionsByTakerIndex] = IndexedPosition({index : i, position : positions[i]});
                _positionsByTakerIndex++;
                if (_positionsByTakerIndex > length) break;
            }
        }
        return _positionsByTaker;
    }

    /* UniswapV2Library functions - had to copy because it depends on SafeMath, which depends on Solidity =0.6.6, which is lower than our Solidity version */

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address _factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint(keccak256(abi.encodePacked(
                hex'ff',
                _factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // init code hash
            )))));
    }
}