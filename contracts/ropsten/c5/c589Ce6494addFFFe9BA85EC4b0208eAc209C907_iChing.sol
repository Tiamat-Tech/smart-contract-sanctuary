// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


/**
 * @title iChing
 */
contract iChing is
    ERC721Enumerable,
    Ownable
{
    using SafeMath for uint256;

    string public baseTokenURI;
    uint256 private _currentTokenId = 0;
    uint256 MAX_SUPPLY = 9999;
    uint256 public totalMint = 0;
    uint256 public totalPledge;

    uint256 public presaleTime = 1631718000;
    uint256 public presaleEndTime = 1631804400;
    uint256 public pledgeTime = 1699999999;
    uint256 public awakeningTime = 1699999999;

    mapping(address => bool) public whitelist;
    mapping(address => uint8) public presaleNumOfPlayer;
    mapping(address => uint8) public pledgeNumOfPlayer;
    mapping(address => uint8) public claimed;

    event WhitelistedAddressRemoved(address addr);
    event BloodThirster(uint256 indexed tokenId, address indexed luckyDog);
    event BloodRider(uint256 indexed tokenId, address indexed luckyDog);
    event GivenName(uint256 indexed tokenId, string name);
    event StoryOfiChing(uint256 indexed tokenId, string name);

    /**
     * @dev Throws if called by any account that's not whitelisted.
     */
    modifier onlyWhitelisted() {
        require(
            whitelist[msg.sender],
            "iChing: You're not on the whitelist."
        );
        _;
    }

    constructor() ERC721("BookOfChanges", "BOC") {
        baseTokenURI = "https://gateway.pinata.cloud/ipfs/";
    }

    /**
     * @dev Airdrop iChings to several addresses.
     * @param _recipients addresss of the future owner of the token
     */
    function mintTo(address[] memory _recipients) external onlyOwner {
        for (uint256 i = 0; i < _recipients.length; i++) {
            uint256 newTokenId = _getNextTokenId();
            _mint(_recipients[i], newTokenId);
            _incrementTokenId();
        }
        totalMint += _recipients.length;
    }

    /**
     * @dev Mint to msg.sender. Only whitelisted users can participate
     * @param _num Quantity to purchase
     */
    function presale(uint8 _num) external payable onlyWhitelisted {
        require(
            block.timestamp >= presaleTime && block.timestamp < presaleEndTime,
            "iChing: Presale has not yet started."
        );
        require(
            (_num + presaleNumOfPlayer[msg.sender]) <= 3,
            "iChing: Up to 3 iChings can be purchased."
        );
        require(
            msg.value == uint256(_num) * 6e16,
            "iChing: You need to pay the exact price."
        );
        _mintList(_num);
        presaleNumOfPlayer[msg.sender] = presaleNumOfPlayer[msg.sender] + _num;
        totalMint += uint256(_num);
    }

    /**
     * @dev Pledge for the purchase. Each address can only purchase up to 5 iChings.
     * @param _num Quantity to purchase
     */
    function bloodMark(uint8 _num) external payable {
        require(
            block.timestamp >= pledgeTime,
            "iChing: Pledge has not yet started."
        );
        require(
            (_num + pledgeNumOfPlayer[msg.sender] + claimed[msg.sender]) <= 5,
            "iChing: Each address can only purchase up to 5 iChings."
        );
        require(
            totalMint + uint256(_num) <= MAX_SUPPLY - totalPledge - 200,
            "iChing: Sorry, all iChings are sold out."
        );
        require(
            msg.value == uint256(_num) * 6e16,
            "iChing: You need to pay the exact price."
        );
        pledgeNumOfPlayer[msg.sender] = pledgeNumOfPlayer[msg.sender] + _num;
        totalPledge += uint256(_num);
    }

    /**
     * @dev Your iChings can only be claimed at the end of the sale.
     */
    function claim() external {
        require(
            block.timestamp >= pledgeTime,
            "iChing: Pledge has not yet started."
        );
        _mintList(pledgeNumOfPlayer[msg.sender]);
        claimed[msg.sender] += pledgeNumOfPlayer[msg.sender];
        pledgeNumOfPlayer[msg.sender] = 0;
    }

    /**
     * @dev Mint to msg.sender.
     * @param _num addresss of the future owner of the token
     */
    function mint(uint8 _num) external payable {
        require(
            block.timestamp >= awakeningTime,
            "iChing: Mint time has not yet arrived!"
        );
        require(
            totalMint + uint256(_num) <= MAX_SUPPLY - totalPledge - 200,
            "iChing: Sorry, all iChings are sold out."
        );
        require(
            _num <= 5,
            "iChing: Up to 5 iChings can be minted in a tx."
        );
        require(
            msg.value == uint256(_num) * 6e16,
            "iChing: You need to pay the exact price."
        );
        _mintList(_num);
        totalMint += uint256(_num);
    }

    /**
     * @dev Every time the tokenId reaches a multiple of 100, a random iChing gets a 10x mint price return.
     * For the 2500th, 5000th, 7500th and 9999th sales, 4 random iChings will be picked and be each gifted with a Harley Davidson motorcycle as their ride.
     */
    function _mintList(uint8 _num) private {
        for (uint8 i = 0; i < _num; i++) {
            uint256 newTokenId = _getNextTokenId();
            _mint(msg.sender, newTokenId);
            _incrementTokenId();
            if (newTokenId % 100 == 0) {
                uint256 amount = random() % 100;
                uint256 realId = newTokenId - amount;
                address luckyDog = ownerOf(realId);
                payable(luckyDog).transfer(6e17);
                emit BloodThirster(realId, luckyDog);
            }
            if (newTokenId % 2500 == 0 || newTokenId == MAX_SUPPLY) {
                uint256 randomNum = random() % 999;
                bytes32 randomHash = keccak256(
                    abi.encode(
                        ownerOf(newTokenId - randomNum - 100),
                        ownerOf(newTokenId - randomNum - 200),
                        ownerOf(newTokenId - randomNum - 300)
                    )
                );
                uint256 bloodRiderId = newTokenId -
                    (uint256(randomHash) % 2500);
                emit BloodRider(bloodRiderId, ownerOf(bloodRiderId));
            }
        }
    }

    /**
     * @dev calculates the next token ID based on value of _currentTokenId
     * @return uint256 for the next token ID
     */
    function _getNextTokenId() private view returns (uint256) {
        return _currentTokenId.add(1);
    }

    /**
     * @dev generates a random number based on block info
     */
    function random() private view returns (uint256) {
        bytes32 randomHash = keccak256(
            abi.encode(
                block.timestamp,
                block.difficulty,
                block.coinbase,
                msg.sender
            )
        );
        return uint256(randomHash);
    }

    /**
     * @dev increments the value of _currentTokenId
     */
    function _incrementTokenId() private {
        require(_currentTokenId < MAX_SUPPLY);
        _currentTokenId++;
    }

    /**
     * @dev change the baseTokenURI only by Admin
     */
    function setBaseUri(string memory _uri) external onlyOwner {
        baseTokenURI = _uri;
    }

    /**
     * @dev set the sale time only by Admin
     */
    function setAwakeningTime(uint256 _time) external onlyOwner {
        awakeningTime = _time;
    }

    /**
     * @dev set the presale and pledge time only by Admin
     */
    function setAllTime(
        uint256 _preSaleTime,
        uint256 _preSaleEndTime,
        uint256 _pledgeTime
    ) external onlyOwner {
        presaleTime = _preSaleTime;
        presaleEndTime = _preSaleEndTime;
        pledgeTime = _pledgeTime;
    }

    function setName(uint256 _tokenId, string memory _name) external {
        require(
            ownerOf(_tokenId) == msg.sender,
            "iChing: You don't own this iChing!"
        );
        emit GivenName(_tokenId, _name);
    }

    function setStory(uint256 _tokenId, string memory _desc) external {
        require(
            ownerOf(_tokenId) == msg.sender,
            "iChing: You don't own this iChing!"
        );
        emit StoryOfiChing(_tokenId, _desc);
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        return
            string(abi.encodePacked(baseTokenURI, Strings.toString(_tokenId)));
    }



    function recoverGodhead() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    /**
     * @dev add addresses to the whitelist
     * @param addrs addresses
     */
    function addAddressesToWhitelist(address[] memory addrs) public onlyOwner {
        for (uint256 i = 0; i < addrs.length; i++) {
            whitelist[addrs[i]] = true;
        }
    }

    /**
     * @dev remove addresses from the whitelist
     * @param addrs addresses
     */
    function removeAddressesFromWhitelist(address[] memory addrs)
        public
        onlyOwner
    {
        for (uint256 i = 0; i < addrs.length; i++) {
            whitelist[addrs[i]] = false;
            emit WhitelistedAddressRemoved(addrs[i]);
        }
    }
}