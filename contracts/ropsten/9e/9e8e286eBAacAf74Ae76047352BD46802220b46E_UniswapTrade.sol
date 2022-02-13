// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.7.6;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./WETH9.sol";

//import "hardhat/console.sol";

contract UniswapTrade is Ownable, ERC721Enumerable, ERC721Burnable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    //Ropsten addresses (use constructor)
    ISwapRouter public immutable swapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    WETH9 public immutable weth9 =
        WETH9(0xc778417E063141139Fce010982780140Aa0cD5Ab);

    //Ropsten
    address public constant dai = 0x31F42841c2db5173425b5223809CF3A38FEde360;

    // For this example, we will set the pool fee to 1%. (change to 0.3%)
    uint24 public constant poolFee = 10000;

    uint256 public maxSupply = 1559;

    mapping(uint256 => uint256) public TokenIdStakeAmmount;

    constructor() ERC721("UniswapTrade", "UNSTA") {}

    function stakeEth(uint256 id) internal {
        require(msg.value > 0);

        weth9.deposit{value: msg.value}();

        // Approve the router to spend WETH.
        TransferHelper.safeApprove(
            address(weth9),
            address(swapRouter),
            msg.value
        );

        // Naively set amountOutMinimum to 0. In production, use an oracle or other data source to choose a safer value for amountOutMinimum.
        // We also set the sqrtPriceLimitx96 to be 0 to ensure we swap our exact input amount.
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: address(weth9),
                tokenOut: dai,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: msg.value,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        // The call to `exactInputSingle` executes the swap.
        uint256 stakeAmmount = swapRouter.exactInputSingle(params);
        TokenIdStakeAmmount[id] = stakeAmmount;
    }

    // function _baseURI() internal view virtual override returns (string memory) {
    //     return "Art gonna be here";
    // }

    function mint(address to) public payable returns (uint256) {
        uint256 newItemId = _tokenIds.current();
        _tokenIds.increment();
        require(newItemId < maxSupply);

        _mint(to, newItemId);
        stakeEth(newItemId);

        return newItemId;
    }

    //Destroy token and get stake back
    function destroy(uint256 tokenId) external {
        uint256 stakeAmmount = TokenIdStakeAmmount[tokenId];

        require(stakeAmmount > 0);
        TokenIdStakeAmmount[tokenId] = 0;
        burn(tokenId);

        TransferHelper.safeTransferFrom(
            dai,
            address(this),
            msg.sender,
            stakeAmmount
        );
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        string
            memory header = "Future art could be here, using the parameters: ";

        //Alternatively could calculate interest
        return
            string(
                abi.encodePacked(
                    header,
                    " valueStaked:",
                    toString(TokenIdStakeAmmount[tokenId]),
                    "  howLongStaked:",
                    toString(21)
                )
            );
    }

    //TODO - temporary, test only
    function toString(uint256 value) internal pure returns (string memory) {
        // Inspired by OraclizeAPI's implementation - MIT licence
        // https://github.com/oraclize/ethereum-api/blob/b42146b063c7d6ee1358846c198246239e9360e8/oraclizeAPI_0.4.25.sol

        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}