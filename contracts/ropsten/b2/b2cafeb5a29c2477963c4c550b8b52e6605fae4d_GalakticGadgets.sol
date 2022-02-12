/**
  ________       .__          __      __  .__           ________                       
 /  _____/_____  |  | _____  |  | ___/  |_|__| ____    /  _____/_____    ____    ____  
/   \  ___\__  \ |  | \__  \ |  |/ /\   __\  |/ ___\  /   \  ___\__  \  /    \  / ___\ 
\    \_\  \/ __ \|  |__/ __ \|    <  |  | |  \  \___  \    \_\  \/ __ \|   |  \/ /_/  >
 \______  (____  /____(____  /__|_ \ |__| |__|\___  >  \______  (____  /___|  /\___  / 
        \/     \/          \/     \/              \/          \/     \/     \//_____/  

Art By: Chris Dyer
Contract By: Travis Delly
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Openzep
import '@openzeppelin/contracts-upgradeable/utils/cryptography/ECDSAUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol';

import './Helpers/Base.sol';

contract GalakticGadgets is GalakticBase, ERC1155SupplyUpgradeable {
    event Purchased(
        uint256 indexed index,
        address indexed account,
        uint256 amount
    );

    struct Gadget {
        // 1
        string name;
        string ipfsMetadataHash;
        // 1
        uint128 mintPrice;
        uint64 id;
        uint64 maxPurchaseTx;
        // 1
        uint64 maxSupply;
        bool mintable;
        uint8 mintPriceGG;
        uint176 _gap;
    }

    string public name_;
    string public symbol_;
    uint256 counter;

    mapping(uint256 => Gadget) public gadgets;
    mapping(address => bool) internal externalCallers;
    mapping(address => uint256) public usedMembers;

    modifier onlyExternalCaller() {
        require(externalCallers[msg.sender], 'Caller is not allowed');
        _;
    }

    function initialize(string memory _name, string memory _symbol)
        public
        initializer
    {
        __ERC1155_init('ipfs://');
        __GalakticBase_init();
        name_ = _name;
        symbol_ = _symbol;
    }

    function name() public view returns (string memory) {
        return name_;
    }

    function symbol() public view returns (string memory) {
        return symbol_;
    }

    /**
     * @notice adds a new gadget
     */
    function addGadget(
        string memory _name,
        string memory _ipfsMetadataHash,
        uint128 _mintPrice,
        uint8 _mintPriceGG,
        uint64 _maxPurchaseTx,
        uint64 _maxSupply
    ) public onlyOwner {
        Gadget storage util = gadgets[counter];
        util.id = uint64(counter);
        util.maxPurchaseTx = _maxPurchaseTx;
        util.ipfsMetadataHash = _ipfsMetadataHash;
        util.name = _name;
        util.mintPrice = _mintPrice;
        util.mintPriceGG = _mintPriceGG;
        util.maxSupply = _maxSupply;
        util.mintable = true;

        counter++;
    }

    /**
     * @notice edit an existing gadget
     */
    function editGadget(
        string memory _name,
        string memory _ipfsMetadataHash,
        uint128 _mintPrice,
        uint8 _mintPriceGG,
        uint64 _maxPurchaseTx,
        uint64 _maxSupply,
        uint256 _idx
    ) external onlyOwner {
        require(exists(_idx), 'EditGadget: Gadget does not exist');
        gadgets[_idx].ipfsMetadataHash = _ipfsMetadataHash;
        gadgets[_idx].mintPrice = _mintPrice;
        gadgets[_idx].mintPriceGG = _mintPriceGG;
        gadgets[_idx].maxSupply = _maxSupply;
        gadgets[_idx].maxPurchaseTx = _maxPurchaseTx;
        gadgets[_idx].name = _name;
    }

    /**
     * @notice make gadget mintable
     */
    function updateMintable(uint256 _idx, bool _mintable) external onlyOwner {
        gadgets[_idx].mintable = _mintable;
    }

    /**
     * @notice mint gadget tokens
     *
     * @param gadgetIdx the gadget id to mint
     * @param amount the amount of tokens to mint
     */
    function mint(
        uint256 gadgetIdx,
        uint256 amount,
        address to
    ) external onlyOwner {
        require(exists(gadgetIdx), 'Mint: Gadget does not exist');
        require(
            totalSupply(gadgetIdx) + amount < gadgets[gadgetIdx].maxSupply,
            'Mint: Max supply reached'
        );

        _mint(to, gadgetIdx, amount, '');

        emit Purchased(gadgetIdx, to, amount);
    }

    /**
     * @notice mint gadget tokens
     *
     * @param gadgetIdx the gadget id to mint
     * @param amount the amount of tokens to mint
     */
    function mintExternal(
        uint256 gadgetIdx,
        uint256 amount,
        address to
    ) external onlyExternalCaller {
        require(exists(gadgetIdx), 'Mint: Gadget does not exist');
        require(
            totalSupply(gadgetIdx) + amount < gadgets[gadgetIdx].maxSupply,
            'Mint: Max supply reached'
        );

        _mint(to, gadgetIdx, amount, '');

        emit Purchased(gadgetIdx, to, amount);
    }

    /**
     * @notice mint gadget tokens
     *
     * @param gadgetIdx the gadget id to mint
     * @param amount the amount of tokens to mint
     */
    function bulkMint(
        uint256 gadgetIdx,
        uint256 amount,
        address[] calldata to
    ) external onlyOwner {
        require(exists(gadgetIdx), 'Mint: Gadget does not exist');

        for (uint256 i = 0; i < to.length; i++) {
            require(gadgets[gadgetIdx].mintable, 'Gadget is not mintable');
            require(
                totalSupply(gadgetIdx) + amount < gadgets[gadgetIdx].maxSupply,
                'Mint: Max supply reached'
            );

            _mint(to[i], gadgetIdx, amount, '');

            emit Purchased(gadgetIdx, to[i], amount);
        }
    }

    /**@notice purchase gadget tokens, free for galaktic holders */
    function purchase(
        uint256[] calldata gadgetIds,
        uint256[] calldata amount,
        bytes memory signature,
        uint256 members
    ) external whenNotPaused {
        // Ensure whitelist
        bytes32 messageHash = sha256(abi.encode(msg.sender, members));
        require(
            ECDSAUpgradeable.recover(messageHash, signature) == owner,
            'Mint: Invalid Signature, are you whitelisted bud?'
        );

        for (uint256 i = 0; i < gadgetIds.length; i++) {
            require(gadgets[i].mintable, 'Gadget is not mintable');
            require(
                totalSupply(i) + amount[i] < gadgets[i].maxSupply,
                'Mint: Max supply reached'
            );

            usedMembers[msg.sender] +=
                amount[i] *
                gadgets[gadgetIds[i]].mintPriceGG;

            require(
                usedMembers[msg.sender] < members,
                'Over Purchased, Chose less items.'
            );

            _mint(msg.sender, gadgetIds[i], amount[i], '');
        }
    }

    /**
     * @notice Triggers a transfer to `account` of the amount of Ether they are owed, according to their percentage of the
     * total shares and their previous withdrawals.
     */
    function release(address to) external onlyOwner {
        uint256 balance = address(this).balance;

        payable(to).transfer(balance);
    }

    /**
     * @notice return total supply for all existing gadgets
     */
    function totalSupplyAll() external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](counter);

        for (uint256 i; i < counter; i++) {
            result[i] = totalSupply(i);
        }

        return result;
    }

    /**
     *   @notice gets habitatgadgets
     */
    function getGadgets() external view returns (Gadget[] memory) {
        Gadget[] memory _utils = new Gadget[](counter);

        for (uint256 i = 0; i < counter; i++) {
            _utils[i] = gadgets[i];
        }

        return _utils;
    }

    /** @notice get current idx */
    function getCurrentCounter() external view returns (uint256) {
        return counter;
    }

    /**
     * @notice indicates weither any token exist with a given id, or not
     */
    function exists(uint256 id) public view override returns (bool) {
        return gadgets[id].maxSupply > 0;
    }

    /**
     * @notice returns the metadata uri for a given id
     *
     * @param _id the gadget id to return metadata for
     */
    function uri(uint256 _id) public view override returns (string memory) {
        require(exists(_id), 'URI: nonexistent token');

        return
            string(
                abi.encodePacked(super.uri(_id), gadgets[_id].ipfsMetadataHash)
            );
    }

    /** @notice idk */
    function getUsedMembers(address account) external view returns (uint256) {
        return usedMembers[account];
    }

    /** Setters */

    /**
     * @notice sets an external caller
     */
    function setExternalCaller(address caller, bool enabled)
        external
        onlyOwner
    {
        externalCallers[caller] = enabled;
    }
}