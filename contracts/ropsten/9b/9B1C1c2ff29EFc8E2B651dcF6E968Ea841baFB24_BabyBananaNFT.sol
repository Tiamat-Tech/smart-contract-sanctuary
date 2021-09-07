// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IERC1155MetadataURI.sol";
import "./IERC1155Receiver.sol";
import "./IBabyBananaNFT.sol";
import "./EnumerableSet.sol";
import "./Address.sol";

contract BabyBananaNFT is IERC1155MetadataURI, IERC165, IBabyBananaNFT {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.UintSet;
    using Address for address;

    struct Metadata {
        bool isStackable;
        bool isConsumable;
        bool isStakeable;
        bool isUnique;
        uint256 price;
        uint256 stakingRewardShare;
        address rewardToken;
    }
    
    // Initial features
    uint8 constant BUYBACK = 0;
    uint8 constant CHESS_GAME = 1;
    uint8 constant SPACE_CENTER = 2;
    uint8 constant TAX_DISCOUNT = 3;
    uint8 constant REWARD_BOOST = 4;
    uint8 constant REWARD_TOKEN = 5;
    uint8 constant LOTTERY_TICKET = 6;
    
    address constant BANANA = 0x603c7f932ED1fc6575303D8Fb018fDCBb0f39a95;
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address constant ZERO = 0x0000000000000000000000000000000000000000;
    address constant MULTI_SIG_TEAM_WALLET = 0x48e065F5a65C3Ba5470f75B65a386A2ad6d5ba6b;

    address public maintenanceWallet = 0xda83D3257E8880e44Cfe8e8690b9d6c283d397c6;
    address public museum = 0xD5E81e25bB36A94d64Eb844b905546Ff8f29DB8D;
    address public token;
    
    string _uri;
    EnumerableSet.UintSet _tokenIds;
    
    mapping(uint256 => mapping(uint8 => uint256)) public tokenFeatureValue;
    mapping(uint256 => Metadata) public  tokenMetadata;
    mapping(uint256 => uint256) public minted;
    mapping(uint256 => bool) public isFrozen;
    
    mapping(address => bool) _isLimitExempt; // Excluded addresses from holding limitations
    mapping(address => bool) _isHolderExempt; // Excluded addresses from perks (ignored from holders)
    mapping(uint256 => uint8[]) _tokenFeatureIds; // Helper to iterate token feature values
    mapping(uint256 => EnumerableSet.AddressSet) _holders; // Addresses that hold token
    mapping(address => EnumerableSet.UintSet) _usersTokens; // Token ids that user is holding (used to determine features and their values)
    
    mapping(uint256 => mapping(address => uint256)) _balances;
    mapping(address => mapping(address => bool)) _operatorApprovals;

    modifier onlyMaintenance() {
        require(msg.sender == maintenanceWallet);
        _;
    }

    modifier onlyTeam() {
        require(msg.sender == MULTI_SIG_TEAM_WALLET);
        _;
    }

    modifier onlyToken() {
        require(msg.sender == token);
        _;
    }

    modifier onlyMuseum() {
        require(msg.sender == museum);
        _;
    }

    constructor() {
        _setURI("https://babybanana.finance/nft/api/{id}");
        
        _isHolderExempt[ZERO] = true;
        _isLimitExempt[ZERO] = true;
        _isHolderExempt[DEAD] = true;
        _isLimitExempt[DEAD] = true;

        _isHolderExempt[maintenanceWallet] = true;
        _isLimitExempt[maintenanceWallet] = true;
    }
    
    function uri(uint256) public view virtual override returns (string memory) {
        return _uri;
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            interfaceId == type(IERC165).interfaceId;
    }

    function balanceOf(address account, uint256 id) public view virtual override(IBabyBananaNFT, IERC1155) returns (uint256) {
        require(account != ZERO, "ERC1155: balance query for the zero address");
        return _balances[id][account];
    }

    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(msg.sender != operator, "ERC1155: setting approval status for self");

        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override(IBabyBananaNFT, IERC1155) {
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "ERC1155: caller is not owner nor approved"
        );
        _safeTransferFrom(msg.sender, from, to, id, amount, data);
    }

    function _safeTransferFrom(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != ZERO, "ERC1155: transfer to the zero address");
        
        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;
        
        emit TransferSingle(operator, from, to, id, amount);

        if (!_isLimitExempt[to]) { _doTransferCheck(to, id); }
        _handleHolderCount(from, to, id);
        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }
    
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == msg.sender || isApprovedForAll(from, msg.sender),
            "ERC1155: transfer caller is not owner nor approved"
        );
        _safeBatchTransferFrom(msg.sender, from, to, ids, amounts, data);
    }
    
    function _safeBatchTransferFrom(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != ZERO, "ERC1155: transfer to the zero address");
        
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            
            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
            
            if (!_isLimitExempt[to]) { _doTransferCheck(to, id); }
            _handleHolderCount(from, to, id);
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }
    
    // Private helpers
    
    function _setURI(string memory newuri) private {
        _uri = newuri;
    }
    
    function _doTransferCheck(address recipient, uint256 tokenId) private view {
        if (!tokenMetadata[tokenId].isStackable) { _checkNonStackables(recipient); }
        if (tokenMetadata[tokenId].rewardToken != address(0)) { _checkRewardNFT(recipient); }
    }
    
    function _checkRewardNFT(address recipient) private view {
        for (uint256 i; i < _usersTokens[recipient].length(); i++) {
            uint256 tokenId = _usersTokens[recipient].at(i);
            require(tokenMetadata[tokenId].rewardToken == address(0), "Recipient has active reward NFT");
        }
    }
    
    function _checkNonStackables(address recipient) private view {
        for (uint256 i; i < _usersTokens[recipient].length(); i++) {
            uint256 tokenId = _usersTokens[recipient].at(i);
            require(tokenMetadata[tokenId].isStackable, "Recipient has non-stackable NFT");
        }
    }
    
    function _handleHolderCount(address sender, address recipient, uint256 tokenId) private {
        bool isEmptyWallet = _balances[tokenId][sender] == 0;
        if (isEmptyWallet) { _holders[tokenId].remove(sender); _usersTokens[sender].remove(tokenId); }
        
        bool hasToken = _balances[tokenId][recipient] > 0;
        if (!_isHolderExempt[recipient] && hasToken) { _holders[tokenId].add(recipient); _usersTokens[recipient].add(tokenId); }
    }

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver(to).onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }
    
    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver(to).onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non ERC1155Receiver implementer");
            }
        }
    }
    
    // Custom interface

    function consume(uint256 tokenId, address sender) external override onlyToken {
        require(tokenMetadata[tokenId].isConsumable, "Token is not consumable");
        
        _safeTransferFrom(sender, sender, DEAD, tokenId, 1, "");
    }

    function stake(uint256 tokenId, address sender) external override onlyMuseum {
        require(tokenMetadata[tokenId].isStakeable, "Token is not stakeable");

        _safeTransferFrom(sender, sender, museum, tokenId, 1, "");
    }

    function priceOf(uint256 tokenId) external view override returns (uint256) {
        return tokenMetadata[tokenId].price;
    }

    function stakingRewardShareOf(uint256 tokenId, address account) external view override returns (uint256) {
        if (_isHolderExempt[account]) { return 0; }

        for (uint256 i; i < _usersTokens[account].length(); i++) {
            uint256 id = _usersTokens[account].at(i);
            if (tokenId == id) { return tokenMetadata[tokenId].stakingRewardShare; }
        }

        return 0;
    }
    
    function featureValueOf(uint8 featureId, address account) public view override returns (uint256) {
        if (_isHolderExempt[account]) { return 0; }

        uint256 largestFeatureValue;
        for (uint256 i; i < _usersTokens[account].length(); i++) {
            uint256 tokenId = _usersTokens[account].at(i);

            for (uint256 j; j < _tokenFeatureIds[tokenId].length; j++) {
                uint8 feature = _tokenFeatureIds[tokenId][j];
                uint256 featureValue = tokenFeatureValue[tokenId][feature];
                if (feature == featureId && featureValue > largestFeatureValue) {
                    largestFeatureValue = featureValue; 
                }
            }
        }
        
        return largestFeatureValue;
    }

    function lotteryTicketsOf(address account) external view override returns (uint256) {
        if (_isHolderExempt[account]) { return 0; }

        uint256 lotteryTickets;
        for (uint256 i; i < _usersTokens[account].length(); i++) {
            uint256 tokenId = _usersTokens[account].at(i);

            for (uint256 j; j < _tokenFeatureIds[tokenId].length; j++) {
                uint8 feature = _tokenFeatureIds[tokenId][j];
                if (feature == LOTTERY_TICKET) { lotteryTickets += tokenFeatureValue[tokenId][feature]; }
            }
        }
        
        return lotteryTickets;
    }

    function rewardTokenFor(address account) external view override returns (address) {
        if (_isHolderExempt[account]) { return BANANA; }

        for (uint256 i; i < _usersTokens[account].length(); i++) {
            uint256 tokenId = _usersTokens[account].at(i);
            address rewardToken = tokenMetadata[tokenId].rewardToken;
            if (rewardToken != address(0)) { return rewardToken; }
        }

        return BANANA;
    }
    
    function createdTokensAmount() external view returns (uint256) {
        return _tokenIds.length();
    }

    // Helpers to iterate token holders
    
    function tokenHoldersAmount(uint256 tokenId) external view returns (uint256) {
        return _holders[tokenId].length();
    }
    
    function tokenHolder(uint256 tokenId, uint256 index) external view returns (address) {
        return _holders[tokenId].at(index);
    }

    // Helpers to iterate token feature ids

    function tokenFeatureIdsAmount(uint256 tokenId) external view returns (uint256) {
        return _tokenFeatureIds[tokenId].length;
    }

    function tokenFeatureId(uint256 tokenId, uint256 index) external view returns (uint8) {
        return _tokenFeatureIds[tokenId][index];
    }

    // Helpers to iterate tokens that user hold

    function userTokensAmount(address account) external view returns (uint256) {
        return _usersTokens[account].length();
    }

    function userToken(address account, uint256 index) external view returns (uint256) {
        return _usersTokens[account].at(index);
    }
    
    // Team

    function setURI(string memory newUri) external onlyTeam {
        _uri = newUri;
    }

    function updateMaintenanceWallet(address newAddress) external onlyTeam {
        _isHolderExempt[maintenanceWallet] = false;
        _isLimitExempt[maintenanceWallet] = false;
        _isHolderExempt[newAddress] = true;
        _isLimitExempt[newAddress] = true;
        maintenanceWallet = newAddress;
    }

    function updateMuseum(address newMuseum) external onlyTeam {
        museum = newMuseum;
    }

    function updateToken(address newToken) external onlyTeam {
        token = newToken;
    }

    function setLimitExempt(address account, bool exempt) external onlyTeam {
        require(account != maintenanceWallet && account != ZERO && account != DEAD, "Unauthorized parameter address");
        
        _isLimitExempt[account] = exempt;
    }
    
    /**
     * @notice Use with caution because account is not automatically added back to holder with perks.
    */
    function setHolderExempt(address account, bool exempt) external onlyTeam {
        require(account != maintenanceWallet && account != ZERO && account != DEAD, "Unauthorized parameter address");
        
        if (exempt) {
            for (uint256 i; i < _tokenIds.length(); i++) {
                _holders[_tokenIds.at(i)].remove(account);
                _usersTokens[account].remove(_tokenIds.at(i));
            }
        }
        
        _isHolderExempt[account] = exempt;
    }

    // Maintenance

    function updateFeatureValue(uint256 tokenId, uint8 featureId, uint256 newValue) external onlyMaintenance {
        require(_tokenIds.contains(tokenId), "Token id doesn't exist");
        
        bool hasFeatureId;
        for (uint256 i; i < _tokenFeatureIds[tokenId].length; i++) {
            uint8 feature = _tokenFeatureIds[tokenId][i];
            if (feature == featureId) { hasFeatureId = true; }
        }
        require(hasFeatureId, "Token doesn't have feature");
        
        tokenFeatureValue[tokenId][featureId] = newValue;
    }

    function updateStakingRewardShare(uint256 tokenId, uint256 newShare) external onlyMaintenance {
        require(_tokenIds.contains(tokenId), "Token id doesn't exist");

        tokenMetadata[tokenId].stakingRewardShare = newShare;
    }

    function setTokenPrice(uint256 tokenId, uint256 newPrice) external onlyMaintenance {
        require(_tokenIds.contains(tokenId), "Token id doesn't exist");

        tokenMetadata[tokenId].price = newPrice;
    }

    function freezeMinting(uint256 tokenId) external onlyMaintenance {
        isFrozen[tokenId] = true;
    }

    // Creation

    /**
     * @notice Create new token for this collection.
     * @notice Marketing still need to mint tokens separately.
     * @notice Calling of this function is limited to maintenance wallet.
     * @param tokenId Token id to be added in the collection.
     * @param metadata Token metadata.
     * @param featureIds List of feature ids to be added as a token features.
     * @param featureValues List of feature values.
    */
    function addToken(
        uint256 tokenId,
        Metadata calldata metadata,
        uint8[] calldata featureIds,
        uint256[] calldata featureValues
    ) public onlyMaintenance {
        require(minted[tokenId] == 0, "Can't modify minted tokens");
        require(!_tokenIds.contains(tokenId), "Token id is already created");
        require(featureIds.length == featureValues.length, "Parameter length mismatch");
        
        _tokenIds.add(tokenId);
        tokenMetadata[tokenId] = metadata;
        if (metadata.isConsumable) { require(featureIds.length == 1, "Consumable can't have many perks"); }
        
        for (uint256 i; i < featureIds.length; i++) {
            uint8 featureId = featureIds[i];
            _tokenFeatureIds[tokenId].push(featureId);
            tokenFeatureValue[tokenId][featureId] = featureValues[i];
        }
    }

    /**
     * @notice Same as addToken, but add multiple token configs at once.
     * @notice Marketing still need to mint tokens separately.
     * @notice Calling of this function is limited to maintenance wallet.
     * @param tokenIds List of token ids to be added in the collection.
     * @param metadatas List of token metadatas.
     * @param arrayOffeatureIds Multidimensional array of feature ids.
     * @param arrayOfFeatureValues Multidimensional array of feature values.
    */
    function addTokenBatch(
        uint256[] calldata tokenIds,
        Metadata[] calldata metadatas,
        uint8[][] calldata arrayOffeatureIds,
        uint256[][] calldata arrayOfFeatureValues
    ) external onlyMaintenance {
        bool validParametersLengths = tokenIds.length == metadatas.length && 
            metadatas.length == arrayOffeatureIds.length &&
            arrayOffeatureIds.length == arrayOfFeatureValues.length;
        require(validParametersLengths, "Parameter length mismatch");

        for (uint256 i; i < tokenIds.length; i++) {
            addToken(tokenIds[i], metadatas[i], arrayOffeatureIds[i], arrayOfFeatureValues[i]);
        }
    }
    
    /**
     * @notice Remove token from this collection.
     * @notice Token to be removed must have been created before removal.
     * @notice Minted tokens cannot be removed.
     * @notice Calling of this function is limited to maintenance wallet.
     * @param tokenId Id of the token to be removed.
    */
    function removeToken(uint256 tokenId) external onlyMaintenance {
        require(_tokenIds.contains(tokenId), "Token id doesn't exist");
        require(minted[tokenId] == 0, "Can't modify minted tokens");
        
        _tokenIds.remove(tokenId);
        
        for (uint256 i; i < _tokenFeatureIds[tokenId].length; i++) {
            uint8 featureId = _tokenFeatureIds[tokenId][i];
            delete tokenFeatureValue[tokenId][featureId];
        }
        
        delete _tokenFeatureIds[tokenId];
        delete tokenMetadata[tokenId];
    }

    /**
     * @notice Mint new NFTs. Passed id must be created by calling addToken before minting.
     * @notice Minter doesn't gain any perks of the NFTs.
     * @notice Calling of this function is limited to maintenance wallet.
     * @param id Id of the token to be minted.
     * @param amount Amount of tokens to be minted.
    */
    function mint(uint256 id, uint256 amount) external onlyMaintenance {
        require(_tokenIds.contains(id), "Token id doesn't exist");
        require(!isFrozen[id], "Token id is frozen from minting");
        
        if (tokenMetadata[id].isUnique) { require(minted[id] == 0 && amount == 1, "Can't mint more than 1 NFT"); }
        minted[id] += amount;

        _balances[id][msg.sender] += amount;
        emit TransferSingle(msg.sender, ZERO, msg.sender, id, amount);

        _doSafeTransferAcceptanceCheck(msg.sender, ZERO, msg.sender, id, amount, "");
    }

    /**
     * @notice Same as mint function, but mint multiple NFTs at once.
     * @notice Minter doesn't gain any perks of the NFTs.
     * @notice Both parameters MUST have same length.
     * @notice Calling of this function is limited to maintenance wallet.
     * @param ids List of ids of tokens to be minted.
     * @param amounts List of amounts of tokens to be minted.
    */
    function mintBatch(uint256[] memory ids, uint256[] memory amounts) external onlyMaintenance {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];
            
            require(_tokenIds.contains(id), "Token id doesn't exist");
            require(!isFrozen[id], "Token id is frozen from minting");
            
            if (tokenMetadata[id].isUnique) { require(minted[id] == 0 && amount == 1, "Can't mint more than 1 NFT"); }
            minted[id] += amount;
            _balances[id][msg.sender] += amount;
        }

        emit TransferBatch(msg.sender, ZERO, msg.sender, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(msg.sender, ZERO, msg.sender, ids, amounts, "");
    }
}