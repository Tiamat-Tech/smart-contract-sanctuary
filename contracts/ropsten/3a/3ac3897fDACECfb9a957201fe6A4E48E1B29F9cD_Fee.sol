// This contract fetches real-time price feed from Chainlink Oracles and converts the gas fee amount to its equivalent token price.
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Fee {
    using SafeMath for uint256;

    // admin
    mapping(address => bool) admins;

    // The pricefeed contract addresses for both main and kovan networks. For example, priceContracts["main-eth-usd"] = "0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419"
    mapping(bytes => address) public priceContracts;

    // mapping token address to tokem price index. For example tokensMap[0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48] = "main-eth-usd"
    // this allows us to figure out the cost equivalence for gas fee.
    mapping(address => bytes) public tokensMap;

    constructor() public {
        admins[msg.sender] = true; // deployer is the default admin.

        // initalize price feed.
        priceContracts["main-usdc-eth"] = 0x986b5E1e1755e3C2440e960477f25201B0a8bbD4;
        priceContracts["main-uni-eth"] = 0xD6aA3D25116d8dA79Ea0246c4826EB951872e02e;
        priceContracts["kovan-usdc-eth"] = 0x64EaC61A2DFda2c3Fa04eED49AA33D021AeC8838;
        priceContracts["main-dai-eth"] = 0x773616E4d11A78F511299002da57A0a94577F1f4;

        // initialize token addresses.
        tokensMap[0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984] = "main-uni-eth";
        tokensMap[0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48] = "main-usdc-eth";
        tokensMap[0x7079f3762805CFf9C979a5bDC6f5648bCFEE76C8] = "kovan-usdc-eth";
        tokensMap[0x6B175474E89094C44Da98b954EedeAC495271d0F] = "main-dai-eth";
    }

    event AdminPrivileged(address indexed addr, bool privilege);

    modifier onlyAdmin() {
        require(admins[msg.sender], "Unauthorized call! Not an admin");
        _;
    }

    /**
     * Adds or removes admin privilege to or from the input address.
     * @param input: the input address to be given or revoked admin privilege.
     * @param isAdmin: true: assigns admin, false: revokes admin
     */
    function modifyAdmin(address input, bool isAdmin) public onlyAdmin() {
        admins[input] = isAdmin;
        emit AdminPrivileged(input, isAdmin);
    }

    /**
     * Adds a new price feed, then maps to the token address.
     * @param priceIndex: The network and the currency index. e.g. "kovan-btc-usd"
     * @param feed: The address of the Chainlink price feed
     * @param token: The token address
     */
    function addPriceFeed(
        string memory priceIndex,
        address feed,
        address token
    ) public onlyAdmin() {
        bytes memory index = bytes(priceIndex);
        priceContracts[index] = feed;
        tokensMap[token] = index;
    }

    /**
     * Gets the real time price of a single token (not accounted for decimals) data from Chainlink
     * @param token: The token address
     * @dev For Ropsten network, the token price is fixed at 10000000000000000 wei or 0.01 ETH.
     * Returns the rounded-up price in 18 decimals (Wei).
     */
    function getPrice(address token) public view returns (int256) {
        // bytes memory index = tokensMap[token];
        // require(index.length > 0, "Token not supported");
        // address addr = priceContracts[index];
        // require(addr != address(0), "Invalid contract address");
        // AggregatorV3Interface priceFeed = AggregatorV3Interface(addr);
        // (, int256 price, , , ) = priceFeed.latestRoundData();
        // return price;

        // Ropsten
        return 10000000000000000;
    }

    /**
     * Returns the amount of tokens equivalent to the gas fee
     * @param token: The token address
     * @param gas: gas in Wei
     * Returns the fee in 18 decimals
     */
    function calculateGasInTokens(
        address token,
        uint256 gas
    ) public view returns (uint256) {
        bytes memory index = tokensMap[token];
        require(index.length > 0, "Token not supported");
        uint256 gasFee = gas;
        uint256 weiPerToken = uint256(getPrice(token));
        uint256 roundingDecimals = ERC20(token).decimals();
        uint256 gasInTokensRounded = (gasFee.mul(10**roundingDecimals)).div(weiPerToken);
        return gasInTokensRounded;
    }
}