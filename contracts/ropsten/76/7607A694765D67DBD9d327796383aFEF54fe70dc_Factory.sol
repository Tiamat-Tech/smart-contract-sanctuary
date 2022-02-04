// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ERC721Token.sol";

pragma solidity >=0.8.9;

contract Factory is Ownable {
    event ERC721TokenCreated(address tokenAddress);

    function deployNewERC721Token(
        string memory name,
        string memory symbol,
        string memory initBaseURI,
        string memory initNotRevealedUri,
        uint256 _maxSupply,
        uint256 _price,
        uint256 _maxMintPerTx,
        address _AddressPayment
    ) external returns (address) {
        ERC721Token t = new ERC721Token(
            name,
            symbol,
            initBaseURI,
            initNotRevealedUri,
            _maxSupply,
            _price,
            _maxMintPerTx,
            _AddressPayment
        );
        Ownable(address(t)).transferOwnership(_msgSender());
        emit ERC721TokenCreated(address(t));

        return address(t);
    }
}