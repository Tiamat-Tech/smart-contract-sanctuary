// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GiraffeTower {

    function getGenesisAddresses() public view returns (address[] memory){}
    function getGenesisAddress(uint256 token_id) public view returns (address){}
    function walletOfOwner(address _owner) public view returns (uint256[] memory){}
    struct Giraffe {
        uint256 birthday;
    }
    mapping(uint256 => Giraffe) public giraffes;

}

contract Gleaf is ERC20Burnable, Ownable {
    event LogNewAlert(string description, address indexed _from, uint256 _n);
    using SafeMath for uint256;
    address nullAddress = 0x0000000000000000000000000000000000000000;
    
    address public giraffetowerAddress = 0xaC17758ddA42355907095fb4077Af9D45a61A37E;
    //Mapping of giraffe to timestamp
    mapping(uint256 => uint256) internal tokenIdToTimeStamp;
    mapping(uint256 => uint256) tokenRound;

    uint256 public EMISSIONS_RATE = 11574070000000;
    bool public CLAIM_STATUS = true;
    uint256 public CLAIM_START_TIME;
    uint256 totalDividends = 0;
    uint256 ownerRoyalty = 0;
    uint256 public OgsCount = 100;
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

    function setEmissionRate(uint256 _emissionrate)
        public
        onlyOwner
    {
        EMISSIONS_RATE = _emissionrate;
        return;
    }

     function setClaimStatus(bool _claimstatus)
        public
        onlyOwner
    {
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
        if(tokenIdToTimeStamp[tokenId] == 0){
                uint256 birthday = gt.giraffes(tokenId);
                uint256 stime = 0;
                if(birthday > CLAIM_START_TIME){
                    stime = birthday;
                }else{
                    stime = CLAIM_START_TIME;
                }
                if(gt.getGenesisAddress(tokenId) == msg.sender){
                    totalReward += (4320000 * EMISSIONS_RATE);
                }
        tokenIdToTimeStamp[tokenId] = stime;
        }
        totalReward +=  ((block.timestamp - tokenIdToTimeStamp[tokenId]) * EMISSIONS_RATE); 
        tokenIdToTimeStamp[tokenId] = block.timestamp;
        require(totalReward > 0, "LTR!");
        _mint(
            msg.sender,
            totalReward
        );
    }

    function claimAll() public {
         require(CLAIM_STATUS == true, "Claim disabled!");
        GiraffeTower gt = GiraffeTower(giraffetowerAddress);
        address _address = msg.sender;
        uint256[] memory tokenIds =  gt.walletOfOwner(_address);
        uint256 totalRewards = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            // require(
            //     tokenIdToStaker[tokenIds[i]] == msg.sender,
            //     "Token is not claimable by you!"
            // );
            if(tokenIdToTimeStamp[tokenIds[i]] == 0){
                uint256 birthday = gt.giraffes(tokenIds[i]);
                uint256 stime = 0;
                if(birthday > CLAIM_START_TIME){
                    stime = birthday;
                }else{
                    stime = CLAIM_START_TIME;
                }
                if(gt.getGenesisAddress(tokenIds[i]) == msg.sender){
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

        _mint(msg.sender, totalRewards);
    }

    function getAllRewards(address _address) public view returns (uint256) {
        GiraffeTower gt = GiraffeTower(giraffetowerAddress);
        uint256[] memory tokenIds =  gt.walletOfOwner(_address);
        uint256 totalRewards = 0;
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if(tokenIdToTimeStamp[tokenIds[i]] == 0){
                uint256 birthday = gt.giraffes(tokenIds[i]);
                uint256 stime = 0;
                if(birthday > CLAIM_START_TIME){
                    stime = birthday;
                }else{
                    stime = CLAIM_START_TIME;
                }
                if(gt.getGenesisAddress(tokenIds[i]) == msg.sender){
                    totalRewards += (4320000 * EMISSIONS_RATE);
                }
                totalRewards = totalRewards + ((block.timestamp - stime) * EMISSIONS_RATE);
            }else{
                totalRewards = totalRewards + ((block.timestamp - tokenIdToTimeStamp[tokenIds[i]]) * EMISSIONS_RATE);
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
        if(birthday > CLAIM_START_TIME){
            stime = birthday;
        }else{
            stime = CLAIM_START_TIME;
        }
        uint256 totalRewards = 0;
       
        
         if(tokenIdToTimeStamp[tokenId] == 0){
                if(gt.getGenesisAddress(tokenId) == msg.sender){
                    totalRewards += (4320000 * EMISSIONS_RATE);
                }
                totalRewards = totalRewards + ((block.timestamp - stime) * EMISSIONS_RATE);
            }else{
                totalRewards = totalRewards + ((block.timestamp - tokenIdToTimeStamp[tokenId]) * EMISSIONS_RATE);
            }
       
        return totalRewards;
    }

    function getBirthday(uint256 tokenId)
        public
        view
        returns (uint256)
    {
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
        require(IERC721(giraffetowerAddress).ownerOf(tokenId) == msg.sender && tokenId <= 100, "WR:Invalid");
        uint256 total = (totalDividends - tokenRound[tokenId]) / OgsCount;
        require(total > 0,"Too Low");
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