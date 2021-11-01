// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "./libs/SafeMath.sol";

interface ILiquidityGauge {
    function user_checkpoint(address _for) external;

    function integrate_fraction(address _for) external view returns (uint256);
}

interface ILendFlareToken {
    function mint(address _for, uint256 amount) external;
}

contract LendFlareTokenMinter {
    using SafeMath for uint256;

    address public token;
    // address public lendFlareGaugeModel;

    mapping(address => mapping(address => uint256)) public minted; // user -> gauge -> value
    mapping(address => mapping(address => bool)) public allowed_to_mint_for; // minter -> user -> can mint?

    event Minted(address user, address gauge, uint256 amount);

    constructor(
        address _token /* , address _lendFlareGaugeModel */
    ) public {
        token = _token;
        // lendFlareGaugeModel = _lendFlareGaugeModel;
    }

    function _mint_for(address gauge_addr, address _for) internal {
        ILiquidityGauge(gauge_addr).user_checkpoint(_for);
        uint256 total_mint = ILiquidityGauge(gauge_addr).integrate_fraction(
            _for
        );
        uint256 to_mint = total_mint - minted[_for][gauge_addr];

        if (to_mint != 0) {
            ILendFlareToken(token).mint(_for, to_mint);
            minted[_for][gauge_addr] = total_mint;

            emit Minted(_for, gauge_addr, total_mint);
        }
    }

    function mint(address gauge_addr) public {
        _mint_for(gauge_addr, msg.sender);
    }

    function mint_many(address[8] memory gauge_addrs) public {
        for (uint256 i = 0; i < gauge_addrs.length; i++) {
            if (gauge_addrs[i] == address(0)) break;

            _mint_for(gauge_addrs[i], msg.sender);
        }
    }

    function mint_for(address gauge_addr, address _for) public {
        if (allowed_to_mint_for[msg.sender][_for]) {
            _mint_for(gauge_addr, _for);
        }
    }

    function toggle_approve_mint(address minting_user) public {
        allowed_to_mint_for[minting_user][msg.sender] = !allowed_to_mint_for[
            minting_user
        ][msg.sender];
    }
}