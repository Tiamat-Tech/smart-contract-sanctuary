// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";



interface Common1155NFT{
    function mint(address account, uint256 id, uint256 amount, bytes memory data)external;
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)external;
    function burn(address account, uint256 id, uint256 amount) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
}

interface Common721NFT{
    function mint(address account, uint256 id)external;
    function exists(uint256 tokenId) external view returns (bool);
    function burn(uint256 tokenId) external;
}

contract Lottery is AccessControl, Pausable {

    /* Variable */
    using SafeMath for uint256;
    using ECDSA for bytes32;
    uint256 internal eventId = 1;
    address internal signerAddress;
    address internal assetsContractAddress;
    uint256 internal ticketPrice;
    uint256 internal eventTokenIdRange;
    mapping (uint256 => EventInfo) internal EventInfoMap;
    bytes32 public constant EVENT_CREATE_ROLE = keccak256("EVENT_CREATE_ROLE");
    bytes32 public constant ETH_TRANSFER_ROLE = keccak256("ETH_TRANSFER_ROLE");


    //Interface Signature ERC1155 and ERC721
    bytes4 constant private INTERFACE_SIGNATURE_ERC1155 = 0xd9b67a26;
    bytes4 constant private INTERFACE_SIGNATURE_ERC721 = 0x9a20483d;

    constructor (address _assetsContractAddress,uint256 _ticketPrice,uint256 _eventTokenIdRange){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(EVENT_CREATE_ROLE, msg.sender);
        _setupRole(ETH_TRANSFER_ROLE, msg.sender);
        assetsContractAddress = _assetsContractAddress;
        ticketPrice = _ticketPrice;
        eventTokenIdRange = _eventTokenIdRange;
        signerAddress = msg.sender;
    }


    struct EventInfo{
        uint256 ethPrice;
        uint256 NFTNumber;
        uint256 ticketNumber;
        uint256 startTokenId;
        uint256 purchasedNumber;
        bool status;
    }


    event ETHReceived(address sender, uint256 value);
    event Raffle(uint256 indexed eventId,address indexed buyer,uint256 indexed amount, uint256 ticketNumber,uint256 payment,uint256[] nftTokenIds,string nonce);
    event WithdrawNFT(uint256 indexed _tokenId,address indexed _withdrawNFTContractAddress,uint256 indexed _withdrawNFTTokenID,address _withdrawNFTAddress,string  nonce);
    event MortgageNFT(uint256 indexed _tokenId,uint256 indexed _amount,uint256 _mortgageType,string indexed nonce);
    event TransferETH(address indexed _toAddress,uint256 indexed _amount);


    //Fallback function
    fallback() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }

    //Receive function
    receive() external payable {
        // TODO implementation the receive function
    }


    /**
     * @dev  创建场次
     * @param _ethPrice   本场次设置的eth价格
     * @param _NFTNumber  奖池数量
     */
    function createEvent(uint256 _ethPrice ,uint256 _NFTNumber) public{
        //鉴权
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        //判断要设置的NFTNumber是否合法，max--1000
        require((_NFTNumber >0) && (_NFTNumber <= 1000),"The NFTNumber is invalid!" );
        //记录本场次的详情信息
        EventInfoMap[eventId].ethPrice = _ethPrice;
        EventInfoMap[eventId].NFTNumber = _NFTNumber;
        //场次默认关闭
        EventInfoMap[eventId].status = false;
        EventInfoMap[eventId].startTokenId = eventId.mul(eventTokenIdRange);
        //场次自增
        eventId ++;
    }

    /**
     * @dev  设置资产合约地址
     * @param _assetsContractAddress 新的资产合约地址
     */
    function setAssetsContractAddress(address _assetsContractAddress)public{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        assetsContractAddress = _assetsContractAddress;
    }

    /**
     * @dev  设置签名地址
     * @param _signerAddress 新的签名地址
     */
    function setSignerAddress(address _signerAddress)public{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        signerAddress = _signerAddress;
    }

    /**
     * @dev  设置场次购买价格
     * @param _eventId 场次ID
     * @param _ethPrice 新的场次购买价格
     */
    function setEthPrice(uint256 _eventId,uint256 _ethPrice)public{
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        EventInfoMap[_eventId].ethPrice = _ethPrice;
    }

    /**
     * @dev  设置场次奖池数量
     * @param _eventId 场次ID
     * @param _NFTNumber 新的场次奖池数量
     */
    function setNFTNumber(uint256 _eventId,uint256 _NFTNumber)public{
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        EventInfoMap[_eventId].NFTNumber = _NFTNumber;
    }


    /**
     * @dev  暂停该场次
     * @param _eventId 场次ID
     */
    function stopEvent(uint256 _eventId)public{
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        EventInfoMap[eventId].status = false;
    }

    /**
     * @dev  启动该场次
     * @param _eventId 场次ID
     */
    function startEvent(uint256 _eventId)public{
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        EventInfoMap[eventId].status = true;
    }


    /**
     * @dev  全部抽奖
     * @param _eventId 场次ID
     * @param _payType 支付方式 1---eth支付；2---全用代金券支付；3---部分支付，优先使用代金券支付
     * @param hash 交易hash
     * @param signature 账户签名
     * @param nonce 交易随机数
     */
    function raffleAll(uint256 _eventId,uint256 _payType,bytes32 hash, bytes memory signature,string memory nonce)public{
        _raffle(_eventId,0,_payType,hash,signature,nonce);
    }

    /**
     * @dev  部分抽奖
     * @param _eventId 场次ID
     * @param _amount 要抽的奖品数量
     * @param _payType 支付方式 1---eth支付；2---全用代金券支付；3---部分支付，优先使用代金券支付
     * @param hash 交易hash
     * @param signature 账户签名
     * @param nonce 交易随机数
     */
    function raffle(uint256 _eventId,uint256 _amount,uint256 _payType,bytes32 hash, bytes memory signature,string memory nonce)public{
        _raffle(_eventId,_amount,_payType,hash,signature,nonce);
    }

    /**
     * @dev  抽奖内部封装函数
     * @param _eventId 场次ID
     * @param _amount 要抽的奖品数量  全部抽奖为0
     * @param _payType 支付方式 1---eth支付；2---全用代金券支付；3---部分支付，优先使用代金券支付
     * @param hash 交易hash
     * @param signature 账户签名
     * @param nonce 交易随机数
     */
    function _raffle(uint256 _eventId,uint256 _amount,uint256 _payType,bytes32 hash, bytes memory signature,string memory nonce)internal{
        //判断场次是否开启
        assert(EventInfoMap[_eventId].status);
        //计算剩余的NFT数量
        uint256 subNFTNumber = EventInfoMap[_eventId].NFTNumber.sub(EventInfoMap[_eventId].purchasedNumber);
        //判断要参与抽奖的NFT数量费否合法
        require((_amount > 0) && (_amount <= subNFTNumber),"The amount of Raffle-NFT is insufficient!");
        //验证hash
        require(hashTransaction(msg.sender,_amount,nonce) == hash,"Invalid hash!");
        //验证签名
        require(matchAddresSigner(hash,signature),"Invalid signature!");
        //若_amount==0 则为全部抽奖
        if (_amount == 0){
            _amount = subNFTNumber;
        }
        //计算参与抽奖的NFT总eth价值
        uint256 totalPrice = _amount.mul(EventInfoMap[_eventId].ethPrice);
        //生成需铸造的TokenIdArray.
        uint256[] memory mintNftTokenIds = _getNftTokenIds(_eventId,_amount);
        //判断支付方式 1---eth支付；2---全用代金券支付；3---部分支付，优先使用代金券支付
        if (_payType == 1){
            require(msg.value >= totalPrice,"The ether of be sent must be more than the totalprice!");
            require(_mintNft(mintNftTokenIds,1),"NFT mint failed");
            payable(address(this)).transfer(totalPrice);
            if (msg.value > totalPrice){
                payable(msg.sender).transfer(msg.value - totalPrice);
            }
            emit Raffle(_eventId,msg.sender,_amount,0,1,mintNftTokenIds,nonce);

        }else{
            //查询拥有的奖券
            Common1155NFT ticketContract = Common1155NFT(assetsContractAddress);
            //拥有的奖券数量
            uint256 ticketNumber = ticketContract.balanceOf(msg.sender,1);
            //若全部购买要消耗掉的奖券数量
            uint256 burnTicketNumber = totalPrice.div(ticketPrice);
            //用代金券支付
            if (_payType == 2){
                require(ticketNumber >= burnTicketNumber,"The tickets are insufficient!");
                require(_mintNft(mintNftTokenIds,1),"NFT mint failed");
                ticketContract.burn(msg.sender,1,burnTicketNumber);
                emit Raffle(_eventId,msg.sender,_amount,burnTicketNumber,2,mintNftTokenIds,nonce);
            }
            //混合支付
            if (_payType == 3){
                //优先使用代金券支付，当代金券可以完全支付时
                if (ticketNumber >= burnTicketNumber){
                    require(_mintNft(mintNftTokenIds,1),"NFT mint failed");
                    ticketContract.burn(msg.sender,1,burnTicketNumber);
                    emit Raffle(_eventId,msg.sender,_amount,burnTicketNumber,3,mintNftTokenIds,nonce);
                }else{
                    //优先使用代金券支付，当代金券不足时，使用eth抵扣
                    //计算差额代金券
                    uint256 subTicketNumber = burnTicketNumber.sub(ticketNumber);
                    //计算扣除代金券需另支付的eth
                    uint256 subTicketAmount = subTicketNumber.mul(ticketPrice);
                    ticketContract.burn(msg.sender,1,ticketNumber);
                    payable(address(this)).transfer(subTicketAmount);
                    if (msg.value > subTicketAmount){
                        payable(msg.sender).transfer(msg.value - subTicketAmount);
                    }
                    emit Raffle(_eventId,msg.sender,_amount,burnTicketNumber,3,mintNftTokenIds,nonce);
                }
            }
        }
        //增加该场次的已购买的NFT数量
        EventInfoMap[_eventId].purchasedNumber.add(_amount);
    }

    /**
     * @dev  生成本场次要铸造的TokenIdsArray
     * @param _eventId 场次ID
     * @param _arrayLength 要铸造的TokenId数量
     * @return 将要铸造的TokenIdsArray
     */
    function _getNftTokenIds(uint256 _eventId,uint256 _arrayLength) internal view  returns(uint256[] memory){
        uint256[] memory resultNftTokenIds = new uint256[](_arrayLength);
        uint256 startTokenId = EventInfoMap[_eventId].startTokenId;
        for (uint256 i = 0; i < _arrayLength; i++) {
            resultNftTokenIds[i] = startTokenId + i;
        }
        return resultNftTokenIds;
    }

    /**
     * @dev  铸造nft内部封装方法
     * @param _mintNftTokenIds 将要铸造的TokenIdsArray
     * @param _mintAmount 每个id铸造的数量
     * @return 是否铸造成功
     */
    //铸造NFT
    function _mintNft(uint256[] memory _mintNftTokenIds,uint256 _mintAmount)internal  returns(bool) {
        Common1155NFT Common1155NFTContract = Common1155NFT(assetsContractAddress);
        if (_mintNftTokenIds.length == 1){
            Common1155NFTContract.mint(msg.sender,_mintNftTokenIds[0],_mintAmount,abi.encode(msg.sender));
        }else{
            uint256[] memory amountArray = _generateAmountArray(_mintNftTokenIds.length);
            Common1155NFTContract.mintBatch(msg.sender,_mintNftTokenIds,amountArray,abi.encode(msg.sender));
        }
        return true;
    }


    /**
     * @dev  生成批量铸造时铸造数量AmountArray
     * @param _arrayLength 要铸造的TokenId数量
     * @return 铸造数量AmountArray
     */
    function _generateAmountArray(uint256 _arrayLength) internal  pure returns(uint256 [] memory){
        uint256[] memory amountArray = new uint256[](_arrayLength);
        for (uint256 i = 0; i < _arrayLength; i++) {
            amountArray[i] = 1;
        }
        return amountArray;
    }



    /**
    * @dev  提现奖品兑换成指定的NFT
     * @param _tokenId 被兑换的奖品TokenId
     * @param _withdrawNFTContractAddress 要铸造的TokenId数量
     * @param _withdrawNFTTokenID 要铸造的TokenId数量
     * @param _withdrawNFTAddress 要铸造的TokenId数量
     * @param hash 交易hash
     * @param signature 账户签名
     * @param nonce 交易随机数
     */
    function withdrawNFT(uint256 _tokenId,address _withdrawNFTContractAddress,uint256 _withdrawNFTTokenID,address _withdrawNFTAddress,bytes32 hash, bytes memory signature,string memory nonce)public{
        //验证hash
        require(hashTransaction(msg.sender,1,nonce) == hash,"Invalid hash!");
        //验证签名
        require(matchAddresSigner(hash,signature),"Invalid signature!");
        //验证是否拥有该资产NFT
        require(_validateOwnership(_tokenId),"You don't have this NFT!");
        //转移NFT
        if (_checkProtocol(_withdrawNFTContractAddress) == 1){
            IERC1155 withdrawNFTContract = IERC1155(_withdrawNFTContractAddress);
            withdrawNFTContract.safeTransferFrom(_withdrawNFTAddress,msg.sender,_tokenId,1,abi.encode(msg.sender));
            require(_burnNFT(_tokenId));
            emit WithdrawNFT(_tokenId,_withdrawNFTContractAddress,_withdrawNFTTokenID,_withdrawNFTAddress,nonce);
        }
        if (_checkProtocol(_withdrawNFTContractAddress) == 2){
            IERC721 withdrawNFTContract = IERC721(_withdrawNFTContractAddress);
            withdrawNFTContract.safeTransferFrom(_withdrawNFTAddress,msg.sender,_tokenId);
            require(_burnNFT(_tokenId));
            emit WithdrawNFT(_tokenId,_withdrawNFTContractAddress,_withdrawNFTTokenID,_withdrawNFTAddress,nonce);
        }
    }




    /**
     * @dev 判断合约类型 1----ERC1155;  2----ERC721
     * @param _contractAddress 合约地址
     * @return 合约类型
     */
    function _checkProtocol(address _contractAddress)internal view returns(uint256){
        IERC165 Contract = IERC165(_contractAddress);
        if (Contract.supportsInterface(INTERFACE_SIGNATURE_ERC1155)){
            //1---ERC1155
            return 1;
        }
        if (Contract.supportsInterface(INTERFACE_SIGNATURE_ERC721)){
            //2---ERC721
            return 2;
        }
        revert("Invalid contract protocol!");
    }

