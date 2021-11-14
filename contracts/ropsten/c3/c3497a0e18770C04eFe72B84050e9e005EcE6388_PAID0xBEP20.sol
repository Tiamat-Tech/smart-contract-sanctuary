// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "/contracts/IBEP20.sol";
import "/contracts/BEP20.sol";
import "/contracts/BEP20Mintable.sol";
import "/contracts/BEP20Burnable.sol";


contract PAID0xBEP20 is BEP20Mintable, BEP20Burnable {

    constructor ()
      BEP20('CITYDAO', 'TEMPCITY')
    {
        _setupDecimals(18);
        _mint(_msgSender(), 100000000000000000000000);
    }

    /**
     * @dev Function to mint tokens.
     *
     * NOTE: restricting access to owner only. See {BEP20Mintable-mint}.
     *
     * @param account The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function _mint(address account, uint256 amount) internal override onlyOwner {
        super._mint(account, amount);
    }

    /**
     * @dev Function to stop minting new tokens.
     *
     * NOTE: restricting access to owner only. See {BEP20Mintable-finishMinting}.
     */
    function _finishMinting() internal override onlyOwner {
        super._finishMinting();
    }
}