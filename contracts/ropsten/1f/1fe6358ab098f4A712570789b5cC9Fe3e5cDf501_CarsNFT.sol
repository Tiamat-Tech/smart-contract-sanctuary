// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

interface pancakeRouterInterface {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
}

interface pancakeFactoryInterface {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface pancakePairInterface {
    function getReserves() external view returns (
        uint112 _reserve0,
        uint112 _reserve1,
        uint32 _blockTimestampLast
    );
}

contract CarsNFT is Ownable, ERC721Enumerable {

    uint256 public price = 9.99 ether;
    uint256 public mintCounter;
    uint256 public airdropCounter;
    uint256 public maxTokensToBuy;
    uint256 private airdropReserved;
    uint256 private maxTokensCount = 10000;
    string private baseURI;
    IERC20 private contractBUSD;
    IERC20 private contractCST;
    address private addressLP;
    pancakeRouterInterface private pancakeRouterContract;
    pancakeFactoryInterface private pancakeFactoryContract;

    /// @notice don't forget to add '/' to the end of seventh argument at constructor
    constructor(
        address _contractBUSD,
        address _lpAddress,
        address _cstAddress,
        address _pancakeRouterAddress,
        address _pancakeFactoryAddress,
        uint256 _airdropReserved,
        string memory _uri,
        string memory _tokenName,
        string memory _tokenSymbol
    ) ERC721(_tokenName, _tokenSymbol) {
        airdropReserved = _airdropReserved;
        addressLP = _lpAddress;
        contractBUSD = IERC20(_contractBUSD);
        contractCST = IERC20(_cstAddress);
        maxTokensToBuy = 10;
        baseURI = _uri;
        pancakeRouterContract = pancakeRouterInterface(_pancakeRouterAddress);
        pancakeFactoryContract = pancakeFactoryInterface(_pancakeFactoryAddress);
    }

    event Buy(address _buyer, uint256 _tokensAmount);
    event SetContractBUSD(address _address);
    event SetMaxTokensToBuy(uint256 _maxTokens);
    event Airdrop(address[] _addresses, uint256[] _tokenIds);
    event AddLiquidity(uint256 _amountBUSD, uint256 _amountCST, uint256 _liquidity);
    event Withdraw(address _to, uint256 _amount);

    function setContractBUSD(address _addr) public onlyOwner {
        contractBUSD = IERC20(_addr);
        emit SetContractBUSD(_addr);
    }

    function setMaxTokensToBuy(uint256 _maxTokens) public onlyOwner {
        maxTokensToBuy = _maxTokens;
        emit SetMaxTokensToBuy(_maxTokens);
    }

    function buy(uint256 tokensToBuy) public {
        require(tokensToBuy > 0, "Tokens amount exceed minimum to buy");
        require(tokensToBuy <= maxTokensToBuy, "Tokens amount exceed maximum");
        require(countAvailableTokensToBuy() >= tokensToBuy, "Already sold out");

        uint256 purchaseAmount = tokensToBuy * price;

        contractBUSD.transferFrom(msg.sender, address(this), purchaseAmount);
        uint256 _mintCounter = mintCounter;
        for (uint256 i = 0; i < tokensToBuy; i++) {
            _safeMint(msg.sender, _mintCounter);
            _mintCounter++;
            if (_mintCounter % 1000 == 0) {
                _addLiquidity();
            }
        }
        mintCounter = _mintCounter;
        if (countAvailableTokensToBuy() == 0 && contractBUSD.balanceOf(address(this)) > 0) {
            _addLiquidity();
        }
        emit Buy(msg.sender, tokensToBuy);
    }

    function airdrop(address[] memory _addresses, uint256[] memory _ids) public onlyOwner {
        require(_addresses.length == _ids.length, "Arrays lengths are not equivalent");
        require(_ids.length <= countAvailableTokensToAirdrop(), "Tokens are out of stock");

        uint256 minimumAirdropTokenId = maxTokensCount - airdropReserved - 1;

        for (uint256 i = 0; i < _ids.length; i++) {
            require(
                _ids[i] > minimumAirdropTokenId && _ids[i] < maxTokensCount,
                "Provided tokenId is out of reserved range"
            );
            _safeMint(_addresses[i], _ids[i]);
            airdropCounter++;
        }

        emit Airdrop(_addresses, _ids);
    }

    function setBaseURI(string memory _uri) public onlyOwner {
        baseURI = _uri;
    }

    function withdraw(address _to) public onlyOwner {
        uint256 currentBUSDBalance = contractBUSD.balanceOf(address(this));
        contractBUSD.transfer(_to, currentBUSDBalance);
        emit Withdraw(_to, currentBUSDBalance);
    }

    function getAirdropReserved() public view onlyOwner returns(uint256) {
        return airdropReserved;
    }

    function countAvailableTokensToBuy() public view returns(uint256) {
        return maxTokensCount - airdropReserved - mintCounter;
    }

    function countAvailableTokensToAirdrop() public view returns(uint256) {
        return airdropReserved - airdropCounter;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _addLiquidity() private {
        uint256 currentBUSDBalance = contractBUSD.balanceOf(address(this));
        address pairAddress = pancakeFactoryContract.getPair(address(contractBUSD), address(contractCST));
        (,uint112 reserve1,) = pancakePairInterface(pairAddress).getReserves();
        uint256 amountForSwap = _getAmountForSwap(30, uint256(reserve1), currentBUSDBalance);
        contractBUSD.approve(address(pancakeRouterContract), currentBUSDBalance);
        address[] memory addresses = new address[](2);
        addresses[0] = address(contractBUSD);
        addresses[1] = address(contractCST);
        uint256[] memory result = pancakeRouterContract.swapExactTokensForTokens(
            currentBUSDBalance / 2, // change this to amountForSwap after fixing
            0,
            addresses,
            address(this),
            block.timestamp
        );
        contractCST.approve(address(pancakeRouterContract), result[1]);
        (uint256 _busd, uint256 _cst, uint256 _liquidity) = pancakeRouterContract.addLiquidity(
            address(contractBUSD),
            address(contractCST),
            result[0],
            result[1],
            0,
            0,
            addressLP,
            block.timestamp
        );
        emit AddLiquidity(_busd, _cst, _liquidity);
    }

    function _getAmountForSwap(
        uint256 feeBps,
        uint256 reserve1,
        uint256 amount
    ) private pure returns(uint256){
        uint256 l = 10000 - feeBps;
        uint256 a = (reserve1 * reserve1 * (10000 + l));
        uint256 b = 4 * l * amount * reserve1;
        uint256 c = a + b;
        uint256 d = (((10000 + l) * reserve1)/ (2 * l));
        uint256 s = c - d;
        return (sqrt(s)) ;
    }

    function sqrt(uint x) private pure returns (uint y) {
        uint z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
}