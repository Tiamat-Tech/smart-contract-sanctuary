// SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {
    TransferHelper
} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {
    INonfungiblePositionManager
} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {
    PoolAddress
} from "@uniswap/v3-periphery/contracts/libraries/PoolAddress.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";

/// @author Alchemy Team
/// @title UNIV3ERC20
/// @notice The contract wraps a univ3 position into a fungible position
contract UNIV3ERC20 is IERC20 {
    // using Openzeppelin contracts for SafeMath and Address, TransferHelper from the (uni?) library
    using SafeMath for uint256;
    using Address for address;
    // uinv3 update - fried
    using SafeMath for uint128;
    using TransferHelper for address;

    // presenting the total supply
    uint256 internal _totalSupply;

    // representing the name of the governance token
    string internal _name;

    // representing the symbol of the governance token
    string internal _symbol;

    // representing the decimals of the governance token
    uint8 internal constant _decimals = 18;

    // a record of balance of a specific account by address
    mapping(address => uint256) private _balances;

    // a record of allowances for a specific address by address to address mapping
    mapping(address => mapping(address => uint256)) private _allowances;

    // struct for raised nfts
    struct _raisedNftStruct {
        IERC721 nftaddress;
        bool forSale;
        uint256 tokenid;
        uint256 price;
    }

    // univ3 NFT for ease of access
    _raisedNftStruct public nonfungiblePosition;

    // PositionManager that operates upon NFT's
    INonfungiblePositionManager public positionManager;

    // in case we have the above we also take the token pool immediately
    IUniswapV3Pool public tokenPool;

    // factory contract that spawned this contract
    address public _factoryContract;

    constructor() {
        // Don't allow implementation to be initialized.
        _factoryContract = address(1);
    }

    function initialize(
        address nftAddress_,
        address owner_,
        uint256 tokenId_,
        string memory name_,
        string memory symbol_,
        address factoryContract
    ) external {
        // handle initialization
        require(_factoryContract == address(0), "already initialized");
        require(factoryContract != address(0), "factory can not be null");
        _factoryContract = factoryContract;

        // initialize the single nonfungible position
        nonfungiblePosition = _raisedNftStruct({
            nftaddress: IERC721(nftAddress_),
            tokenid: tokenId_,
            forSale: false,
            price: 0
        });

        // initalize the NFPM
        positionManager = INonfungiblePositionManager(
            0xC36442b4a4522E871399CD717aBDD847Ab11FE88
        ); //https://github.com/Uniswap/uniswap-v3-periphery/blob/main/deploys.md

        _name = name_;
        _symbol = symbol_;

        // data taken from tuple we need for init / minting

        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            ,
            ,
            uint128 currentLiquidity,
            ,
            ,
            ,

        ) = positionManager.positions(nonfungiblePosition.tokenid);

        // mint the owner of the NFT exactly as many shares as there is liquidity
        _mint(owner_, currentLiquidity);

        // init pool obj so we can use it for data
        tokenPool = IUniswapV3Pool(
            PoolAddress.computeAddress(
                0x1F98431c8aD98523631AE4a59f267346ea31F984,
                PoolAddress.getPoolKey(token0, token1, fee)
            )
        );

        // print total supply so we see it increasing with mint
        emit Transfer(address(0), owner_, _totalSupply);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing
     * and updating burn tokens for abstraction
     *
     * @param amount the amount to be burned
     */
    function _burn(uint256 amount) internal {
        _totalSupply = _totalSupply.sub(amount);
    }

    ////////////////////////////////////
    // UNIV3

    event portionOfLiquidityAdded(
        address account,
        uint256 newLiquidity,
        uint256 amount0Added,
        uint256 amount1Added
    );

    /**
     * @notice adds liquidity and mints shares based on added liquidity
     * @param amount0ToTrySpend max token0 to try and spend
     * @param amount1ToTrySpend max token1 to try and spend
     * @param amount0MinToSpend min token0 to try and spend
     * @param amount1MinToSpend min token1 to try and spend
     * @param recipient sender
     * */
    function _addPortionOfCurrentLiquidity(
        uint256 amount0ToTrySpend,
        uint256 amount1ToTrySpend,
        uint256 amount0MinToSpend,
        uint256 amount1MinToSpend,
        address recipient
    ) external {
        (, , address token0, address token1, , , , , , , , ) =
            positionManager.positions(nonfungiblePosition.tokenid);

        // include a block like this if you want to shift the logic of checking for token (because token assignment is according
        // to size of address so really undecidable by you) to solidity, just that this is inefficient gas-wise
        //  if (!(some condition)) {
        //      (
        //          amount0ToTrySpend,
        //          amount1ToTrySpend,
        //          amount0MinToSpend,
        //          amount1MinToSpend
        //      ) = (
        //          amount1ToTrySpend,
        //          amount0ToTrySpend,
        //          amount1MinToSpend,
        //          amount0MinToSpend
        //      );
        //  }

        // transfer from liquidity provider to this contract
        // be careful not to mess up tokens!!!!
        // will obviously fail if token spender does not have enough tokens
        token0.safeTransferFrom(recipient, address(this), amount0ToTrySpend);
        token1.safeTransferFrom(recipient, address(this), amount1ToTrySpend);

        token0.safeApprove(address(positionManager), amount0ToTrySpend);
        token1.safeApprove(address(positionManager), amount1ToTrySpend);

        (uint128 newLiquidity, uint256 amount0, uint256 amount1) =
            positionManager.increaseLiquidity(
                INonfungiblePositionManager.IncreaseLiquidityParams({
                    tokenId: nonfungiblePosition.tokenid,
                    amount0Desired: amount0ToTrySpend,
                    amount1Desired: amount1ToTrySpend,
                    amount0Min: amount0MinToSpend,
                    amount1Min: amount1MinToSpend,
                    deadline: block.timestamp + 2 minutes
                })
            );

        // new liquidity is instantly the delta so we can easily just mint according to it
        _mint(msg.sender, newLiquidity);

        // transfer back to sender unspent rest
        token0.safeTransfer(recipient, amount0ToTrySpend.sub(amount0));
        token1.safeTransfer(recipient, amount1ToTrySpend.sub(amount1));

        emit portionOfLiquidityAdded(recipient, newLiquidity, amount0, amount1);
    }

    event portionOfLiquidityWithdrawn(
        address account,
        uint256 sharesBurned,
        uint256 amount0Collected,
        uint256 amount1Collected
    );

    /**
     * @notice withdraws portion of current liquidity
     * @param burnerShares amount of shares to be burned
     * @param minimumToken0Out min amount of token 0 you want back
     * @param minimumToken1Out min amount of token 0 you want back
     * @param recipient_ the account to receive the tokens
     * */
    function _withdrawPortionOfCurrentLiquidity(
        uint128 burnerShares,
        uint256 minimumToken0Out,
        uint256 minimumToken1Out,
        address recipient_
    ) external {
        uint256 balance = balanceOf(recipient_);
        require(balance >= burnerShares, "Can't burn more than you have");

        // immediately burn tokens
        _balances[recipient_] = balance.sub(burnerShares);
        _burn(burnerShares);

        //  Decrease liquidity, tokens are accounted to position.
        (uint256 amount0, uint256 amount1) =
            positionManager.decreaseLiquidity(
                INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: nonfungiblePosition.tokenid,
                    liquidity: burnerShares,
                    amount0Min: minimumToken0Out, // min out
                    amount1Min: minimumToken1Out, // min out
                    deadline: block.timestamp + 2 minutes // will look into
                })
            );

        // collect from position
        (uint256 amount0Collected, uint256 amount1Collected) =
            positionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: nonfungiblePosition.tokenid,
                    recipient: recipient_,
                    amount0Max: uint128(amount0),
                    amount1Max: uint128(amount1)
                })
            );

        emit portionOfLiquidityWithdrawn(
            recipient_,
            burnerShares,
            amount0Collected,
            amount1Collected
        );
    }

    /**
     * returns address of token0
     */
    function getToken0() external view returns (address) {
        return tokenPool.token0();
    }

    /**
     * returns address of token1
     */
    function getToken1() external view returns (address) {
        return tokenPool.token1();
    }

    /**
     * returns total shares which equal liquidity of position
     */
    function getTotalShares() external view returns (uint128 shares) {
        shares = tokenPool.liquidity();
        return shares;
    }

    /**
     * @notice internal function to help with error handling for quoting functions
     */
    function parseRevertReason(bytes memory reason)
        internal
        pure
        returns (uint256)
    {
        if (reason.length != 32) {
            if (reason.length < 68) revert("Unexpected error");
            assembly {
                reason := add(reason, 0x04)
            }
            revert(abi.decode(reason, (string)));
        }
        return abi.decode(reason, (uint256));
    }

    /**
     * @notice see liquidity addition, amount of liquidity added can be found through events
     */
    function quoteLiquidityAddition(
        uint256 amount0ToTrySpend,
        uint256 amount1ToTrySpend,
        uint256 amount0MinToSpend,
        uint256 amount1MinToSpend
    ) external returns (uint256) {
        try
            this._addPortionOfCurrentLiquidity(
                amount0ToTrySpend,
                amount1ToTrySpend,
                amount0MinToSpend,
                amount1MinToSpend,
                msg.sender
            )
        {} catch (bytes memory reason) {
            return parseRevertReason(reason);
        }
    }

    /**
     * @notice see liquidity withdrawal, amount of liquidity added can be found through events
     */
    function quoteLiquidityWithdrawal(
        uint128 burnerShares,
        uint256 minimumToken0Out,
        uint256 minimumToken1Out
    ) external returns (uint256) {
        try
            this._withdrawPortionOfCurrentLiquidity(
                burnerShares,
                minimumToken0Out,
                minimumToken1Out,
                msg.sender
            )
        {} catch (bytes memory reason) {
            return parseRevertReason(reason);
        }
    }

    ////////////////////////////////////

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}. Uses burn abstraction for balance updates without gas and universally.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address dst, uint256 rawAmount)
        external
        override
        returns (bool)
    {
        uint256 amount = rawAmount;
        _transferTokens(msg.sender, dst, amount);
        return true;
    }

    /**
     * fallback function for collection funds
     */
    fallback() external payable {}

    receive() external payable {}

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(msg.sender, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero ress.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address src,
        address dst,
        uint256 rawAmount
    ) external override returns (bool) {
        address spender = msg.sender;
        uint256 spenderAllowance = _allowances[src][spender];
        uint256 amount = rawAmount;

        if (spender != src && spenderAllowance != uint256(-1)) {
            uint256 newAllowance =
                spenderAllowance.sub(amount, "NFTDAO:amount exceeds");
            _allowances[src][spender] = newAllowance;
        }

        _transferTokens(src, dst, amount);
        return true;
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        _totalSupply += amount;
        _balances[account] += amount;
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(owner != address(0), "ERC20: approve from 0");
        require(spender != address(0), "ERC20: approve to 0");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transferTokens(
        address src,
        address dst,
        uint256 amount
    ) internal {
        require(src != address(0), "ALC: cannot transfer 0");
        require(dst != address(0), "ALC: cannot transfer 0");

        _balances[src] = _balances[src].sub(amount, "ALC:_transferTokens");
        _balances[dst] = _balances[dst].add(amount);
        emit Transfer(src, dst, amount);
    }

    function safe32(uint256 n, string memory errorMessage)
        internal
        pure
        returns (uint32)
    {
        require(n < 2**32, errorMessage);
        return uint32(n);
    }

    function getChainId() internal pure returns (uint256) {
        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        return chainId;
    }
}