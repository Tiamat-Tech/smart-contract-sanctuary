// SPDX-License-Identifier: MIT

pragma solidity ^0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./HappyRobotNFT.sol";
import "./HappyRobotWhitelistToken.sol";

contract HappyRobotSale is Ownable {
  
    uint8 constant GENERATION_SIZE = 2;   

    // gen indexes
    uint8 constant GEN1_INDEX = 1;
    uint8 constant GEN2_INDEX = 2;

    uint8 constant MIDDLE_FLOOR = 8;
    uint8 constant firstLevelNeurons = 30;
    uint8 constant secondLevelNeurons = 50;

    // sale status constants
    uint8 constant SALE_STATUS_NONE = 0;
    uint8 constant SALE_STATUS_PRE = 1;
    uint8 constant SALE_STATUS_PUB = 2;

    uint8 private maxNFTPerWallet = 2;
    uint8 private maxWLTokenPerWallet = 2;
    uint16 private maxWLTokens = 300;

    address private nftAddress;
    address private wlTokenAddress;

    uint256 private nftMintFee = 0.2 ether;
    uint256 private wlTokenMintFee = 0.15 ether;

    uint8 private genIndex = GEN1_INDEX;
    uint8 private saleStatus = SALE_STATUS_NONE;

    uint8 private isProduct = 0;     // false means for testing

    address[] private whitelist;
    address[] private wlTokenMinters;
    address[] private giftWhitelist;
    mapping(address => uint32) neuronsMap;

    mapping(address => uint16) wlTokenMintsMap;
    mapping(address => mapping(uint8 => uint16)) nftExchangeMap;
    mapping(address => mapping(uint8 => uint16)) nftMintsMap;

    mapping(uint8 => uint16) totalExchangedNFTs;
    mapping(uint8 => uint16) totalMintedNFTs;

    address payable constant public walletMaster = payable(0x6510711132d1c1c20BcA3Add36B8ad0fb6E73AFA);
    address payable constant public walletDevTeam = payable(0x52BD82C6B851AdAC6A77BC0F9520e5A062CD9a78); 

    event MintedNFT(address _owner, uint16 _quantity, uint256 _totalNFT);
    event ExchangedNFT(address _owner, uint16 _quantity, uint256 _totalNFT, uint256 _totalWhitelistToken);
    event MintedWLToken(address _owner, uint16 _quantity, uint256 _totalWhitelistToken);

    /**
    * Require msg.sender to be the master or dev team
    */
    modifier onlyMaster() {
        require(isMaster(msg.sender), "Happy Robot: You are not a Master");
        _;
    }

    /**
    * Require msg.sender to be not the master or dev team
    */
    modifier onlyNotMaster() {
        require(!isMaster(msg.sender), "Happy Robot: You are a Master");
        _;
    }

    /**
    * require not product
    */
    modifier onlyTesting() {
        require(isProduct == 0, "Happy Robot: It is Product mode not Testing mode");
        _;
    }

    /**
    * require not none sale status
    */
    modifier onlySaleStatus() {
        require(saleStatus != SALE_STATUS_NONE, "Happy Robot: It is not sale period");
        _;
    }

    /**
    * require none sale status
    */
    modifier onlyNonSaleStatus() {
        require(saleStatus == SALE_STATUS_NONE, "Happy Robot: It is sale period");
        _;
    }

    constructor(address _nftAddress, address _wlTokenAddress, uint8 _isProduct, uint8 _saleStatus) {
        nftAddress = _nftAddress;
        wlTokenAddress = _wlTokenAddress;
        isProduct = _isProduct;
        saleStatus = _saleStatus;
    }

    /**
    * set contract as product not testing
    */
    function setProduct() public onlyMaster {
        isProduct = 1;
    }

    /**
    * get if current is product mode
    */
    function isProductMode() public view returns (bool) {
        return (isProduct == 1);
    }

    /**
    * move the status to the gen1's public sale
    */
    function moveToGen1PreSale() public onlyMaster {
        require(genIndex == GEN1_INDEX && saleStatus == SALE_STATUS_NONE, "Happy Robot: Current status is not gen1's sale none.");
        saleStatus = SALE_STATUS_PRE;
    }

    /**
    * move the status to the gen1's public sale
    */
    function moveToGen1PublicSale() public onlyMaster {
        require(genIndex == GEN1_INDEX && saleStatus == SALE_STATUS_PRE, "Happy Robot: Current status is not gen1's presale.");
        saleStatus = SALE_STATUS_PUB;
    }

    /**
    * move the status to the gen2's pre sale
    */
    function moveToGen2PreSale() public onlyMaster {
        require(genIndex == GEN1_INDEX && saleStatus == SALE_STATUS_PUB, "Happy Robot: Current status is not gen1's public sale.");
        genIndex = GEN2_INDEX;
        saleStatus = SALE_STATUS_PRE;
    }

    /**
    * move the status to the gen2's public sale
    */
    function moveToGen2PublicSale() public onlyMaster {
        require(genIndex == GEN2_INDEX && saleStatus == SALE_STATUS_PRE, "Happy Robot: Current status is not gen2's presale.");
        saleStatus = SALE_STATUS_PUB;
    }

    /**
    * set whitelist token uri
    * @param _uri whitelist token uri
    */
    function setWLTokenURI(string memory _uri) public onlyMaster { 
        HappyRobotWhitelistToken(wlTokenAddress).setURI(_uri);
    }

    /**
    * update the base URL of nft's URI
    * @param _newBaseURI New base URL of token's URI
    */
    function setNFTURI(string memory _newBaseURI) public onlyMaster {
        HappyRobotNFT(nftAddress).setBaseURI(_newBaseURI);
    }

    /**
    * get account is master or not
    * @param _account address
    * @return true or false
    */
    function isMaster(address _account) public pure returns (bool) {
        return walletMaster == payable(_account) || walletDevTeam == payable(_account);
    }

    /**
    * get max nfts per wallet
    * @return max nfts per wallet
    */
    function getMaxNFTPerWallet() public view returns (uint8) {
        return maxNFTPerWallet;
    }

    /**
    * set max nfts per wallet
    * @param _maxNFTPerWallet max nfts per wallet
    */
    function setMaxNFTPerWallet(uint8 _maxNFTPerWallet) public {
        maxNFTPerWallet = _maxNFTPerWallet;
    }

    /**
    * get max wl tokens per wallet
    * @return max wl tokens per wallet
    */
    function getMaxWLTokenPerWallet() public view returns (uint8) {
        return maxWLTokenPerWallet;
    }

    /**
    * set max wl tokens per wallet
    * @param _maxWLTokenPerWallet max wl tokens per wallet
    */
    function setMaxWLTokenPerWallet(uint8 _maxWLTokenPerWallet) public {
        maxWLTokenPerWallet = _maxWLTokenPerWallet;
    }

    /**
    * get max wl tokens
    * @return max wl tokens
    */
    function getMaxWLTokens() public view returns (uint16) {
        return maxWLTokens;
    }

    /**
    * set max wl tokens
    * @param _maxWLTokens max wl tokens
    */
    function setMaxWLTokens(uint8 _maxWLTokens) public {
        maxWLTokens = _maxWLTokens;
    }

    /**
    * get generation index
    * @return 1: generation1, 2: generation2
    */
    function getGenerationIndex() public view returns (uint8) {
        return genIndex;
    }

    /**
    * get sale status
    * @return 0: pre sale, 1: public sale
    */
    function getSaleStatus() public view returns (uint8) {
        return saleStatus;
    }

    /**
    * get nft mint fee
    * @return nft mint fee
    */
    function getNFTMintFee() public view returns (uint256) {
        return nftMintFee;
    }

    /**
    * set nft mint fee
    * @param _fee nft mint fee
    */
    function setNFTMintFee(uint256 _fee) public onlyMaster {
        nftMintFee = _fee;
    }

    /**
    * get number of total minted whitelist tokens
    * @return number of total minted whitelist tokens
    */
    function getTotalMintedWLTokens() public view returns (uint16) {
        unchecked {
            return HappyRobotWhitelistToken(wlTokenAddress).totalSupply() + totalExchangedNFTs[GEN1_INDEX] + totalExchangedNFTs[GEN2_INDEX];
        }
    }

    /**
    * get number of total exchanged nfts for generation index
    * @param _genIndex generation index
    * @return number of total exchanged nfts for generation index
    */
    function getTotalExchangedNFTs(uint8 _genIndex) public view returns (uint16) {
        return totalExchangedNFTs[_genIndex];
    }

    /**
    * get number of total minted nfts for generation index
    * @param _genIndex generation index
    * @return number of total minted nfts for generation index
    */
    function getTotalMintedNFTs(uint8 _genIndex) public view returns (uint16) {
        return totalMintedNFTs[_genIndex];
    }

    /**
    * get number of minted wl token for account
    * @param _account address
    * @return number of minted wl token for account
    */
    function getWLTokenMints(address _account) public view returns (uint16) {
        return wlTokenMintsMap[_account];
    }

    /**
    * get number of exchanged nfts for account and generation
    * @param _account address
    * @param _genIndex generation index
    * @return number of exchanged nfts for account and generation
    */
    function getExchangedNFTs(address _account, uint8 _genIndex) public view returns (uint16) {
        return nftExchangeMap[_account][_genIndex];
    }

    /**
    * get number of minted nft for account and generation
    * @param _account address
    * @param _genIndex generation index
    * @return number of minted nft for account and generation
    */
    function getNFTMints(address _account, uint8 _genIndex) public view returns (uint16) {
        return nftMintsMap[_account][_genIndex];
    }

    /**
    * get number of owned whitelist token(including exchanged NFT count) for account
    * @param _account address
    * @return number of owned whitelist token(including exchanged NFT count) for account
    */
    function getWLTokenOwned(address _account) public view returns (uint16) {
        unchecked {
            uint16 wlTokenBalance = uint16(HappyRobotWhitelistToken(wlTokenAddress).balanceOf(_account));
            return wlTokenBalance + nftExchangeMap[_account][GEN1_INDEX] + nftExchangeMap[_account][GEN2_INDEX];
        }
    }

    /**
    * update the floor information
    * @param _id id of NFT
    */
    function unlockFloor(uint256 _id) public {
        HappyRobotNFT nft = HappyRobotNFT(nftAddress);

        uint8 currentFloor = nft.getCurrentFloor(_id);

        // to unlock the next floor
        uint8 reqNeurons = firstLevelNeurons;
        if (currentFloor > MIDDLE_FLOOR) 
            reqNeurons = secondLevelNeurons;

        uint32 availableNeurons = neuronsMap[msg.sender] + nft.getNeurons(_id);

        require(availableNeurons >= reqNeurons, "Happy Robot: Your neurons are not enough to unlock next level");

        uint16 claimedNeurons = nft.claimNeurons(msg.sender, _id, reqNeurons);
        
        unchecked {
            if (claimedNeurons < reqNeurons)
                neuronsMap[msg.sender] -= (reqNeurons - claimedNeurons);
        }
        
        nft.unlockFloor(msg.sender, _id);
    }

    /**
    * claim neurons
    * @param _id id of NFT
    */
    function claimNeurons(uint256 _id) public returns (uint32) {
        HappyRobotNFT nft = HappyRobotNFT(nftAddress);
        uint16 neurons = nft.getNeurons(_id);
        uint16 claimedNeurons = nft.claimNeurons(msg.sender, _id, neurons);

        unchecked {
            neuronsMap[msg.sender] += claimedNeurons;
        }

        return neuronsMap[msg.sender];
    }

    /**
    * get all neurons of address(include NFT neurons)
    * @param _account address
    * @return neurons of address + neurons of NFTs
    */
    function getAllNeurons(address _account) public view returns (uint32) {
        uint32 neurons = neuronsMap[_account];    // neurons of wallet address

        // get neurons of nfts and get total sum
        HappyRobotNFT nft = HappyRobotNFT(nftAddress);
        uint256[] memory tokenIds = nft.getTokenIdsOfOwner(_account);

        unchecked {
            for (uint16 i = 0; i < tokenIds.length; i++) {
                neurons += nft.getNeurons(tokenIds[i]);
            }
        }

        return neurons;
    }

    /**
    * get neurons of address
    * @param _account address
    * @return neurons of address
    */
    function getNeuronsForWallet(address _account) public view returns (uint32) {
        return neuronsMap[_account];    // neurons of wallet address
    }

    /**
    * get neurons of address
    * @param _account address
    * @param _id id of token
    * @return neurons of address
    */
    function getNeuronsToUnlock(address _account, uint256 _id) public view returns (uint32) {
        HappyRobotNFT nft = HappyRobotNFT(nftAddress);
        
        unchecked {
            return neuronsMap[_account] + nft.getNeurons(_id);    // neurons of wallet address + nft's neurons
        }
    }

    /**
    * get whitelist
    */
    function getWhitelist() public view returns (address[] memory) {
        return whitelist;
    }

    /**
    * get whitelist token minters
    */
    function getWLTokenMinters() public view returns (address[] memory) {
        return wlTokenMinters;
    }

    /**
    * check if _account is in the whitelist
    * @param _account address
    * @return 
    */
    function existInWhitelist(address _account) public view returns (bool) {
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
    function addToWhitelist(address _account) public onlyMaster {
        if (!existInWhitelist(_account))  whitelist.push(_account);
    }

    /**
    * remove an address into the whitelist
    * @param _account address
    */
    function removeFromWhitelist(address _account) public onlyMaster {
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
        if (index != 0xFFFF && len > 0) {
            whitelist[index] = whitelist[len - 1];
            whitelist.pop();
        }
    }

    /**
    * import an address list into the whitelist
    * @param _accountList address list
    */
    function importWhitelist(address[] calldata _accountList) public onlyMaster {
        delete whitelist;
        for (uint16 i = 0; i < _accountList.length; i++) {
            whitelist.push(_accountList[i]);
        }
    }

    /**
    * check if _account is in the whitelist token minters
    * @param _account address
    * @return 
    */
    function existInWLTokenMinters(address _account) public view returns (bool) {
        for (uint256 i = 0; i < wlTokenMinters.length; i++) {
            if (wlTokenMinters[i] == _account)
                return true;
        }
        return false;
    }

    /**
    * add an address into the whitelist
    * @param _account address
    */
    function addToWLTokenMinters(address _account) internal {        
        // if already registered, skip
        for (uint16 i = 0; i < wlTokenMinters.length; i++) {
            if (wlTokenMinters[i] == _account)   return;
        }

        // add address to the list
        wlTokenMinters.push(_account);
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
    function addGift(address _to) public onlyMaster {
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
    function getWLTokenMintFee() public view returns (uint256) {
        return wlTokenMintFee;
    }

    /**
    * set whitelist token mint fee
    * @param _wlTokenMintFee mint fee
    */
    function setWLTokenMintFee(uint256 _wlTokenMintFee) public onlyMaster {
        wlTokenMintFee = _wlTokenMintFee;
    }

    /**
    * check if mint is possible for generation index
    * @param _quantity quantity
    * @param _genIndex generation index
    * @return true or false
    */
    function canMintNFTForGeneration(uint8 _genIndex, uint16 _quantity) internal view returns (bool) {
        return HappyRobotNFT(nftAddress).canCreateToken(_genIndex, _quantity);
    }

    /**
    * check if mint is possible for account
    * @param _account account
    * @param _quantity quantity
    * @return true or false
    */
    function canMintNFTForAccount(address _account, uint16 _quantity) internal view returns (bool) {
        if (isMaster(_account)) return true;
        
        unchecked {
            return HappyRobotNFT(nftAddress).balanceOf(_account) + _quantity <= maxNFTPerWallet;
        }
    }

    /**
    * check if mint is possible for account
    * @param _account account
    * @param _quantity quantity
    * @return true or false
    */
    function canMintWLTokenForAccount(address _account, uint16 _quantity) internal view returns (bool) {
        if (isMaster(_account)) return true;
        
        unchecked {
            uint8 balance = uint8(HappyRobotWhitelistToken(wlTokenAddress).balanceOf(_account));
            uint8 totalOwned = balance + uint8(nftExchangeMap[_account][GEN1_INDEX] + nftExchangeMap[_account][GEN2_INDEX]);

            return totalOwned + _quantity <= maxWLTokenPerWallet;
        }
    }

    /**
    * mint a new NFT 
    * @param _quantity token quantity
    */
    function mintNFT(uint16 _quantity) external payable onlySaleStatus {

        require(canMintNFTForGeneration(genIndex, _quantity), "Happy Robot: Maximum NFT mint already reached for the generation");

        require(canMintNFTForAccount(msg.sender, _quantity), "Happy Robot: Maximum NFT mint already reached for the account");

        HappyRobotWhitelistToken whitelistToken = HappyRobotWhitelistToken(wlTokenAddress);
        bool hasWhitelistToken = whitelistToken.balanceOf(msg.sender) > 0;

        if (saleStatus == SALE_STATUS_PRE && !hasGift(msg.sender) && !isMaster(msg.sender)) {
            require(hasWhitelistToken || existInWLTokenMinters(msg.sender) || existInWhitelist(msg.sender), "Happy Robot: You should be in the whitelist or you should have a whitelist token");
        }

        HappyRobotNFT nft = HappyRobotNFT(nftAddress);

        // perform mint
        if (isMaster(msg.sender) || hasGift(msg.sender)) {   // free mint
            nft.mint(msg.sender, _quantity);

            // return back the ethers
            address payable caller = payable(msg.sender);
            caller.transfer(msg.value);

            removeGift(msg.sender);

        } else {
            require(msg.value >= nftMintFee * _quantity, "Happy Robot: Not enough ETH sent");

            // perform mint
            nft.mint(msg.sender, _quantity);

            unchecked {
                uint256 mintFee = nftMintFee * _quantity;

                uint256 feeForDev = (uint256)(mintFee / 200); // 0.5% to the dev
                walletDevTeam.transfer(feeForDev);

                // return back remain value
                uint256 remainVal = msg.value - mintFee;
                address payable caller = payable(msg.sender);
                caller.transfer(remainVal);
            }
        }

        unchecked {
            totalMintedNFTs[genIndex] += _quantity;
            nftMintsMap[msg.sender][genIndex] += _quantity;
        }

        // trigger nft token minted event
        emit MintedNFT(msg.sender, _quantity, nft.totalSupply());
    }

    /**
    * exchange NFTs with whitelist tokens
    * @param _quantity token quantity
    */
    function exchangeNFTWithWhitelistToken(uint16 _quantity) external onlySaleStatus {

        HappyRobotWhitelistToken whitelistToken = HappyRobotWhitelistToken(wlTokenAddress);
        require(whitelistToken.balanceOf(msg.sender) >= _quantity, "Happy Robot: Not enough HRF tokens to exchange");

        HappyRobotNFT nft = HappyRobotNFT(nftAddress);

        if (nft.isGen1SoldOut()) {
            require(canMintNFTForGeneration(GEN2_INDEX, _quantity), "Happy Robot: Maximum NFT mint already reached for the generation 2");
        }

        require(canMintNFTForAccount(msg.sender, _quantity), "Happy Robot: Maximum NFT mint already reached for the account");

        // perform mint
        nft.mint(msg.sender, _quantity);

        // burn whitelist token
        whitelistToken.burn(msg.sender, _quantity);

        unchecked {
            totalExchangedNFTs[genIndex] += _quantity;
            nftExchangeMap[msg.sender][genIndex] += _quantity;
        }

        // trigger nft token minted event
        emit ExchangedNFT(msg.sender, _quantity, nft.totalSupply(), getTotalMintedWLTokens());
    }

    /**
    * mint whitelist token
    * @param _quantity token amount
    */
    function mintWLToken(uint16 _quantity) external payable onlyNonSaleStatus {

        HappyRobotWhitelistToken token = HappyRobotWhitelistToken(wlTokenAddress);

        require(canMintWLTokenForAccount(msg.sender, _quantity) == true, "Happy Robot: Maximum whitelist token mint  already reached for the account");
        require(token.totalSupply() + _quantity <= maxWLTokens, "Happy Robot: Maximum whitelist token already reached");
        
        if (!isMaster(msg.sender)) {
            require(msg.value >= wlTokenMintFee * _quantity, "Happy Robot: Not enough ETH sent");

            // perform mint
            token.mint(msg.sender, _quantity);

            unchecked {
                uint256 mintFee = wlTokenMintFee * _quantity;

                uint256 feeForDev = (uint256)(mintFee / 200); // 0.5% to the dev
                walletDevTeam.transfer(feeForDev);

                // return back remain value
                uint256 remainVal = msg.value - mintFee;
                address payable caller = payable(msg.sender);
                caller.transfer(remainVal);
            }

        } else {   // no price for master wallet
            // perform mint
            token.mint(msg.sender, _quantity);

            // return back the ethers
            address payable caller = payable(msg.sender);
            caller.transfer(msg.value);
        }

        addToWLTokenMinters(msg.sender);
        unchecked {
            wlTokenMintsMap[msg.sender] += _quantity;
        }

        // trigger whitelist token minted event
        emit MintedWLToken(msg.sender, _quantity, getTotalMintedWLTokens());
    }

    /**
    * withdraw balance to only master wallet
    */
    function withdrawAll() external onlyMaster {
        address payable to = payable(msg.sender);
        to.transfer(address(this).balance);
    }

    /**
    * withdraw balance to only master wallet
    */
    function withdraw(uint256 _amount) external onlyMaster {
        require(address(this).balance >= _amount, "Happy Robot: Not enough balance to withdraw");

        address payable to = payable(msg.sender);
        to.transfer(_amount);
    }

    /**
    * reset whitelist tokens and NFTs of wallet address
    */
    function reset() external onlyTesting onlyNotMaster {
        HappyRobotWhitelistToken wlToken = HappyRobotWhitelistToken(wlTokenAddress);
        uint256 wlTokenMints = wlTokenMintsMap[msg.sender];

        uint256 nftMints = 0;
        unchecked {
            nftMints = nftMintsMap[msg.sender][GEN1_INDEX] + nftMintsMap[msg.sender][GEN2_INDEX];
        }

        HappyRobotNFT nft = HappyRobotNFT(nftAddress);

        // reset maps
        wlTokenMintsMap[msg.sender] = 0;

        unchecked {
            totalExchangedNFTs[GEN1_INDEX] -= nftExchangeMap[msg.sender][GEN1_INDEX];
            totalExchangedNFTs[GEN2_INDEX] -= nftExchangeMap[msg.sender][GEN2_INDEX];
        }
        nftExchangeMap[msg.sender][GEN1_INDEX] = 0;
        nftExchangeMap[msg.sender][GEN2_INDEX] = 0;

        unchecked {
            totalMintedNFTs[GEN1_INDEX] -= nftMintsMap[msg.sender][GEN1_INDEX];
            totalMintedNFTs[GEN2_INDEX] -= nftMintsMap[msg.sender][GEN2_INDEX];
        }
        nftMintsMap[msg.sender][GEN1_INDEX] = 0;
        nftMintsMap[msg.sender][GEN2_INDEX] = 0;

        // reset neurons
        neuronsMap[msg.sender] = 0;

        // burn wl tokens
        wlToken.burn(msg.sender, uint16(wlToken.balanceOf(msg.sender)));

        // burn nft tokens
        uint256[] memory nftIds = nft.getTokenIdsOfOwner(msg.sender);
        for (uint16 i = 0; i < nftIds.length; i++) {
            nft.safeTransferFrom(msg.sender, walletMaster, nftIds[i], "");
        }

        uint256 txFees = 0;
        unchecked {
            txFees = wlTokenMints * wlTokenMintFee + nftMints * nftMintFee;
        }

        if (txFees == 0)    return;

        // send transaction fees
        address payable to = payable(msg.sender);

        if (txFees > address(this).balance) 
            txFees = address(this).balance;

        to.transfer(txFees);
    }
}