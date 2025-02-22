// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;
import "hardhat/console.sol";
import "./libs/LibNFTOrder.sol";
import "./libs/LibSignature.sol";
import "./interfaces/IERC721Inkion.sol";

contract InkionExchange {
    address zeroEx;
    IERC721Inkion erc721Inkion;

    function initialize(address _zeroEx, address _erc721Inkion) public {
        zeroEx = _zeroEx;
        erc721Inkion = IERC721Inkion(_erc721Inkion);
    }

    // signature content is generated by backend, signed by user, then submit back to backend
    // signature is public in the marketplace
    // sellers can lower the price but not raising
    // cancelling order = blacklisting signature
    function buyERC721(
        LibNFTOrder.ERC721Order calldata sellOrder,
        LibSignature.Signature calldata signature
    ) external payable returns (bool) {
        //erc721Inkion.safeMint(sellOrder.maker, sellOrder.erc721TokenId);
        bytes4 FUNC_SELECTOR = bytes4(
            keccak256(
                "buyERC721((uint8,address,address,uint256,uint256,address,uint256,(address,uint256,bytes)[],address,uint256,(address,bytes)[]),(uint8,uint8,bytes32,bytes32),bytes)"
            )
        );
        bytes memory data = abi.encodeWithSelector(
            FUNC_SELECTOR,
            sellOrder,
            signature,
            ""
        );
        (bool success, ) = zeroEx.delegatecall(data);

        // if (!success) {
        //     assembly {
        //         revert(add(32, returndata), mload(returndata))
        //     }
        // }
        require(success);
        return true;
    }
}