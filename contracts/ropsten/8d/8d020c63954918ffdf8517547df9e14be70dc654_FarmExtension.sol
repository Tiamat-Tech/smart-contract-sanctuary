/**
 *Submitted for verification at Etherscan.io on 2021-03-02
*/

// File: contracts\liquidity-mining\FarmData.sol

//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;

struct FarmingPositionRequest {
    uint256 setupIndex; // index of the chosen setup.
    uint256 amount; // amount of main token or liquidity pool token.
    bool amountIsLiquidityPool; //true if user wants to directly share the liquidity pool token amount, false to add liquidity to AMM
    address positionOwner; // position extension or address(0) [msg.sender].
}

struct FarmingSetupConfiguration {
    bool add; // true if we're adding a new setup, false we're updating it.
    bool disable;
    uint256 index; // index of the setup we're updating.
    FarmingSetupInfo info; // data of the new or updated setup
}

struct FarmingSetupInfo {
    bool free; // if the setup is a free liquidity mining setup or a locked one.
    uint256 blockDuration; // duration of setup
    uint256 originalRewardPerBlock;
    uint256 minStakeable; // minimum amount of staking tokens.
    uint256 maxStakeable; // maximum amount stakeable in the setup (used only if free is false).
    uint256 renewTimes; // if the setup is renewable or if it's one time.
    address ammPlugin; // amm plugin address used for this setup (eg. uniswap amm plugin address).
    address liquidityPoolTokenAddress; // address of the liquidity pool token
    address mainTokenAddress; // eg. buidl address.
    address ethereumAddress;
    bool involvingETH; // if the setup involves ETH or not.
    uint256 penaltyFee; // fee paid when the user exits a still active locked liquidity mining setup (used only if free is false).
    uint256 setupsCount; // number of setups created by this info.
    uint256 lastSetupIndex; // index of last setup;
}

struct FarmingSetup {
    uint256 infoIndex; // setup info
    bool active; // if the setup is active or not.
    uint256 startBlock; // liquidity mining setup start block.
    uint256 endBlock; // liquidity mining setup end block.
    uint256 lastUpdateBlock; // number of the block where an update was triggered.
    uint256 objectId; // items object id for the liquidity pool token (used only if free is false).
    uint256 rewardPerBlock; // liquidity mining setup reward per single block.
    uint256 totalSupply; // If free it's the LP amount, if locked is currentlyStaked.
}

struct FarmingPosition {
    address uniqueOwner; // address representing the owner of the position.
    uint256 setupIndex; // the setup index related to this position.
    uint256 creationBlock; // block when this position was created.
    uint256 liquidityPoolTokenAmount; // amount of liquidity pool token in the position.
    uint256 mainTokenAmount; // amount of main token in the position (used only if free is false).
    uint256 reward; // position reward (used only if free is false).
    uint256 lockedRewardPerBlock; // position locked reward per block (used only if free is false).
}

// File: contracts\liquidity-mining\IFarmExtension.sol

//SPDX_License_Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;


interface IFarmExtension {

    function init(bool byMint, address host) external;

    function setHost(address host) external;

    function data() external view returns(address farmMainContract, bool byMint, address host, address rewardTokenAddress);

    function transferTo(uint256 amount) external;
    function backToYou(uint256 amount) external payable;

    function setFarmingSetups(FarmingSetupConfiguration[] memory farmingSetups) external;

    function active() external view returns(bool);
}

// File: contracts\liquidity-mining\IFarmMain.sol

//SPDX_License_Identifier: MIT
pragma solidity ^0.7.6;
//pragma abicoder v2;


interface IFarmMain {

    function MAX_CONTEMPORARY_LOCKED() external view returns(uint256);
    function ONE_HUNDRED() external view returns(uint256);
    // function loadBalancerActive() external view returns(bool);
    
    function _rewardTokenAddress() external view returns(address);
    function setFarmingSetups(FarmingSetupConfiguration[] memory farmingSetups) external;
}

// File: contracts\liquidity-mining\util\IERC20.sol

// SPDX_License_Identifier: MIT

pragma solidity ^0.7.6;

interface IERC20 {

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function safeApprove(address spender, uint256 amount) external;

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function decimals() external view returns (uint8);
}

// File: contracts\liquidity-mining\util\IERC20Mintable.sol

// SPDX_License_Identifier: MIT

pragma solidity ^0.7.6;

interface IERC20Mintable {
    function mint(address wallet, uint256 amount) external returns (bool);
    function burn(address wallet, uint256 amount) external returns (bool);
}

// File: contracts\liquidity-mining\FarmExtension.sol

//SPDX_License_Identifier: MIT
pragma solidity ^0.7.6;
//pragma abicoder v2;





