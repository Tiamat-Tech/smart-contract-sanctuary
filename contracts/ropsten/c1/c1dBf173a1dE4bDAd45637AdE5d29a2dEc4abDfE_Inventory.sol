// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ERC1155Base.sol";

/**
 * @title Team3D's Inventory V3
 */
contract Inventory is ERC1155Base {
    /// @notice Event emitted when an approved game created a new item based on a template.
    event ItemFromTemplateCreated(
        uint256 templateId,
        uint8 feature1,
        uint8 feature2,
        uint8 feature3,
        uint8 feature4,
        uint8 equipmentPosition,
        uint256 amount,
        address player,
        uint256 tokenId
    );

    /// @notice Event emitted when an approved game changed features of an item.
    event FeaturesForItemChanged(
        uint256 tokenId,
        uint8 feature1,
        uint8 feature2,
        uint8 feature3,
        uint8 feature4,
        uint8 equipmentPosition,
        address player
    );

    /// @notice Event emitted when a token's amount (supply, balance) is increased.
    event TokenAmountsIncreased(
        address tokenOwner,
        uint256 tokenId,
        uint256 amount
    );

    /// @notice Event emitted when a token is burnt.
    event Burnt(
        address owner,
        uint256 tokenId,
        uint256 amount,
        uint256 treasureChestRewardsForToken,
        uint256 treasureHuntPoints
    );

    // Treasure chest reward token
    IERC20 public treasureChestRewardToken;

    // Mapping of contract addresses that are allowed to create items and edit item features based on a templateId 
    mapping(uint256 => mapping(address => bool)) public templateApprovedGames;

    // Mapping from token ID to respective treasure chest rewards in VIDYA tokens
    mapping(uint256 => uint256) public treasureChestRewards;

    // Mapping to calculate how many treasure hunts an address has participated in
    mapping(address => uint256) public treasureHuntPoints;

    // Mapping for the different equipment items of each address/character
    // 0 - head, 1 - left hand, 2 - neck, 3 - right hand, 4 - chest, 5 - legs, 6 - feet slot, 7 - cape slot, 8 - belt slot, 9 - companion, 10 - non wearable
    mapping(address => uint256[11]) public characterEquipment;

    // To check if a template exists
    mapping(uint256 => bool) public templateExists;

    // To check if items from templates can be unique or multiples
    mapping(uint256 => bool) public isTemplateUnique;

    // To see how many and which template ids current game has access to
    mapping(address => uint256[]) public gameAccessTemplateIds;

    // Total item counts each template holds
    mapping(uint256 => uint256) public itemCountsPerTemplate;

    //Tracks Non-unique tokenIds by TemplateId
    mapping(uint256 => uint256) public multiTokenIdByTemplateID;

    /* Item struct holds the templateId, a total of 4 additional features, equipment position 
    and the burned status */
    struct Item {
        uint256 templateId; // id of Template in the itemTemplates array
        uint8 feature1;
        uint8 feature2;
        uint8 feature3;
        uint8 feature4;
        uint8 equipmentPosition;
        bool burned;
    }

    // All items created, ever, both burned and not burned
    Item[] public allItems;

    modifier onlyApprovedGame(uint256 _templateId) {
        require(
            templateApprovedGames[_templateId][msg.sender],
            "Inventory: Game is not approved for modifying this token"
        );
        _;
    }

    modifier isTokenOwner(address _caller, uint256 _tokenId) {
        require(
            balanceOf(_caller, _tokenId) != 0,
            "Inventory: Caller doesn't own this token"
        );
        _;
    }

    modifier doesTemplateExist(uint256 _templateId) {
        require(templateExists[_templateId], "Inventory: Template doesn't exist");
        _;
    }

    modifier doesTemplateNotExist(uint256 _templateId) {
        require(!templateExists[_templateId], "Inventory: Template already exists");
        _;
    }

    /**
     * @dev Constructor function
     * @param _tokenURIStart Prefix of token URI "https://team3d.io/inventory/json/"
     * @param _tokenURIEnd Suffix of token URI ".json"
     * @param _rewardToken Interface of reward token (VIDYA: 0x3D3D35bb9bEC23b06Ca00fe472b50E7A4c692C30)
     */
    constructor(
        string memory _tokenURIStart,
        string memory _tokenURIEnd,
        IERC20 _rewardToken
    ) ERC1155(_tokenURIStart) {
        treasureChestRewardToken = _rewardToken;
        setTokenURIPath(_tokenURIStart, _tokenURIEnd);
        addNewTemplate(0, 0, msg.sender, true);
    }

    /**
     * @dev External function to equip items. This function can be called only by the owner of the token.
     * @param _tokenId Token Id
     * @param _equipmentPosition Position of equipment
     */
    function equip(uint256 _tokenId, uint8 _equipmentPosition)
        external
        isTokenOwner(msg.sender, _tokenId)
    {
        require(_equipmentPosition < 11, "Inventory: Equip to invalid position");
        require(
            allItems[_tokenId].equipmentPosition == _equipmentPosition,
            "Inventory: Equip to wrong position"
        );

        characterEquipment[msg.sender][_equipmentPosition] = _tokenId;
    }

    /**
     * @dev External function to unequip.
     * @param _equipmentPosition Position of equipment
     */
    function unequip(uint8 _equipmentPosition) external {
        require(_equipmentPosition < 11, "Inventory: Unequip from invalid position");
        characterEquipment[msg.sender][_equipmentPosition] = 0;
    }

    /**
     * @dev External function to withdraw any ERC20 tokens which Inventory contract holds. This function can be called by only owner.
     * @param _tokenContract Address of ERC20 token.
     */
    function withdrawERC20Tokens(address _tokenContract) external onlyOwner {
        IERC20 token = IERC20(_tokenContract);
        uint256 amount = token.balanceOf(address(this));
        token.transfer(msg.sender, amount);
    }

    /**
     * @dev External function to approve games to modify items. This function can be called by only owner.
     * @param _gameAddr Address of game
     * @param _status Game status(Approve or disapprove)
     * @param _minTemplateId Minimum template id
     * @param _maxTemplateId Maximum template id
     */
    function approvedGamesForTemplate(
        address _gameAddr,
        bool _status,
        uint256 _minTemplateId,
        uint256 _maxTemplateId
    ) external onlyOwner {
        for (uint256 i = _minTemplateId; i <= _maxTemplateId; i++) {
            templateApprovedGames[i][_gameAddr] = _status;
            gameAccessTemplateIds[_gameAddr].push(i);
        }
    }

    /**
     * @dev Public function to add new template and transfer it to receiver. This function can be called by only owner.
     * @param _templateId Id of template
     * @param _equipmentPosition Equipment position
     * @param _receiver Address of receiver
     * @param _isTemplateUnique Bool value if items from this template can be unique or multiple nfts
     */
    function addNewTemplate(
        uint256 _templateId,
        uint8 _equipmentPosition,
        address _receiver,
        bool _isTemplateUnique
    ) public onlyOwner doesTemplateNotExist(_templateId) {
        uint256 id = allItems.length;

        templateExists[_templateId] = true;
        allItems.push(Item(_templateId, 0, 0, 0, 0, _equipmentPosition, false));

        _mint(_receiver, id, 1, "");
        setTokenURI(id, _templateId);
        if (!_isTemplateUnique) {
            multiTokenIdByTemplateID[_templateId] = id;
        }
        isTemplateUnique[_templateId] = _isTemplateUnique;
        itemCountsPerTemplate[_templateId]++;
    }

    /**
     * @dev Public function to create item from template. This function can be called by approved games only.
     * @param _templateId Id of template
     * @param _feature1 Feature 1
     * @param _feature2 Feature 2
     * @param _feature3 Feature 3
     * @param _feature4 Feature 4
     * @param _equipmentPosition Equipment position
     * @param _amount Amount of Item
     * @param _player Address of player
     * @return Token Id
     */
    function createItemFromTemplate(
        uint256 _templateId,
        uint8 _feature1,
        uint8 _feature2,
        uint8 _feature3,
        uint8 _feature4,
        uint8 _equipmentPosition,
        uint256 _amount,
        address _player
    )
        public
        doesTemplateExist(_templateId)
        onlyApprovedGame(_templateId)
        returns (uint256)
    {
        uint256 id;
        if (isTemplateUnique[_templateId]) {
            require(_amount == 1, "Inventory: _templateId is set to unique with a fixed supply of 1.");
            id = allItems.length;

            allItems.push(
                Item(
                    _templateId,
                    _feature1,
                    _feature2,
                    _feature3,
                    _feature4,
                    _equipmentPosition,
                    false
                )
            );
            _mint(_player, id, _amount, "");
            setTokenURI(id, _templateId);
        } else {
            id = multiTokenIdByTemplateID[_templateId];
            _mint(_player, id, _amount, "");
        }

        itemCountsPerTemplate[_templateId] += _amount;

        emit ItemFromTemplateCreated(
            _templateId,
            _feature1,
            _feature2,
            _feature3,
            _feature4,
            _equipmentPosition,
            _amount,
            _player,
            id
        );
        return id;
    }

    /**
     * @dev Public function to change features of item. This function can be called by approved games only.
     * @param _tokenId Id of Token
     * @param _feature1 Feature 1
     * @param _feature2 Feature 2
     * @param _feature3 Feature 3
     * @param _feature4 Feature 4
     * @param _equipmentPosition Equipment position
     * @param _player Address of player
     */
    function changeFeaturesForItem(
        uint256 _tokenId,
        uint8 _feature1,
        uint8 _feature2,
        uint8 _feature3,
        uint8 _feature4,
        uint8 _equipmentPosition,
        address _player
    )
        public
        onlyApprovedGame(allItems[_tokenId].templateId)
        isTokenOwner(_player, _tokenId)
    {
        Item storage item = allItems[_tokenId];

        item.feature1 = _feature1;
        item.feature2 = _feature2;
        item.feature3 = _feature3;
        item.feature4 = _feature4;
        item.equipmentPosition = _equipmentPosition;

        emit FeaturesForItemChanged(
            _tokenId,
            _feature1,
            _feature2,
            _feature3,
            _feature4,
            _equipmentPosition,
            _player
        );
    }

    /**
     * @dev Public function to add more tokens to already existing token Id. This function can be called by only approved game and _tokenOwner should be holding that token.
     *      This function is allowed only for multiple tokens. Ex: Oxygen tank ...
     * @param _tokenOwner Address of token owner
     * @param _tokenId Id of Token
     * @param _amount Amount to increase
     */
    function increaseTokenAmounts(
        address _tokenOwner,
        uint256 _tokenId,
        uint256 _amount
    )
        public
        onlyApprovedGame(allItems[_tokenId].templateId)
        isTokenOwner(_tokenOwner, _tokenId)
    {
        uint256 templateId = allItems[_tokenId].templateId;

        require(!isTemplateUnique[templateId], "Inventory: Cannot increase supply of unique token.");

        _mint(_tokenOwner, _tokenId, _amount, "");

        itemCountsPerTemplate[templateId] += _amount;

        emit TokenAmountsIncreased(_tokenOwner, _tokenId, _amount);
    }

    /**
     * @dev External function to add treasure chest. This function can be called by only approved games.
     * @param _tokenId Token id
     * @param _rewardsAmount Rewards amount
     */
    function addTreasureChest(uint256 _tokenId, uint256 _rewardsAmount)
        external
        onlyApprovedGame(allItems[_tokenId].templateId)
    {
        treasureChestRewards[_tokenId] = _rewardsAmount;
    }

    /**
     * @dev Public function to burn the token.
     * @param _owner Address of token owner
     * @param _tokenId Token id
     * @param _amount Token amount
     */
    function burn(
        address _owner,
        uint256 _tokenId,
        uint256 _amount
    ) public isTokenOwner(_owner, _tokenId) {
        uint256 templateId = allItems[_tokenId].templateId;

        _burn(_owner, _tokenId, _amount);

        if (balanceOf(_owner, _tokenId) == 0 && isTemplateUnique[templateId]) {
            allItems[_tokenId].burned = true;
        }

        itemCountsPerTemplate[templateId] -= _amount;

        uint256 treasureChestRewardsForToken = treasureChestRewards[_tokenId];

        if (treasureChestRewardsForToken > 0) {
            treasureChestRewardToken.transfer(
                _owner,
                treasureChestRewardsForToken
            );
            treasureHuntPoints[_owner]++;
        }

        emit Burnt(
            _owner,
            _tokenId,
            _amount,
            treasureChestRewardsForToken,
            treasureHuntPoints[_owner]
        );
    }

    // Return an array of tokenIds and balances _who owns 
    function getTokenIdsAndBalances(address _who) public view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](allItems.length);
        for(uint256 i = 0; i < allItems.length; i++) {
            uint256 balance = balanceOf(_who, i);
            if(balance > 0) {
                result[i] = balance;
            }
        }
        return result;
    }

    function totalSupply() public view returns (uint256) {
        uint256 result;

        for (uint i = 0; i < allItems.length; i++) {
            result = result + itemCountsPerTemplate[i];
        }

        return result;
    }

    function name() public pure returns (string memory) {
        return "Inventory V3";
    }

    function symbol() public pure returns (string memory) {
        return "ITEM";
    }
}