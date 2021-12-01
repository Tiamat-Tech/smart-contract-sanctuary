// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;
pragma abicoder v2;

import "./ERC1155Base.sol";
import "../whitelist/interfaces/IWlController.sol";

contract ERC1155WatermarkAsset is ERC1155Base {

    /// @notice Whitelist controller
    IWlController public wlController;

    event CreateERC1155WatermarkAsset(address owner, string name, string symbol);
    event SetWlController(address indexed wlController);

    function __ERC1155WatermarkAsset_init(
        string memory _name,
        string memory _symbol,
        string memory baseURI,
        string memory contractURI
    ) external initializer {
        __Ownable_init_unchained();
        __ERC1155Lazy_init_unchained();
        __ERC165_init_unchained();
        __Context_init_unchained();
        __Mint1155Validator_init_unchained();
        __ERC1155_init_unchained("");
        __HasContractURI_init_unchained(contractURI);
        __ERC1155Burnable_init_unchained();
        __RoyaltiesV2Upgradeable_init_unchained();
        __ERC1155Base_init_unchained(_name, _symbol);
        _setBaseURI(baseURI);
        emit CreateERC1155WatermarkAsset(_msgSender(), _name, _symbol);
    }

    /**
     * @notice Set a new whitelist controller.
     * @param _wlController New whitelist controller.
     */
    function setWlController(IWlController _wlController) external onlyOwner {
        wlController = _wlController;
        emit SetWlController(address(_wlController));
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning.
     */
    function _beforeTokenTransfer(address operator, address from, address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        // require from and to addresses in whitelist
        IWlController controller = wlController;
        if (address(controller) != address(0)) {
            // check mint case
            if (from != address(0)) {
                require(
                    controller.isInvestorAddressActive(from),
                    "ERC1155WatermarkAsset: transfer permission denied"
                );
            }

            // check burn case
            if (to != address(0)) {
                require(
                    controller.isInvestorAddressActive(to),
                    "ERC1155WatermarkAsset: transfer permission denied"
                );
            }
        }
    }

    uint256[50] private __gap;
}