// contracts/rMutantCoin.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract rMutantCoin is ERC20, Ownable {
    using SafeMath for uint256;
    IERC721Enumerable public _mpAddress;

    mapping (uint256 => bool) private _isDemon;
    mapping (uint256 => bool) private _isMummy;
    mapping (uint256 => bool) private _isApeZombie;

    // Sun Oct 17 2021 18:00:00 GMT+0000 - Public Sale date.
    uint256 constant public _START = 1634493600;
    // Sat Oct 17 2024 18:00:00 GMT+0000 - 3 years from public sale date.
    uint256 public _END = 1729188000;

    // base rate is in ethers 10^18.
    uint256 public _demonBaseRate = 35 ether;
    uint256 public _mummyBaseRate = 15 ether;
    uint256 public _apeZombieBaseRate = 5 ether;
    uint256 public _otherBaseRate = 0.35 ether;
    //(((10000 - (9+24+88))*0.35) + (5*88) + (15*24) + (35*9)) * 365 * 3 = 5,007,051 total ~ 5% of total supply.

	mapping(uint256 => uint256) public _lastClaimTimestamp; //map tokenId -> timestamp.

    event RewardClaimed(address indexed user, uint256 reward);

    constructor(IERC721Enumerable mpAddress) ERC20("rMutantCoin", "rMC") {
        _mpAddress = mpAddress;
        _mapDemon();
        _mapMummy();
        _mapApeZombie();
    }

    // Map MPNFT type

    function _mapDemon() private {
        _isDemon[17] = true;
        _isDemon[638] = true;
        _isDemon[1885] = true;
        _isDemon[3917] = true;
        _isDemon[4836] = true;
        _isDemon[5907] = true;
        _isDemon[6611] = true;
        _isDemon[8066] = true;
        _isDemon[9411] = true;
    }

    function _mapMummy() private {
        _isMummy[39] = true;
        _isMummy[375] = true;
        _isMummy[1024] = true;
        _isMummy[1425] = true;
        _isMummy[1708] = true;
        _isMummy[2146] = true;
        _isMummy[2387] = true;
        _isMummy[2495] = true;
        _isMummy[2715] = true;
        _isMummy[2927] = true;
        _isMummy[3492] = true;
        _isMummy[4159] = true;
        _isMummy[4466] = true;
        _isMummy[5220] = true;
        _isMummy[5317] = true;
        _isMummy[5580] = true;
        _isMummy[5798] = true;
        _isMummy[6146] = true;
        _isMummy[6917] = true;
        _isMummy[7192] = true;
        _isMummy[8219] = true;
        _isMummy[8498] = true;
        _isMummy[9265] = true;
        _isMummy[9280] = true;
    }

    function _mapApeZombie() private {
        _isApeZombie[58] = true;
        _isApeZombie[990] = true;
        _isApeZombie[1122] = true;
        _isApeZombie[1193] = true;
        _isApeZombie[1377] = true;
        _isApeZombie[1482] = true;
        _isApeZombie[1530] = true;
        _isApeZombie[1662] = true;
        _isApeZombie[1753] = true;
        _isApeZombie[1892] = true;
        _isApeZombie[1941] = true;
        _isApeZombie[2072] = true;
        _isApeZombie[2138] = true;
        _isApeZombie[2254] = true;
        _isApeZombie[2311] = true;
        _isApeZombie[2334] = true;
        _isApeZombie[2343] = true;
        _isApeZombie[2429] = true;
        _isApeZombie[2488] = true;
        _isApeZombie[2564] = true;
        _isApeZombie[2570] = true;
        _isApeZombie[2685] = true;
        _isApeZombie[2712] = true;
        _isApeZombie[2941] = true;
        _isApeZombie[2970] = true;
        _isApeZombie[3213] = true;
        _isApeZombie[3330] = true;
        _isApeZombie[3395] = true;
        _isApeZombie[3490] = true;
        _isApeZombie[3495] = true;
        _isApeZombie[3611] = true;
        _isApeZombie[3638] = true;
        _isApeZombie[3833] = true;
        _isApeZombie[4474] = true;
        _isApeZombie[4515] = true;
        _isApeZombie[4561] = true;
        _isApeZombie[4749] = true;
        _isApeZombie[4832] = true;
        _isApeZombie[4853] = true;
        _isApeZombie[4877] = true;
        _isApeZombie[5069] = true;
        _isApeZombie[5237] = true;
        _isApeZombie[5256] = true;
        _isApeZombie[5302] = true;
        _isApeZombie[5315] = true;
        _isApeZombie[5339] = true;
        _isApeZombie[5415] = true;
        _isApeZombie[5492] = true;
        _isApeZombie[5576] = true;
        _isApeZombie[5745] = true;
        _isApeZombie[5764] = true;
        _isApeZombie[5946] = true;
        _isApeZombie[6276] = true;
        _isApeZombie[6305] = true;
        _isApeZombie[6298] = true;
        _isApeZombie[6492] = true;
        _isApeZombie[6516] = true;
        _isApeZombie[6587] = true;
        _isApeZombie[6651] = true;
        _isApeZombie[6706] = true;
        _isApeZombie[6786] = true;
        _isApeZombie[7015] = true;
        _isApeZombie[7122] = true;
        _isApeZombie[7128] = true;
        _isApeZombie[7253] = true;
        _isApeZombie[7338] = true;
        _isApeZombie[7459] = true;
        _isApeZombie[7660] = true;
        _isApeZombie[7756] = true;
        _isApeZombie[7913] = true;
        _isApeZombie[8127] = true;
        _isApeZombie[8307] = true;
        _isApeZombie[8386] = true;
        _isApeZombie[8472] = true;
        _isApeZombie[8531] = true;
        _isApeZombie[8553] = true;
        _isApeZombie[8780] = true;
        _isApeZombie[8857] = true;
        _isApeZombie[8909] = true;
        _isApeZombie[8957] = true;
        _isApeZombie[9203] = true;
        _isApeZombie[9368] = true;
        _isApeZombie[9475] = true;
        _isApeZombie[9805] = true;
        _isApeZombie[9839] = true;
        _isApeZombie[9910] = true;
        _isApeZombie[9956] = true;
        _isApeZombie[9998] = true;
    }

    // Owner only

    function setMpAddress(IERC721Enumerable mpAddress) public onlyOwner {
        _mpAddress = mpAddress;
    }

    function setEndDate(uint256 endDate) public onlyOwner {
        _END = endDate;
    }

    function setDemonBaseRate(uint256 rate) public onlyOwner {
        _demonBaseRate = rate;
    }

    function setMummyBaseRate(uint256 rate) public onlyOwner {
        _mummyBaseRate = rate;
    }

    function setApeZombieBaseRate(uint256 rate) public onlyOwner {
        _apeZombieBaseRate = rate;
    }

    function setOtherBaseRate(uint256 rate) public onlyOwner {
        _otherBaseRate = rate;
    }

    // Mutant Punks NFT logics

    function _mpTokenBalanceOf(address add) public view returns(uint256) { // For unit test only
        return _mpAddress.balanceOf(add);
    }

    function yieldReward() external {
        require(msg.sender != address(0), "must not call from black hole");
        uint256 timeNow = Math.min(block.timestamp, _END);
		uint256 reward = 0;

        for (uint256 i = 0; i < _mpAddress.balanceOf(msg.sender); i++) {
            uint256 tokenId = _mpAddress.tokenOfOwnerByIndex(msg.sender, i);
            uint256 timeFrom = Math.max(_lastClaimTimestamp[tokenId], _START);
            uint256 baseRate = _otherBaseRate;

            if (timeFrom < timeNow) {
                if (_isDemon[tokenId]) {
                    baseRate = _demonBaseRate;
                } else if (_isMummy[tokenId]) {
                    baseRate = _mummyBaseRate;
                } else if (_isApeZombie[tokenId]) {
                    baseRate = _apeZombieBaseRate;
                }

                reward += baseRate.mul((timeNow.sub(timeFrom))).div(86400);
                _lastClaimTimestamp[tokenId] = timeNow;
            }
        }

		if (reward > 0) {
			_mint(msg.sender, reward);
			emit RewardClaimed(msg.sender, reward);
		}
	}
}