// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GiraffeTower {
    function getGenesisAddresses() public view returns (address[] memory) {}

    function getGenesisAddress(uint256 token_id)
        public
        view
        returns (address)
    {}

    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {}

    struct Giraffe {
        uint256 birthday;
    }
    mapping(uint256 => Giraffe) public giraffes;
}

contract Gleaf is ERC20Burnable, Ownable {
    event LogNewAlert(string description, address indexed _from, uint256 _n);
    event NameChange(uint256 tokenId, string name);
    using SafeMath for uint256;
    address nullAddress = 0x0000000000000000000000000000000000000000;

    address public giraffetowerAddress =
        0xaC17758ddA42355907095fb4077Af9D45a61A37E;
    //Mapping of giraffe to timestamp
    mapping(uint256 => uint256) internal tokenIdToTimeStamp;
    mapping(uint256 => uint256) tokenRound;
    mapping(uint256 => string) giraffeName;
    uint256 public nameChangePrice = 10 ether;
    // Mapping if certain name string has already been reserved
    mapping(string => bool) private _nameReserved;
    uint256 public EMISSIONS_RATE = 11574070000000;
    bool public CLAIM_STATUS = true;
    uint256 public CLAIM_START_TIME;
    uint256 totalDividends = 0;
    uint256 ownerRoyalty = 0;
    uint256 public OgsCount = 100;
    address pr = nullAddress;
    event Received(address, uint256);

    constructor() ERC20("Gleaf", "GLEAF") {
        CLAIM_START_TIME = block.timestamp;
    }

    function setGiraffetowerAddress(address _giraffetowerAddress)
        public
        onlyOwner
    {
        giraffetowerAddress = _giraffetowerAddress;
        return;
    }

    function setEmissionRate(uint256 _emissionrate) public onlyOwner {
        EMISSIONS_RATE = _emissionrate;
        return;
    }

    function setGiraffeName(uint256 tokenId, string memory name) public {
        require(
            IERC721(giraffetowerAddress).ownerOf(tokenId) == msg.sender,
            "Token is not nameable by you!"
        );
        require(validateName(name) == true, "Not a valid new name");
        require(
            sha256(bytes(name)) != sha256(bytes(giraffeName[tokenId])),
            "New name is same as the current one"
        );
        require(isNameReserved(name) == false, "Name already reserved");
        uint256 allowance = allowance(msg.sender, pr);
        require(allowance >= nameChangePrice, "Check the token allowance");
        transferFrom(msg.sender, pr, nameChangePrice);
        if (bytes(giraffeName[tokenId]).length > 0) {
            toggleReserveName(giraffeName[tokenId], false);
        }
        toggleReserveName(name, true);
        giraffeName[tokenId] = name;
        emit NameChange(tokenId, name);
    }

    function setPr(address _address) public onlyOwner{ 
        pr = _address;
    }

    /**
     * @dev Reserves the name if isReserve is set to true, de-reserves if set to false
     */
    function toggleReserveName(string memory str, bool isReserve) internal {
        _nameReserved[toLower(str)] = isReserve;
    }

    function isNameReserved(string memory nameString)
        public
        view
        returns (bool)
    {
        return _nameReserved[toLower(nameString)];
    }

    function validateName(string memory str) public pure returns (bool) {
        bytes memory b = bytes(str);
        if (b.length < 1) return false;
        if (b.length > 25) return false; // Cannot be longer than 25 characters
        if (b[0] == 0x20) return false; // Leading space
        if (b[b.length - 1] == 0x20) return false; // Trailing space

        bytes1 lastChar = b[0];

        for (uint256 i; i < b.length; i++) {
            bytes1 char = b[i];

            if (char == 0x20 && lastChar == 0x20) return false; // Cannot contain continous spaces

            if (
                !(char >= 0x30 && char <= 0x39) && //9-0
                !(char >= 0x41 && char <= 0x5A) && //A-Z
                !(char >= 0x61 && char <= 0x7A) && //a-z
                !(char == 0x20) //space
            ) return false;

            lastChar = char;
        }

        return true;
    }

    /**
     * @dev Converts the string to lowercase
     */
    function toLower(string memory str) public pure returns (string memory) {
        bytes memory bStr = bytes(str);
        bytes memory bLower = new bytes(bStr.length);
        for (uint256 i = 0; i < bStr.length; i++) {
            // Uppercase character
            if ((uint8(bStr[i]) >= 65) && (uint8(bStr[i]) <= 90)) {
                bLower[i] = bytes1(uint8(bStr[i]) + 32);
            } else {
                bLower[i] = bStr[i];
            }
        }
        return string(bLower);
    }

    function getGiraffeName(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        return giraffeName[tokenId];
    }
    

    function changeNamePrice(uint256 _price) external onlyOwner {
		nameChangePrice = _price;
	}

    function setClaimStatus(bool _claimstatus) public onlyOwner {
        CLAIM_STATUS = _claimstatus;
        return;
    }

    function claimByTokenId(uint256 tokenId) public {
        GiraffeTower gt = GiraffeTower(giraffetowerAddress);
        require(
            IERC721(giraffetowerAddress).ownerOf(tokenId) == msg.sender,
            "Token is not claimable by you!"
        );
        require(CLAIM_STATUS == true, "Claim disabled!");
        uint256 totalReward = 0;
        if (tokenIdToTimeStamp[tokenId] == 0) {
            uint256 birthday = gt.giraffes(tokenId);
            uint256 stime = 0;
            if (birthday > CLAIM_START_TIME) {
                stime = birthday;
            } else {
                stime = CLAIM_START_TIME;
            }
            if (gt.getGenesisAddress(tokenId) == msg.sender && birthday < CLAIM_START_TIME) {
                totalReward += (4320000 * EMISSIONS_RATE);
            }
            tokenIdToTimeStamp[tokenId] = stime;
        }
        totalReward += ((block.timestamp - tokenIdToTimeStamp[tokenId]) *
            EMISSIONS_RATE);
        tokenIdToTimeStamp[tokenId] = block.timestamp;
        require(totalReward > 0, "LTR!");
        _mint(msg.sender, totalReward);
    }

    function claimAll() public {
        require(CLAIM_STATUS == true, "Claim disabled!");
        GiraffeTower gt = GiraffeTower(giraffetowerAddress);
        address _address = msg.sender;
        uint256[] memory tokenIds = gt.walletOfOwner(_address);
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            // require(
            //     tokenIdToStaker[tokenIds[i]] == msg.sender,
            //     "Token is not claimable by you!"
            // );
            if (tokenIdToTimeStamp[tokenIds[i]] == 0) {
                uint256 birthday = gt.giraffes(tokenIds[i]);
                uint256 stime = 0;
                if (birthday > CLAIM_START_TIME) {
                    stime = birthday;
                } else {
                    stime = CLAIM_START_TIME;
                }
                if (gt.getGenesisAddress(tokenIds[i]) == msg.sender && birthday < CLAIM_START_TIME) {
                    totalRewards += (4320000 * EMISSIONS_RATE);
                }
                tokenIdToTimeStamp[tokenIds[i]] = stime;
            }
            totalRewards =
                totalRewards +
                ((block.timestamp - tokenIdToTimeStamp[tokenIds[i]]) *
                    EMISSIONS_RATE);

            tokenIdToTimeStamp[tokenIds[i]] = block.timestamp;
        }
        require(totalRewards > 0, "LTR!");
        _mint(msg.sender, totalRewards);
    }

    function getAllRewards(address _address) public view returns (uint256) {
        GiraffeTower gt = GiraffeTower(giraffetowerAddress);
        uint256[] memory tokenIds = gt.walletOfOwner(_address);
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (tokenIdToTimeStamp[tokenIds[i]] == 0) {
                uint256 birthday = gt.giraffes(tokenIds[i]);
                uint256 stime = 0;
                if (birthday > CLAIM_START_TIME) {
                    stime = birthday;
                } else {
                    stime = CLAIM_START_TIME;
                }
                if (gt.getGenesisAddress(tokenIds[i]) == msg.sender && birthday < CLAIM_START_TIME) {
                    totalRewards += (4320000 * EMISSIONS_RATE);
                }
                totalRewards =
                    totalRewards +
                    ((block.timestamp - stime) * EMISSIONS_RATE);
            } else {
                totalRewards =
                    totalRewards +
                    ((block.timestamp - tokenIdToTimeStamp[tokenIds[i]]) *
                        EMISSIONS_RATE);
            }
        }
        return totalRewards;
    }

    function getRewardsByTokenId(uint256 tokenId)
        public
        view
        returns (uint256)
    {
        GiraffeTower gt = GiraffeTower(giraffetowerAddress);
        uint256 birthday = gt.giraffes(tokenId);
        uint256 stime = 0;
        if (birthday > CLAIM_START_TIME) {
            stime = birthday;
        } else {
            stime = CLAIM_START_TIME;
        }
        uint256 totalRewards = 0;

        if (tokenIdToTimeStamp[tokenId] == 0) {
            if (gt.getGenesisAddress(tokenId) == msg.sender && birthday < CLAIM_START_TIME) {
                totalRewards += (4320000 * EMISSIONS_RATE);
            }
            totalRewards =
                totalRewards +
                ((block.timestamp - stime) * EMISSIONS_RATE);
        } else {
            totalRewards =
                totalRewards +
                ((block.timestamp - tokenIdToTimeStamp[tokenId]) *
                    EMISSIONS_RATE);
        }

        return totalRewards;
    }

    function getBirthday(uint256 tokenId) public view returns (uint256) {
        GiraffeTower gt = GiraffeTower(giraffetowerAddress);
        uint256 birthday = gt.giraffes(tokenId);

        return birthday;
    }

    function _ownerRoyalty() public view returns (uint256) {
        return ownerRoyalty;
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
        uint256 tt = msg.value / 5;
        totalDividends += tt;
        uint256 ot = msg.value - tt;
        ownerRoyalty += ot;
    }

    function withdrawReward(uint256 tokenId) external {
        require(
            IERC721(giraffetowerAddress).ownerOf(tokenId) == msg.sender &&
                tokenId <= 100,
            "WR:Invalid"
        );
        uint256 total = (totalDividends - tokenRound[tokenId]) / OgsCount;
        require(total > 0, "Too Low");
        tokenRound[tokenId] = totalDividends;
        sendEth(msg.sender, total);
    }

    function withdrawAllReward() external {
        address _address = msg.sender;
        GiraffeTower gt = GiraffeTower(giraffetowerAddress);
        uint256[] memory _tokensOwned = gt.walletOfOwner(_address);
        uint256 totalClaim;
        for (uint256 i; i < _tokensOwned.length; i++) {
            if (_tokensOwned[i] <= 100) {
                totalClaim +=
                    (totalDividends - tokenRound[_tokensOwned[i]]) /
                    OgsCount;
                tokenRound[_tokensOwned[i]] = totalDividends;
            }
        }
        require(totalClaim > 0, "WAR: LTC");
        sendEth(msg.sender, totalClaim);
    }

    function withdrawRoyalty() external onlyOwner {
        require(ownerRoyalty > 0, "WRLTY:Invalid");
        uint256 total = ownerRoyalty;
        ownerRoyalty = 0;
        sendEth(msg.sender, total);
    }

    function rewardBalance(uint256 tokenId) public view returns (uint256) {
        //    require(ownerOf(tokenId) == msg.sender && tokenId < 100 , "WR:Invalid");
        uint256 total = (totalDividends - tokenRound[tokenId]) / OgsCount;
        return total;
    }

    function withdrawFunds(uint256 amount) public onlyOwner {
        sendEth(msg.sender, amount);
    }

    function sendEth(address to, uint256 amount) internal {
        (bool success, ) = to.call{value: amount}("");
        require(success, "Failed to send ether");
    }

    function withdrawToken(
        IERC20 token,
        address recipient,
        uint256 amount
    ) public onlyOwner {
        require(
            token.balanceOf(address(this)) >= amount,
            "You do not have sufficient Balance"
        );
        token.transfer(recipient, amount);
    }
}