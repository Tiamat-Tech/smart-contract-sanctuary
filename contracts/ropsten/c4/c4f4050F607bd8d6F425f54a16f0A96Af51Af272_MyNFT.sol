// SPDX-License-Identifier: MIT
pragma solidity ^0.7.3;

// based on https://docs.openzeppelin.com/contracts/3.x/erc721
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// IMPORTANTE: este smart contract no posee ninguna función con capacidad de compra (payable).
//             se podría transferir a otra cuenta, pero no estaría atado al pago de un valor.

contract MyNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // nombre del smart contract y símbolo
    constructor() ERC721("MyNFT", "NFT") {}

    // permite acuñar un NFT
    // `recipient` especifica la dirección que recibirá el NFT recién acuñado
    // `tokenURI` especifica la URL donde se almacena el JSON que describe los metadatos del NFT
    function mintNFT(address recipient, string memory tokenURI)
        public onlyOwner
        returns (uint256)
    {
        _tokenIds.increment();

        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);
        _setTokenURI(newItemId, tokenURI);

        return newItemId;
    }
}