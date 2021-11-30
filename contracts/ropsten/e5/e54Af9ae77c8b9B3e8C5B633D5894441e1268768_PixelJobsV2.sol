// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/finance/PaymentSplitter.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

// ______  _              _     ___         _
// | ___ \(_)            | |   |_  |       | |
// | |_/ / _ __  __  ___ | |     | |  ___  | |__   ___
// |  __/ | |\ \/ / / _ \| |     | | / _ \ | '_ \ / __|
// | |    | | >  < |  __/| | /\__/ /| (_) || |_) |\__ \
// \_|    |_|/_/\_\ \___||_| \____/  \___/ |_.__/ |___/
//
// brought to you by dot media, Inc(design) / extra mile, Ltd.(develop)
// all the way from far east TOKYO

contract PixelJobsV2 is Ownable, ERC721Enumerable, ReentrancyGuard, Pausable, PaymentSplitter {
    using Strings for uint256;

    // mint price
    uint256 public constant MINT_PRICE = .02 ether;
    // max # of tokens that can be minted - this project only allows 1,000 in prod env.
    uint16 public constant MAX_TOKENS = 1000;
    // max # of tokens that each address can hold.
    uint8 public constant MAX_PURCHASE_PER_PERSON = 5;
    // account role status. access w/o loop
    // 1 -> white list, 2 -> admin
    mapping(address => uint8) public accountStatus;

    // baseUri for assets;
    string private _baseURIExtended;
    // flag for user give away status
    bool private _hasUserGivenAwayFinished = false;
    // flag for whitelist sale status
    bool private _isWhiteListSale = false;
    // flag for open sale status
    bool private _isOpenSale = false;
    // team for operation
    address[] private _team;

    constructor(address[] memory payees, uint256[] memory shares_)
    ERC721("PixelJobs", "PXJOB")
    PaymentSplitter(payees, shares_)
    {
        // admin setting
        _team = payees;
        for (uint8 i = 0; i < _team.length; i++) {
            accountStatus[_team[i]] = 2;
        }
    }

    function mintJobs(uint amount_) external payable nonReentrant {
        // basic condition
        require(amount_ > 0, "101");
        require(balanceOf(msg.sender) + amount_ <= MAX_PURCHASE_PER_PERSON, "102");
        require(totalSupply() + amount_ <= MAX_TOKENS, "103");
        require(msg.value >= (MINT_PRICE * amount_), "104");

        require(_hasUserGivenAwayFinished, "106");
        require(!paused(), "107");

        if (_isWhiteListSale) {
            require(!_isOpenSale, "108");
            require(accountStatus[msg.sender] >= 1, "109");
        } else if (_isOpenSale) {
            require(!_isWhiteListSale, "110");
        }

        // execute
        uint id = totalSupply();
        for (uint8 i = 0; i < amount_; i++) {
            id++;
            _safeMint(msg.sender, id);
        }
    }

    function getStatus() public view returns (uint){
        if (!_hasUserGivenAwayFinished) {
            return 0;
        }
        if (_isWhiteListSale) {
            return 1;
        }
        if (_isOpenSale && totalSupply() < MAX_TOKENS) {
            return 2;
        }
        return 3;
    }

    function setBaseURI(string memory updateUri) external onlyOwner {
        _baseURIExtended = updateUri;
    }

    function setPaused(bool shouldPause) external onlyOwner {
        if (shouldPause) {
            _pause();
            return;
        }
        _unpause();
    }

    /**
     * release funds
     */
    function releaseFunds() external onlyOwner {
        for (uint i = 0; i < _team.length; i++) {
            release(payable(_team[i]));
        }
    }

    function giveAway(address[] memory addresses) external onlyOwner {
        require(addresses.length > 0, "2");
        require(!_hasUserGivenAwayFinished, "3");
        require(!_isOpenSale, "4");
        require(!_isWhiteListSale, "5");
        require(!paused(), "6");

        // DO MINT
        uint id = totalSupply();

        for (uint i = 0; i < addresses.length; i++) {
            id++;
            _safeMint(addresses[i], id);
        }
    }

    function setGiveAway(bool toggle) external onlyOwner {
        _hasUserGivenAwayFinished = toggle;
    }

    function setWhitelist(address[] memory addresses) external onlyOwner {
        for (uint i = 0; i < addresses.length; i++) {
            accountStatus[addresses[i]] = 1;
        }
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseURIExtended;
    }
}