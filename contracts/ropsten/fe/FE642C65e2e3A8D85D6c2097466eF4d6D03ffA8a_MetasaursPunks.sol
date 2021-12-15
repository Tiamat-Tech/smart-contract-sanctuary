// SPDX-License-Identifier: MIT
pragma solidity >=0.8.2 <0.9.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * ╔═╗╔═╗░░╔╗░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
 * ║║╚╝║║░╔╝╚╗░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
 * ║╔╗╔╗╠═╩╗╔╬══╦══╦══╦╗╔╦═╦══╗  Metasaurs Punks  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
 * ║║║║║║║═╣║║╔╗║══╣╔╗║║║║╔╣══╣  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
 * ║║║║║║║═╣╚╣╔╗╠══║╔╗║╚╝║║╠══║  Website: https://www.metasaurs.com/  ░░░░░░░░░
 * ╚╝╚╝╚╩══╩═╩╝╚╩══╩╝╚╩══╩╝╚══╝  Discord: https://discord.com/invite/metasaurs
 *
 * @notice ERC1155 contract (non fungible) of Metasaurs Punks
 * @custom:security-contact [email protected]
 */

contract MetasaursPunks is ERC1155, Ownable, ERC1155Supply {
    using ECDSA for bytes32;

    /// @notice Minting limits
    uint256 public constant MAX_SUPPLY = 19999;

    /// @notice Token bought per address
    mapping(address => uint256) public bought;

    /// @notice Payment receiver
    address payable private receiver;

    /// @notice ID of the last NFT
    uint256 public lastId = 0;

    /// @notice Executed transactions
    mapping(bytes32 => bool) public executed;

    /// @notice Hash signer
    address internal signer;

    /**
     * @notice Called once on deploy
     * @param uri_ - baseURI string
     */
    constructor(string memory uri_) ERC1155(uri_) {
        receiver = payable(msg.sender);
        signer = msg.sender;
    }

    /**
     * @notice Change baseURI
     * @param newURI - New baseURI string
     */
    function setURI(string memory newURI) external onlyOwner {
        _setURI(newURI);
    }

    /**
     * @notice Change payment receiver
     * @param newReceiver - New payment receiver
     */
    function setReceiver(address payable newReceiver) public onlyOwner {
        require(newReceiver != address(0), "incorrect address");
        receiver = newReceiver;
    }

    /**
     * @notice Change tx signer
     * @param newSigner - New payment receiver
     */
    function setSigner(address newSigner) public onlyOwner {
        require(newSigner != address(0), "incorrect address");
        signer = newSigner;
    }

    /**
     * @notice Buy single token
     * @param account - Buyer
     * @param amount - Amount of tokens to buy
     */
    function buy(address account, uint256 amount) external payable {
        require(account != address(0), "incorrect address");
        require(amount > 0, "incorrect amount");
        require(msg.value == 9e17 * amount, "incorrect ethers amount");

        // Mint tokens and charge ethers
        _mintPunks(account, amount);
        receiver.transfer(msg.value);
    }

    /**
     * @notice Airdrop for some users
     * @param accounts - Array of user addresses
     */
    function airdrop(address[] memory accounts) external onlyOwner {
        require(accounts.length + lastId <= MAX_SUPPLY, "max supply overflow");
        for (uint256 i = 0; i < accounts.length; i++) {
            require(accounts[i] != address(0), "incorrect address");
            _mintPunks(accounts[i], 1);
        }
    }

    /**
     * @notice Buy with whitelist
     * @param account - Buyer
     * @param amount - Amount of tokens to buy
     */
    function privateBuy(
        bytes calldata _signature,
        bytes calldata _UUID,
        uint256 amount,
        address account,
        uint256 totalPrice
    ) public payable {
        require(account != address(0), "incorrect address");
        require(amount > 0, "incorrect amount");

        // Price
        uint256 price = _calcPrice(account, amount);
        require(msg.value == price && price == totalPrice, "incorrect price");

        // Signature verification
        bytes32 msgHash = keccak256(
            abi.encode(msg.sender, _UUID, amount, account, totalPrice)
        );
        require(!executed[msgHash], "has been executed!");
        executed[msgHash] = true;
        require(
            msgHash.toEthSignedMessageHash().recover(_signature) == signer,
            "signer not recovered from signed tx!"
        );

        // Mint tokens and charge ethers
        bought[account] += amount;
        _mintPunks(account, amount);
        receiver.transfer(msg.value);
    }

    /**
     * @notice Owner's mint probability for awards
     * @param account - Awarded address
     * @param amount - Amount of tokens to mint
     */
    function mint(address account, uint256 amount) public onlyOwner {
        require(account != address(0), "incorrect address");
        require(amount == 1, "incorrect amount");

        _mintPunks(account, amount);
    }

    /**
     * @notice Calculate price for whitelist buyers
     * @param buyer - Address of buyer
     * @param amount - How many tokens to mint
     */
    function _calcPrice(address buyer, uint256 amount)
        internal
        view
        returns (uint256 price)
    {
        price = 0;
        for (uint256 i = bought[buyer]; i <= amount; i++) {
            if (i == 0) {
                price += 8e17;
            } else {
                price += 6e17;
            }
        }
    }

    /**
     * @notice Get and check next token ID
     */
    function _getId() internal returns (uint256) {
        require(lastId + 1 <= MAX_SUPPLY, "max supply reached");
        lastId++;
        return lastId;
    }

    /**
     * @notice Get and check next tokens ID and push amounts to array
     * @param amount - How many tokens to mint
     */
    function _getIds(uint256 amount)
        internal
        returns (uint256[] memory ids, uint256[] memory amounts)
    {
        require(lastId + amount <= MAX_SUPPLY, "more than max supply");
        ids = new uint256[](amount);
        amounts = new uint256[](amount);
        for (uint16 i = 0; i < amount; i++) {
            lastId++;
            ids[i] = lastId;
            amounts[i] = 1;
        }
    }

    /**
     * @notice Mint metasaurs
     * @param account - Buyer address
     * @param amount - Amount of tokens to mint
     */
    function _mintPunks(address account, uint256 amount) internal {
        if (amount == 1) {
            _mint(account, _getId(), 1, "");
        } else {
            (uint256[] memory ids, uint256[] memory amounts) = _getIds(amount);
            _mintBatch(account, ids, amounts, "");
        }
    }

    // The following functions are overrides required by Solidity.
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}