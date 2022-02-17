// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./HappyRobotNFT.sol";
import "./HappyRobotWhitelistToken.sol";

contract HappyRobotSale is Ownable {
  
    uint8 constant GENERATION_COUNT = 3;
    uint8 constant MAX_PER_WALLET = 3;

    uint8 constant MIDDLE_FLOOR = 8;
    uint8 constant FIRST_LEVEL_TOKINS = 30;
    uint8 constant SECOND_LEVEL_TOKINS = 50;
    uint16 constant MAX_WHITELIST_TOKENS = 300;

    // sale status constants
    uint8 constant SALE_STATUS_NON = 0;
    uint8 constant SALE_STATUS_PRE = 1;
    uint8 constant SALE_STATUS_PUB = 2;

    address payable constant public walletMaster = payable(0x52BD82C6B851AdAC6A77BC0F9520e5A062CD9a78);
    address payable constant public walletDevTeam = payable(0x52BD82C6B851AdAC6A77BC0F9520e5A062CD9a78);

    address private nftAddress;
    address private whitelistTokenAddress;

    uint256 private mintFee = 0.1 ether;
    uint256 private whitelistTokenMintFee = 0.2 ether;

    uint8 private saleStauts = SALE_STATUS_NON;

    address[] private whitelist;
    address[] private giftWhitelist;
    mapping(address => uint32) neuronsMap;

    /**
    * @dev Require msg.sender to be the master or dev team
    */
    modifier onlyCreator() {
        require(walletMaster == payable(msg.sender) || walletDevTeam == payable(msg.sender), "HappyRobot#onlyCreator: ONLY_CREATOR_ALLOWED");
        _;
    }

    constructor(address _nftAddress, address _whitelistTokenAddress) {
        nftAddress = _nftAddress;
        whitelistTokenAddress = _whitelistTokenAddress;
    }

    /**
    * get sale status
    * @return 0: none, 1: pre sale, 2: public sale
    */
    function getSaleStatus() public view returns (uint8) {
        return saleStauts;
    }

    /**
    * set sale status
    * @param _saleStatus 0: none, 1: pre sale, 2: public sale
    */
    function setSaleStatus(uint8 _saleStatus) public onlyCreator {
        require(_saleStatus <= SALE_STATUS_PUB, "Happy Robot: Invalid sale status, the status value should be less than 3");

        saleStauts = _saleStatus;
    }

    /**
    * get mint fee
    * @return mint fee
    */
    function getMintFee() public view returns (uint256) {
        return mintFee;
    }

    /**
    * set mint fee
    * @param _fee mint fee
    */
    function setMintFee(uint256 _fee) public onlyCreator {
        mintFee = _fee;
    }

    /**
    * update the floor information
    * @param _id id of NFT
    * @param _floor passed floor
    * @param _passTime total seconds that was taken the floor
    */
    function passedFloor(uint256 _id, uint8 _floor, uint16 _passTime) public {
        HappyRobotNFT nft = HappyRobotNFT(nftAddress);
        nft.passedFloor(msg.sender, _id, _floor, _passTime);

        // to unlock the next floor
        uint8 reqNeurons = FIRST_LEVEL_TOKINS;
        if (_floor + 1 > MIDDLE_FLOOR) 
            reqNeurons = SECOND_LEVEL_TOKINS;

        uint32 availableNeurons = neuronsMap[msg.sender] + nft.getNeurons(_id);

        require(availableNeurons >= reqNeurons, "Your neurons are not enough to unlock next level");

        uint16 claimedNeurons = nft.claimNeurons(msg.sender, _id, reqNeurons);
        
        if (claimedNeurons < reqNeurons)
            neuronsMap[msg.sender] -= (reqNeurons - claimedNeurons);
    }

    /**
    * claim neurons
    * @param _id id of NFT
    */
    function claimNeurons(uint256 _id) public returns (uint32) {
        HappyRobotNFT nft = HappyRobotNFT(nftAddress);
        uint16 neurons = nft.getNeurons(_id);
        uint16 claimedNeurons = nft.claimNeurons(msg.sender, _id, neurons);

        neuronsMap[msg.sender] += claimedNeurons;

        return neuronsMap[msg.sender];
    }

    /**
    * get all neurons of address(include NFT neurons)
    * @return neurons of address + neurons of NFTs
    */
    function getAllNeurons() public view returns (uint32) {
        uint32 neurons = neuronsMap[msg.sender];    // neurons of wallet address

        // get neurons of nfts and get total sum
        HappyRobotNFT nft = HappyRobotNFT(nftAddress);
        uint256[] memory tokenIds = nft.getTokenIdsOfOwner(msg.sender);
        for (uint16 i = 0; i < tokenIds.length; i++) {
            neurons += nft.getNeurons(tokenIds[i]);
        }

        return neurons;
    }

    /**
    * get neurons of address
    * @return neurons of address
    */
    function getNeuronsForWallet() public view returns (uint32) {
        return neuronsMap[msg.sender];    // neurons of wallet address
    }

    /**
    * get neurons of address
    * @param _id id of token
    * @return neurons of address
    */
    function getNeuronsToUnlock(uint256 _id) public view returns (uint32) {
        HappyRobotNFT nft = HappyRobotNFT(nftAddress);
        return neuronsMap[msg.sender] + nft.getNeurons(_id);    // neurons of wallet address + nft's neurons
    }

    /**
    * check if _account is in the whitelist
    * @param _account address
    * @return 
    */
    function existInWhitelist(address _account) internal view returns (bool) {
        for (uint256 i = 0; i < whitelist.length; i++) {
            if (whitelist[i] == _account)
                return true;
        }
        return false;
    }

    /**
    * add an address into the whitelist
    * @param _account address
    */
    function addToWhitelist(address _account) public onlyCreator {
        if (!existInWhitelist(_account))  whitelist.push(_account);
    }

    /**
    * remove an address into the whitelist
    * @param _account address
    */
    function removeFromWhitelist(address _account) public onlyCreator {
        // find index of _from
        uint256 index = 0xFFFF;
        uint256 len = whitelist.length;
        for (uint256 i = 0; i < len; i++) {
            if (whitelist[i] == _account) {
                index = i;
                break;
            }
        }

        // remove it
        if (index != 0xFFFF) {
            whitelist[index] = giftWhitelist[len - 1];
            whitelist.pop();
        }
    }

    /**
    * import an address list into the whitelist
    * @param _accountList address list
    */
    function importWhitelist(address[] calldata _accountList) public onlyCreator {
        delete whitelist;
        for (uint16 i = 0; i < _accountList.length; i++) {
            whitelist.push(_accountList[i]);
        }
    }

    /**
    * check if _account has gift
    * @param _account address
    * @return 
    */
    function hasGift(address _account) internal view returns (bool) {
        for (uint256 i = 0; i < giftWhitelist.length; i++) {
            if (giftWhitelist[i] == _account)
                return true;
        }
        return false;
    }

    /**
    * give a gift to _to
    * @param _to address
    */
    function addGift(address _to) public onlyCreator {
        if (!hasGift(_to))  giftWhitelist.push(_to);
    }

    /**
    * remove a gift from _from
    * @param _from address
    */
    function removeGift(address _from) internal {
        // find index of _from
        uint256 index = 0xFFFF;
        uint256 len = giftWhitelist.length;
        for (uint256 i = 0; i < len; i++) {
            if (giftWhitelist[i] == _from) {
                index = i;
                break;
            }
        }

        // remove it
        if (index != 0xFFFF) {
            giftWhitelist[index] = giftWhitelist[len - 1];
            giftWhitelist.pop();
        }
    }

    /**
    * get whitelist token mint fee
    * @return whitelist token mint fee
    */
    function getWhitelistTokenMintFee() public view returns (uint256) {
        return whitelistTokenMintFee;
    }

    /**
    * set whitelist token mint fee
    * @param _whitelistTokenMintFee mint fee
    */
    function setWhitelistTokenMintFee(uint256 _whitelistTokenMintFee) public onlyCreator {
        whitelistTokenMintFee = _whitelistTokenMintFee;
    }

    /**
    * check if mint is possible for generation index
    * @param _genIndex generation index
    * @param _quantity quantity
    * @return true or false
    */
    function canMintForGeneration(uint8 _genIndex, uint16 _quantity) public view returns (bool) {
        return HappyRobotNFT(nftAddress).canCreateToken(_genIndex, _quantity);
    }

    /**
    * check if mint is possible for account
    * @param _account account
    * @param _quantity quantity
    * @return true or false
    */
    function canMintForAccount(address _account, uint16 _quantity) public view returns (bool) {
        if (payable(_account) == walletMaster) return true;
        
        return HappyRobotNFT(nftAddress).balanceOf(_account) + _quantity <= MAX_PER_WALLET;
    }

   /**
   * mint a new NFT 
   * @param _genIndex token generation index
   * @param _quantity token amount
   * @param _data token data
   */
    function mint(uint8 _genIndex, uint16 _quantity, bytes calldata _data) public payable {

        require(saleStauts != SALE_STATUS_NON, "Happy Robot: It is not the sale period");

        require(_genIndex < GENERATION_COUNT , "Happy Robot: Invalid Generation Index");

        require(canMintForGeneration(_genIndex, _quantity) == true, "Happy Robot: Maximum minting already reached for the generation");

        require(canMintForAccount(msg.sender, _quantity) == true, "Happy Robot: Maximum minting already reached for the account");

        HappyRobotWhitelistToken whitelistToken = HappyRobotWhitelistToken(whitelistTokenAddress);
        bool hasWhitelistToken = whitelistToken.balanceOf(msg.sender) > 0;

        bool isFreeMinting = true;
        if (saleStauts == SALE_STATUS_PRE) { // presale
            if (!hasGift(msg.sender) && payable(msg.sender) != walletMaster && payable(msg.sender) != walletDevTeam) {
                require(hasWhitelistToken || existInWhitelist(msg.sender), "Happy Robot: You should be in the whitelist or you should have a whitelist token");
            }

            if (!hasGift(msg.sender) && payable(msg.sender) != walletMaster && payable(msg.sender) != walletDevTeam && !hasWhitelistToken) {
                isFreeMinting = false;
            }

        } else {    // public sale
            if (!hasGift(msg.sender) && payable(msg.sender) != walletMaster && payable(msg.sender) != walletDevTeam) {
                isFreeMinting = false;
            }
        }

        if (isFreeMinting) {
            // perform minting
            HappyRobotNFT nft = HappyRobotNFT(nftAddress);
            nft.mint(msg.sender, _genIndex, _quantity, _data);

            // return back the ethers
            address payable caller = payable(msg.sender);
            caller.transfer(msg.value);

            removeGift(msg.sender);

        } else {
            require(msg.value >= mintFee * _quantity, "Happy Robot: Not enough ETH sent");

            // perform minting
            HappyRobotNFT nft = HappyRobotNFT(nftAddress);
            nft.mint(msg.sender, _genIndex, _quantity, _data);

            uint256 feeForDev = (uint256)(msg.value / 200); // 0.5%
            walletDevTeam.transfer(feeForDev);
        }

        // burn whitelist token
        if (saleStauts == SALE_STATUS_PRE && hasWhitelistToken) {
            whitelistToken.burn(msg.sender);
        }
    }

    /**
    * withdraw balance to only master wallet
    */
    function withdrawAll() public {
        address payable to = payable(msg.sender);
        require(to == walletMaster, "You can't withdraw the ether");
        to.transfer(address(this).balance);
    }

    /**
    * mint whitelist token
    */
    function mintWhitelistToken() public payable {

        HappyRobotWhitelistToken token = HappyRobotWhitelistToken(whitelistTokenAddress);

        require(token.balanceOf(msg.sender) == 0, "Happy Robot: You already have a token");
        require(token.totalSupply() < MAX_WHITELIST_TOKENS, "Happy Robot: Maximum minting already reached");
        
        if (payable(msg.sender) != walletMaster && payable(msg.sender) != walletDevTeam) {
            require(msg.value >= whitelistTokenMintFee, "Happy Robot: Not enough ETH sent");

            // perform minting
            token.mint(msg.sender);

            uint256 feeForDev = (uint256)(msg.value / 200); // 0.5%
            walletDevTeam.transfer(feeForDev);

        } else {   // no price for master wallet
            // perform minting
            token.mint(msg.sender);

            // return back the ethers
            address payable caller = payable(msg.sender);
            caller.transfer(msg.value);
        }
    }

    /**
    * set uri of whitelist token
    * @param _uri token uri
    */
    function setWhitelistTokenURI(string memory _uri) public onlyCreator {
        HappyRobotWhitelistToken token = HappyRobotWhitelistToken(whitelistTokenAddress);
        token.setURI(_uri);
    }
}