contract FarmExtension is IFarmExtension {

    // wallet who has control on the extension
    address internal _host;
    // address of the farm main contract linked to this extension
    address internal _farmMainContract;
    // the reward token address linked to this extension
    address internal _rewardTokenAddress;
    // whether the token is by mint or by reserve
    bool internal _byMint;
    // whether the extension is active or not
    bool public override active;

    /** MODIFIERS */

    /** @dev farmMainOnly modifier used to check for unauthorized transfers. */
    modifier farmMainOnly() {
        require(msg.sender == _farmMainContract, "Unauthorized");
        _;
    }

    /** @dev hostOnly modifier used to check for unauthorized edits. */
    modifier hostOnly() {
        require(msg.sender == _host, "Unauthorized");
        _;
    }

    /** PUBLIC METHODS */

    receive() external payable {
        require(_farmMainContract != address(0) && _rewardTokenAddress == address(0), "ETH not allowed");
    }

    function init(bool byMint, address host) public virtual override {
        require(_farmMainContract == address(0), "Already init");
        require((_host = host) != address(0), "blank host");
        _rewardTokenAddress = IFarmMain(_farmMainContract = msg.sender)._rewardTokenAddress();
        _byMint = byMint;
    }

    function data() view public virtual override returns(address liquidityMiningContract, bool byMint, address host, address rewardTokenAddress) {
        return (_farmMainContract, _byMint, _host, _rewardTokenAddress);
    }

    /** @dev method used to update the extension host.
      * @param host new host address.
     */
    function setHost(address host) public virtual override hostOnly {
        _host = host;
    }

    /** @dev method used to activate or deactivate the extension, called only by the host.
      * @param _active true if we're activating the extension, false otherwise.
     */
    function setActive(bool _active) public virtual hostOnly {
        active = _active;
    }

    /** @dev this function calls the farm main contract with the given address and sets the given farming setups.
      * @param farmingSetups array containing all the farming setups.
     */
    function setFarmingSetups(FarmingSetupConfiguration[] memory farmingSetups) public virtual override hostOnly {
        IFarmMain(_farmMainContract).setFarmingSetups(farmingSetups);
    }

    /** @dev transfers the input amount to the caller liquidity mining contract.
      * @param amount amount of erc20 to transfer or mint.
     */
    function transferTo(uint256 amount) public virtual override farmMainOnly {
        if(_rewardTokenAddress != address(0)) {
            return _byMint ? _mintAndTransfer(_rewardTokenAddress, _farmMainContract, amount) : _safeTransfer(_rewardTokenAddress, _farmMainContract, amount);
        }
        (bool result, ) = _farmMainContract.call{value:amount}("");
        require(result, "ETH transfer failed.");
    }

    /** @dev transfers the input amount from the caller liquidity mining contract to the extension.
      * @param amount amount of erc20 to transfer back or burn.
     */
    function backToYou(uint256 amount) payable public virtual override farmMainOnly {
        if(_rewardTokenAddress != address(0)) {
            _safeTransferFrom(_rewardTokenAddress, msg.sender, address(this), amount);
            if(_byMint) {
                _burn(_rewardTokenAddress, amount);
            }
        } else {
            require(msg.value == amount, "invalid sent amount");
        }
    }

    /** INTERNAL METHODS */

    function _mintAndTransfer(address erc20TokenAddress, address recipient, uint256 value) internal virtual {
        IERC20Mintable(erc20TokenAddress).mint(recipient, value);
    }

    function _burn(address erc20TokenAddress, uint256 value) internal virtual {
        IERC20Mintable(erc20TokenAddress).burn(msg.sender, value);
    }

    /** @dev function used to safely approve ERC20 transfers.
      * @param erc20TokenAddress address of the token to approve.
      * @param to receiver of the approval.
      * @param value amount to approve for.
     */
    function _safeApprove(address erc20TokenAddress, address to, uint256 value) internal virtual {
        bytes memory returnData = _call(erc20TokenAddress, abi.encodeWithSelector(IERC20(erc20TokenAddress).approve.selector, to, value));
        require(returnData.length == 0 || abi.decode(returnData, (bool)), 'APPROVE_FAILED');
    }

    /** @dev function used to safe transfer ERC20 tokens.
      * @param erc20TokenAddress address of the token to transfer.
      * @param to receiver of the tokens.
      * @param value amount of tokens to transfer.
     */
    function _safeTransfer(address erc20TokenAddress, address to, uint256 value) internal virtual {
        bytes memory returnData = _call(erc20TokenAddress, abi.encodeWithSelector(IERC20(erc20TokenAddress).transfer.selector, to, value));
        require(returnData.length == 0 || abi.decode(returnData, (bool)), 'TRANSFER_FAILED');
    }

    /** @dev this function safely transfers the given ERC20 value from an address to another.
      * @param erc20TokenAddress erc20 token address.
      * @param from address from.
      * @param to address to.
      * @param value amount to transfer.
     */
    function _safeTransferFrom(address erc20TokenAddress, address from, address to, uint256 value) internal virtual {
        bytes memory returnData = _call(erc20TokenAddress, abi.encodeWithSelector(IERC20(erc20TokenAddress).transferFrom.selector, from, to, value));
        require(returnData.length == 0 || abi.decode(returnData, (bool)), 'TRANSFERFROM_FAILED');
    }

    /** @dev calls the contract at the given location using the given payload and returns the returnData.
      * @param location location to call.
      * @param payload call payload.
      * @return returnData call return data.
     */
    function _call(address location, bytes memory payload) private returns(bytes memory returnData) {
        assembly {
            let result := call(gas(), location, 0, add(payload, 0x20), mload(payload), 0, 0)
            let size := returndatasize()
            returnData := mload(0x40)
            mstore(returnData, size)
            let returnDataPayloadStart := add(returnData, 0x20)
            returndatacopy(returnDataPayloadStart, 0, size)
            mstore(0x40, add(returnDataPayloadStart, size))
            switch result case 0 {revert(returnDataPayloadStart, size)}
        }
    }
}