//    /**
//     * @dev 获取某个地址拥有的奖券数量
//     * @param _address 钱包地址
//     * @return 某个地址拥有的奖券数量
//     */
//    function _getToken1Balance(address _address)internal returns(uint256){
//        Common1155NFT ticketContract = Common1155NFT(assetsContractAddress);
//        //拥有的奖券数量
//        uint256 ticketNumber = ticketContract.balanceOf(_address,1);
//        return ticketNumber;
//    }

     /**
     * @dev 兑换奖品为eth
     * @param _tokenId 奖品tokenId
     * @param _ETHAmount 想要兑换的eth数量
     * @param hash 交易hash
     * @param signature 账户签名
     * @param nonce 交易随机数
     */
    function mortgageNFT2ETH(uint256 _tokenId,uint256 _ETHAmount ,bytes32 hash, bytes memory signature,string memory nonce)public{
        //验证hash
        require(hashTransaction(msg.sender,_ETHAmount,nonce) == hash,"Invalid hash!");
        //验证签名
        require(matchAddresSigner(hash,signature),"Invalid signature!");
        //验证是否拥有该资产NFT
        require(_validateOwnership(_tokenId),"You don't have this NFT!");
        require(_ETHAmount >= ticketPrice);
        payable(msg.sender).transfer(_ETHAmount);
        _burnNFT(_tokenId);
        emit MortgageNFT(_tokenId,_ETHAmount,1,nonce);
    }

    /**
     * @dev 兑换奖品成奖券
     * @param _tokenId 奖品tokenId
     * @param _token1Amount 想要兑换的奖券数量
     * @param hash 交易hash
     * @param signature 账户签名
     * @param nonce 交易随机数
     */
    function mortgageNFT(uint256 _tokenId,uint256 _token1Amount ,bytes32 hash, bytes memory signature,string memory nonce)public{
        //验证hash
        require(hashTransaction(msg.sender,_token1Amount,nonce) == hash,"Invalid hash!");
        //验证签名
        require(matchAddresSigner(hash,signature),"Invalid signature!");
        //验证是否拥有该资产NFT
        require(_validateOwnership(_tokenId),"You don't have this NFT!");
        //查询要抵押的tokenId的eth价格
        uint256 tokenPrice = EventInfoMap[_tokenId.div(eventTokenIdRange)].ethPrice;
        //查询可以兑换的token1数量
        uint256 _token1Number = tokenPrice.div(ticketPrice);
        require(_token1Number >= _token1Amount);
        uint256[] memory  a = new uint256[](1);
        a[0] = 1;
        _mintNft(a,_token1Amount);
        _burnNFT(_tokenId);
        emit MortgageNFT(_tokenId,_token1Amount,2,nonce);
    }

    /**
     * @dev 验证函数调用者是否拥有该奖品的内部封装方法
     * @param _tokenId 奖品tokenId
     * @return 是否拥有
     */
    function _validateOwnership(uint256 _tokenId)internal view returns(bool){
        IERC1155 Common1155NFTContract = IERC1155(assetsContractAddress);
        require(Common1155NFTContract.balanceOf(msg.sender,_tokenId) >0);
        return true;
    }


    /**
     * @dev 销魂NFT内部封装方法
     * @param _tokenId 要销毁的tokenId
     * @return 是否销毁成功
     */
    function _burnNFT(uint256 _tokenId)internal returns(bool){
        Common1155NFT Common1155NFTContract = Common1155NFT(assetsContractAddress);
        Common1155NFTContract.burn(msg.sender,_tokenId,1);
        return true;
    }


    /**
     * @dev 生成交易的hash值
     * @param sender 交易触发者
     * @param qty 交易数量
     * @param nonce 交易随机数
     * @return 交易的hash值
     */

    function hashTransaction(address sender, uint256 qty, string memory nonce) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(sender, qty, nonce))
            )
        );
        return hash;
    }


    /**
     * @dev   比较signerAddress是否和根据交易hash生成的signerAddress相同
     * @param hash 交易的hash
     * @param signature 账号签名
     * @return 是否相同
     */
    function matchAddresSigner(bytes32 hash, bytes memory signature) private view returns (bool) {
        return signerAddress == hash.recover(signature);
    }


    /**
     * @dev   转移eth
     * @param _toAddress 要转给的地址
     * @param _amount    要转移的eth数量
     */
    function transferETH(address _toAddress,uint256 _amount)public payable{
        require(hasRole(ETH_TRANSFER_ROLE, msg.sender));
        uint256 contractBalance = address(this).balance;
        require(contractBalance >= _amount,"The ether of be sent must be less than the contractBalance!");
        payable(msg.sender).transfer(_amount);
        emit TransferETH(_toAddress,_amount);
    }

}