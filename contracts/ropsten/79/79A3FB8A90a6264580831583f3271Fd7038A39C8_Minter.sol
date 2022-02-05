// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract Minter is ERC721, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    IERC20 public _usd;
    uint256 public _mintPriceUsd;
    uint256 private _MAX_SUPPLY;
    string private _BASE_URI;

    Counters.Counter private _nextTokenId;

    constructor(
        address usdAddress,
        uint256 mintPriceUsd,
        uint256 MAX_SUPPLY,
        string memory BASE_URI
    ) ERC721("BrandMinds", "MIND") {
        _usd = IERC20(usdAddress);
        _mintPriceUsd = mintPriceUsd;
        _MAX_SUPPLY = MAX_SUPPLY;
        _BASE_URI = BASE_URI;
        _nextTokenId.increment();
    }

    modifier mintableSupply(uint256 num) {
        uint256 currentTokenId = _nextTokenId.current();
        uint256 futureSupply = currentTokenId.add(num);
        require(futureSupply <= (_MAX_SUPPLY + 1), "Max supply exceeded");
        _;
    }

    function mint(uint256 amount) public mintableSupply(1) {
        require(amount > 0, "Zero amount sent");

        uint256 allowance = _usd.allowance(msg.sender, address(this));
        require(allowance >= amount, "Allowance lower than required");

        uint256 currentTokenId = _nextTokenId.current();
        _nextTokenId.increment();
        _safeMint(msg.sender, currentTokenId);

        _usd.transferFrom(msg.sender, address(this), amount);
    }

    function claimUsd(address to) public onlyOwner {
        uint256 amount = paymentBalanceUsd();
        require(amount > 0, "Cannot send zero amount");
        require(to != address(0), "Cannot send to zero address");

        _usd.transfer(to, amount);

        emit Claim(to, amount);
    }

    function claimEth(address to) public onlyOwner {
        uint256 amount = paymentBalanceEth();
        require(amount > 0, "Cannot send zero amount");
        require(to != address(0), "Cannot send to zero address");

        payable(to).transfer(amount);

        emit Claim(to, amount);
    }

    function getMintPriceUsd() public view returns (uint256) {
        return _mintPriceUsd;
    }

    function paymentBalanceUsd() public view returns (uint256) {
        return _usd.balanceOf(address(this));
    }

    function paymentBalanceEth() public view returns (uint256) {
        return address(this).balance;
    }

    function currentIndex() public view returns (uint256) {
        return _nextTokenId.current();
    }

    function maxSupply() public view returns (uint256) {
        return _MAX_SUPPLY;
    }

    function totalSupply() public view returns (uint256) {
        return _nextTokenId.current();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _BASE_URI;
    }

    event Claim(address indexed to, uint256 indexed amount);
}