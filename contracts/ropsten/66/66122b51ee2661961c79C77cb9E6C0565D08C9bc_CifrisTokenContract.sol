// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// Nuovo Cifris Token
contract CifrisTokenContract is ERC721, Ownable {

    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    // На какой токен назначен хеш для данных
    mapping(uint256 => uint256) private hashes;

    // Коммиссия за выпуск токена
    // TODO Оплачивать комиссию ERC20
    address payable private feeRecipient;
    uint128 private feeOfCreateEth = 0;
    uint128 private feeOfCreateErc20orBep20 = 0;
    IERC20 private erc20OrBep20Token;

    // После какого времени считать скомпроментирвоанным ключ
    mapping(address => uint64) private compromisesManufactures;

    // Конструктор
    constructor() ERC721("Nuovo Cifris NFT", "CFR") {
        // Потому что feeRecipient is payable
        feeRecipient = payable(address(_msgSender()));
    }

    // Поддерживаемые интерфейсы
    function supportsInterface(bytes4 interfaceId) public pure override returns (bool) {
        return interfaceId == type(IERC165).interfaceId
            || interfaceId == type(IERC721).interfaceId;
    }

    // Выпуск токена с хешем защищаемых данных
    function mintWithDataHash(address recipient, uint256 hash)
    public
    returns (uint256)
    {
        require(feeOfCreateEth == 0);
        require(feeOfCreateErc20orBep20 == 0);
        return _mintWithDataHash(recipient, hash);
    }

    // Выпуск токена с хешем защищаемых данных
    function mintWithDataHashWithFeeOfEth(address recipient, uint256 hash)
    public
    // payable
    returns (uint256)
    {
        require(address(feeRecipient) != address(0));
        require(feeOfCreateEth > 0);

        feeRecipient.transfer(feeOfCreateEth);

        return _mintWithDataHash(recipient, hash);
    }

    // Выпуск токена с хешем защищаемых данных
    function mintWithDataHashWithFeeOfErc20orBep20(address recipient, uint256 hash)
    public
    // payable
    returns (uint256)
    {
        require(address(feeRecipient) != address(0));
        require(feeOfCreateErc20orBep20 > 0);

        // Оплачиваем комиссию, а если не хватает, то будет откат назад
        erc20OrBep20Token.transferFrom(_msgSender(), feeRecipient, feeOfCreateErc20orBep20);

        return _mintWithDataHash(recipient, hash);
    }

    // Выпуск токена с хешем защищаемых данных
    function _mintWithDataHash(address recipient, uint256 hash)
    internal
    returns (uint256)
    {
        _tokenIds.increment();
        uint256 newItemId = _tokenIds.current();
        _mint(recipient, newItemId);

        hashes[newItemId] = hash;

        return newItemId;
    }

    // Часть ERC721 стандарта
    function _baseURI() internal pure override returns (string memory) {
        return 'https://cifris.com/nft/';
    }

    // Установить комиссию в эфире
    function setFeeOfCreateEth(uint128 fee) public onlyOwner {
        feeOfCreateEth = fee;
    }

    // Установить комиссию в эфире
    function setErc20OrBep20Token(IERC20 token) public onlyOwner {
        erc20OrBep20Token = token;
    }

    // Вернуть хеш данных
    function getDataHash(uint256 tokenId) public view returns (uint256) {
        return hashes[tokenId];
    }

    // Добавить компроментацию для производителя
    function setCompromise(address manufacturer, uint64 timestamp) public onlyOwner {
        compromisesManufactures[manufacturer] = timestamp;
    }

    // Вернуть: скомпроментирован ли ключ производителя и когда
    function getCompromise(address manufacturer) public view returns (uint64) {
        return compromisesManufactures[manufacturer];
    }

    // Вернуть адрес для получения комиссий
    function getFeeRecipient() public view returns (address payable) {
        return feeRecipient;
    }

    // Установить получателя комиссии
    function setFeeRecipient(address payable recipient) public onlyOwner {
        feeRecipient = recipient;
    }

    // Вернуть размер комиссии в ETH
    function getFeeOfCreateEth() public view returns (uint128) {
        return feeOfCreateEth;
    }

    // Вернуть размер комиссии в ETH
    function getFeeOfCreateErc20orBep20() public view returns (uint128) {
        return feeOfCreateErc20orBep20;
    }
}