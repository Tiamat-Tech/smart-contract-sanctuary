// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";


interface Common1155NFT{
    function mint(address account, uint256 id, uint256 amount, bytes memory data)external;
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data)external;
    function burn(address account, uint256 id, uint256 amount) external;
    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
}


interface Common721NFT{
    function mint(address account, uint256 id)external;
    function exists(uint256 tokenId) external view returns (bool);
    function burn(uint256 tokenId) external;
}


contract LotteryV1 is AccessControl, Pausable {

    /* Variable */
    using SafeMath for uint256;
    uint256 internal eventId = 1;
    address internal signerAddress;//签名钱包地址
    address internal assetsContractAddress;//资产合约地址
    address internal ticketContractAddress;//奖券合约地址
    uint256 internal ticketPrice;//奖券价格
    uint256 internal eventTokenIdRange;//场次TokenId范围
    mapping (uint256 => EventInfo) internal EventInfoMap;
    bytes32 public constant EVENT_CREATE_ROLE = keccak256("EVENT_CREATE_ROLE");
    bytes32 public constant ETH_TRANSFER_ROLE = keccak256("ETH_TRANSFER_ROLE");


    //Interface Signature ERC1155 and ERC721
    bytes4 constant private INTERFACE_SIGNATURE_ERC1155 = 0xd9b67a26;
    bytes4 constant private INTERFACE_SIGNATURE_ERC721 = 0x9a20483d;

    constructor (uint256 _ticketPrice,uint256 _eventTokenIdRange,address _assetsContractAddress,address _ticketContractAddress){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(EVENT_CREATE_ROLE, msg.sender);
        _setupRole(ETH_TRANSFER_ROLE, msg.sender);
        assetsContractAddress = _assetsContractAddress;
        ticketContractAddress = _ticketContractAddress;
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
        address NFTContractAddress;
        bool status;
    }

    /* Event */
    event ETHReceived(address sender, uint256 value);
    event Raffle(uint256 indexed eventId,address indexed buyer,uint256 indexed amount, uint256 ticketNumber,uint256 payType,uint256[] nftTokenIds,string nonce);
    event WithdrawNFT(uint256 indexed _tokenId,address indexed _withdrawNFTContractAddress,uint256 indexed _withdrawNFTTokenID,address _withdrawNFTAddress,string nonce);
    event BathConvertNFT(uint256 indexed _amount,address indexed _from,string indexed _convertType,uint256[] _tokenIds,string nonce);
    event ConvertNFT(uint256 indexed _tokenId,uint256 indexed _amount,address indexed _from,string nonce ,string _convertType);


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
     * @param _NFTContractAddress 奖品NFT合约地址
     */
    function createEvent(uint256 _ethPrice ,uint256 _NFTNumber,address _NFTContractAddress) public{
        //鉴权
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        //判断要设置的NFTNumber是否合法，max--1000
        require((_NFTNumber >0) && (_NFTNumber <= 1000),"The NFTNumber is invalid!" );
        //记录本场次的详细信息
        EventInfoMap[eventId].ethPrice = _ethPrice;
        EventInfoMap[eventId].NFTNumber = _NFTNumber;
        EventInfoMap[eventId].NFTContractAddress = _NFTContractAddress;
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
     * @dev  设置NFT合约地址
     * @param _NFTContractAddress 新的NFT合约地址
     * @param _eventId 场次ID
     */
    function setNFTContractAddress(uint256 _eventId,address _NFTContractAddress)public{
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        EventInfoMap[_eventId].NFTContractAddress = _NFTContractAddress;
    }

    /**
     * @dev  设置签名钱包地址
     * @param _signerAddress 新的签名钱包地址
     */
    function setSignerAddress(address _signerAddress)public{
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        signerAddress = _signerAddress;
    }

    /**
     * @dev  设置奖券合约地址
     * @param _ticketContractAddress 新的奖券合约地址
     */
    function setTicketContractAddress(address _ticketContractAddress)public{
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        ticketContractAddress = _ticketContractAddress;
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
        require((_NFTNumber >0) && (_NFTNumber <= 1000),"The NFTNumber is invalid!" );
        EventInfoMap[_eventId].NFTNumber = _NFTNumber;
    }

    /**
     * @dev  暂停该场次
     * @param _eventId 场次ID
     */
    function stopEvent(uint256 _eventId)public{
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        EventInfoMap[_eventId].status = false;
    }

    /**
     * @dev  启动该场次
     * @param _eventId 场次ID
     */
    function startEvent(uint256 _eventId)public{
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        EventInfoMap[_eventId].status = true;
    }

    /**
     * @dev  全部抽奖
     * @param _eventId 场次ID
     * @param _payType 支付方式 1---eth支付；2---全用代金券支付；3---部分支付，优先使用代金券支付
     * @param hash 交易hash
     * @param signature 交易签名
     * @param nonce 交易随机数
     */
    function raffleAll(uint256 _eventId,uint256 _payType,bytes32 hash, bytes memory signature,string memory nonce)public payable{
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
    function raffle(uint256 _eventId,uint256 _amount,uint256 _payType,bytes32 hash, bytes memory signature,string memory nonce)public payable{
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
    function _raffle(uint256 _eventId,uint256 _amount,uint256 _payType,bytes32 hash, bytes memory signature,string memory nonce)internal {
        uint256 EventId = _eventId;
        string  memory Nonce = nonce;
        uint256 amount = _amount;
        //判断场次是否开启
        assert(EventInfoMap[EventId].status);
        //计算剩余的NFT数量
        uint256 subNFTNumber = EventInfoMap[EventId].NFTNumber.sub(EventInfoMap[EventId].purchasedNumber);
        //若_amount==0 则为全部抽奖
        if (amount == 0){
            amount = subNFTNumber;
        }
        //判断要参与抽奖的NFT数量是否合法
        require((amount > 0) && (amount <= subNFTNumber),"The amount of Raffle-NFT is insufficient!");
        //验证hash
        require(hashRaffleTransaction(EventId,msg.sender,amount,nonce,_payType) == hash,"Invalid hash!");
        //验证签名
        require(matchAddresSigner(hash,signature),"Invalid signature!");
        //计算参与抽奖的NFT总eth价值
        uint256 totalPrice = amount.mul(EventInfoMap[_eventId].ethPrice);
        //生成需铸造的TokenIdArray.
        uint256[] memory mintNftTokenIds = _getNftTokenIds(_eventId,amount);
        address NFTContractAddress;
        //判断是否已经设置了NFT合约地址
        //如果没有设置合约地址 则将全局
        //资产合约地址变量赋值给NFT地址。
        if (EventInfoMap[_eventId].NFTContractAddress == address(0)){
            NFTContractAddress = assetsContractAddress;
        }else{
            NFTContractAddress = EventInfoMap[_eventId].NFTContractAddress;
        }
        //判断支付方式 1---eth支付；2---全用代金券支付；3---部分支付，优先使用代金券支付
        if (_payType == 1){
            require(msg.value >= totalPrice,"The ether of be sent must be more than the totalprice!");
            require(_mintNft(mintNftTokenIds,1,NFTContractAddress),"NFT mint failed");
            payable(address(this)).transfer(totalPrice);
            if (msg.value > totalPrice){
                payable(msg.sender).transfer(msg.value - totalPrice);
            }
            emit Raffle(EventId,msg.sender,amount,0,1,mintNftTokenIds,Nonce);
        }else{
            //查询拥有的奖券
            Common1155NFT ticketContract = Common1155NFT(ticketContractAddress);
            //拥有的奖券数量
            uint256 ticketNumber = ticketContract.balanceOf(msg.sender,1);
            //若全部购买要消耗掉的奖券数量
            uint256 burnTicketNumber = totalPrice.div(ticketPrice);
            //用代金券支付
            if (_payType == 2){
                require(ticketNumber >= burnTicketNumber,"The tickets are insufficient!");
                require(_mintNft(mintNftTokenIds,1,NFTContractAddress),"NFT mint failed");
                ticketContract.burn(msg.sender,1,burnTicketNumber);
                emit Raffle(EventId,msg.sender,amount,burnTicketNumber,2,mintNftTokenIds,Nonce);
            }
            //混合支付
            if (_payType == 3){
                //优先使用代金券支付，当代金券可以完全支付时
                if (ticketNumber >= burnTicketNumber){
                    require(_mintNft(mintNftTokenIds,1,NFTContractAddress),"NFT mint failed");
                    ticketContract.burn(msg.sender,1,burnTicketNumber);
                    emit Raffle(EventId,msg.sender,amount,burnTicketNumber,3,mintNftTokenIds,Nonce);
                }else{
                    string memory _Nonce = Nonce;
                    uint256 _EventId = EventId;
                    //优先使用代金券支付，当代金券不足时，使用eth抵扣
                    //计算差额代金券
                    uint256 subTicketNumber = burnTicketNumber.sub(ticketNumber);
                    //计算扣除代金券需另支付的eth
                    uint256 subTicketAmount = subTicketNumber.mul(ticketPrice);
                    require(msg.value >= subTicketAmount,"The ether of be sent must be more than the subTicketAmount!");
                    require(_mintNft(mintNftTokenIds,1,NFTContractAddress),"NFT mint failed!");
                    ticketContract.burn(msg.sender,1,ticketNumber);
                    payable(address(this)).transfer(subTicketAmount);
                    if (msg.value > subTicketAmount){
                        payable(msg.sender).transfer(msg.value - subTicketAmount);
                    }
                    emit Raffle(_EventId,msg.sender,amount,burnTicketNumber,3,mintNftTokenIds,_Nonce);
                }
            }
        }
        //增加该场次的已购买的NFT数量
        EventInfoMap[EventId].purchasedNumber += amount;
    }

    /**
     * @dev  生成本场次要铸造的TokenIdsArray
     * @param _eventId 场次ID
     * @param _arrayLength 要铸造的TokenId数量
     * @return 将要铸造的TokenIdsArray
     */
    function _getNftTokenIds(uint256 _eventId,uint256 _arrayLength) internal view returns(uint256[] memory){
        uint256[] memory resultNftTokenIds = new uint256[](_arrayLength);
        uint256 startTokenId = EventInfoMap[_eventId].startTokenId.add(EventInfoMap[_eventId].purchasedNumber);
        for (uint256 i = 0; i < _arrayLength; i++) {
            resultNftTokenIds[i] = startTokenId + i;
        }
        return resultNftTokenIds;
    }

    /**
     * @dev  铸造nft内部封装方法
     * @param _mintNftTokenIds 将要铸造的TokenIdsArray
     * @param _mintAmount 每个id铸造的数量
     * @param _ContractAddress 铸造的合约地址
     * @return 是否铸造成功
     */
    //铸造NFT
    function _mintNft(uint256[] memory _mintNftTokenIds,uint256 _mintAmount,address _ContractAddress)internal  returns(bool) {
        if (_checkProtocol(_ContractAddress) == 1){
            Common1155NFT Common1155NFTContract = Common1155NFT(_ContractAddress);
            if (_mintNftTokenIds.length == 1){
                Common1155NFTContract.mint(msg.sender,_mintNftTokenIds[0],_mintAmount,abi.encode(msg.sender));
            }else{
                uint256[] memory amountArray = _generateAmountArray(_mintNftTokenIds.length);
                Common1155NFTContract.mintBatch(msg.sender,_mintNftTokenIds,amountArray,abi.encode(msg.sender));
            }
            return true;
        }
        if(_checkProtocol(_ContractAddress) == 2){
            Common721NFT Common721NFTContract = Common721NFT(_ContractAddress);
            for (uint256 i = 0; i < _mintNftTokenIds.length; i++) {
                Common721NFTContract.mint(msg.sender,_mintNftTokenIds[i]);
            }
            return true;
        }
        return false;
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
     * @param _withdrawNFTContractAddress 要被兑换的NFT合约地址
     * @param _withdrawNFTTokenID 要被兑换的NFT的TokenId
     * @param _withdrawNFTAddress 要被兑换的NFT钱包地址
     * @param hash 交易hash
     * @param signature 交易签名
     * @param nonce 交易随机数
     */
    function withdrawNFT(uint256 _tokenId,address _withdrawNFTContractAddress,uint256 _withdrawNFTTokenID,address _withdrawNFTAddress,bytes32 hash, bytes memory signature,string memory nonce)public{
        //验证hash
        require(hashWithdrawNFTTransaction(_tokenId,_withdrawNFTContractAddress,_withdrawNFTTokenID,_withdrawNFTAddress,msg.sender,nonce) == hash,"Invalid hash!");
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


     /**
     * @dev 兑换奖品为eth
     * @param _tokenId 奖品tokenId
     * @param _ETHAmount 想要兑换的eth数量
     * @param hash 交易hash
     * @param signature 账户签名
     * @param nonce 交易随机数
     */
    function convertNFT2ETH(uint256 _tokenId,uint256 _ETHAmount ,bytes32 hash, bytes memory signature,string memory nonce)public payable{
        //验证hash
        require(hashConvertNFTTransaction(_tokenId,msg.sender,_ETHAmount,nonce,"ETH") == hash,"Invalid hash!");
        //验证签名
        require(matchAddresSigner(hash,signature),"Invalid signature!");
        //验证是否拥有该资产NFT
        require(_validateOwnership(_tokenId),"You don't have this NFT!");
        payable(msg.sender).transfer(_ETHAmount);
        //销毁奖品
        require(_burnNFT(_tokenId),"burnNFT failed!");
        emit ConvertNFT(_tokenId,_ETHAmount,msg.sender,nonce,"ETH");
    }


    /**
     * @dev 批量兑换奖品为eth
     * @param _tokenIdArray 奖品tokenId数组
     * @param _ETHAmount 想要兑换的eth数量
     * @param hash 交易hash
     * @param signature 交易签名
     * @param nonce 交易随机数
     */
    function bathConvertNFT2ETH(uint256[] memory _tokenIdArray,uint256 _ETHAmount ,bytes32 hash, bytes memory signature,string memory nonce)public payable{
        //验证hash
        require(hashBathConvertNFTsTransaction(_tokenIdArray,msg.sender,_ETHAmount,nonce,"ETH") == hash,"Invalid hash!");
        //验证签名
        require(matchAddresSigner(hash,signature),"Invalid signature!");
        //验证是否拥有该资产NFT
        require(_bathValidateOwnership(_tokenIdArray),"You don't have these NFT!");
        //        require(_ETHAmount >= ticketPrice);
        payable(msg.sender).transfer(_ETHAmount);
        //销毁奖品
        require(_bathBurnNFT(_tokenIdArray),"burnNFT failed!");
        emit BathConvertNFT(_ETHAmount,msg.sender,"ETH",_tokenIdArray,nonce);
    }


    /**
     * @dev 兑换奖品成奖券
     * @param _tokenId 奖品tokenId
     * @param _ticketAmount 想要兑换的奖券数量
     * @param hash 交易hash
     * @param signature 账户签名
     * @param nonce 交易随机数
     */
    function convertNFT2Ticket(uint256 _tokenId,uint256 _ticketAmount ,bytes32 hash, bytes memory signature,string memory nonce)public{
        //验证hash
        require(hashConvertNFTTransaction(_tokenId,msg.sender,_ticketAmount,nonce,"Ticket") == hash,"Invalid hash!");
        //验证签名
        require(matchAddresSigner(hash,signature),"Invalid signature!");
        //验证是否拥有该资产NFT
        require(_validateOwnership(_tokenId),"You don't have this NFT!");
//        //查询要抵押的tokenId的eth价格
//        uint256 tokenPrice = EventInfoMap[_tokenId.div(eventTokenIdRange)].ethPrice;
//        //查询可以兑换的奖券数量
//        uint256 _token1Number = tokenPrice.div(ticketPrice);
//        require(_token1Number >= _token1Amount);
        uint256[] memory  a = new uint256[](1);
        a[0] = 1;
        //铸造奖券
        _mintNft(a,_ticketAmount,ticketContractAddress);
        //销毁奖品
        require(_burnNFT(_tokenId),"burnNFT failed!");
        emit ConvertNFT(_tokenId,_ticketAmount,msg.sender,nonce,"Ticket");
    }


    /**
     * @dev 批量兑换奖品成奖券
     * @param _tokenIdArray 奖品tokenId数组
     * @param _ticketAmount 想要兑换的奖券数量
     * @param hash 交易hash
     * @param signature 账户签名
     * @param nonce 交易随机数
     */
    function bathConvertNFT2Ticket(uint256[] memory _tokenIdArray,uint256 _ticketAmount ,bytes32 hash, bytes memory signature,string memory nonce)public{
        //验证hash
        require(hashBathConvertNFTsTransaction(_tokenIdArray,msg.sender,_ticketAmount,nonce,"Ticket") == hash,"Invalid hash!");
        //验证签名
        require(matchAddresSigner(hash,signature),"Invalid signature!");
        //批量验证是否拥有该资产NFT
        require(_bathValidateOwnership(_tokenIdArray),"You don't have these NFT!");
        //批量铸造
        _mintNft(_generateAmountArray(_tokenIdArray.length),_ticketAmount,ticketContractAddress);
        //销毁奖品
        require(_bathBurnNFT(_tokenIdArray),"burnNFT failed!");
        emit BathConvertNFT(_ticketAmount,msg.sender,"Ticket",_tokenIdArray,nonce);
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
     * @dev 批量验证函数调用者是否拥有该奖品的内部封装方法
     * @param _tokenIdArray 奖品tokenId数组
     * @return 是否拥有
     */
    function _bathValidateOwnership(uint256[] memory _tokenIdArray)internal view returns(bool){
        IERC1155 Common1155NFTContract = IERC1155(assetsContractAddress);
        for (uint256 i = 0; i < _tokenIdArray.length; i++) {
            require(Common1155NFTContract.balanceOf(msg.sender,_tokenIdArray[i]) >0);
        }
        return true;
    }



    /**
     * @dev 要销毁的资产NFT内部封装方法
     * @param _tokenId 要销毁的tokenId
     * @return 是否销毁成功
     */
    function _burnNFT(uint256 _tokenId)internal returns(bool){
        Common1155NFT Common1155NFTContract = Common1155NFT(assetsContractAddress);
        Common1155NFTContract.burn(msg.sender,_tokenId,1);
        return true;
    }



    function _bathBurnNFT(uint256[] memory _tokenIdArray)internal returns (bool){
        Common1155NFT Common1155NFTContract = Common1155NFT(assetsContractAddress);
        uint256[] memory burnNFTAmountArray = _generateAmountArray(_tokenIdArray.length);
        Common1155NFTContract.burnBatch(msg.sender,_tokenIdArray,burnNFTAmountArray);
        return true;
    }

    /**
     * @dev 生成购买交易的hash值
     * @param _eventId 场次ID
     * @param sender 交易触发者
     * @param qty 交易数量
     * @param nonce 交易随机数
     * @param _payType 支付方式
     * @return 交易的hash值
     */
    function hashRaffleTransaction(uint256 _eventId,address sender, uint256 qty, string memory nonce,uint256 _payType) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(_eventId,sender,qty,nonce,_payType))
            )
        );
        return hash;
    }

    /**
     * @dev 生成提现兑换NFT交易hash
     * @param _tokenId 被兑换的奖品TokenId
     * @param _withdrawNFTContractAddress 要被兑换的NFT合约地址
     * @param _withdrawNFTTokenID 要被兑换的NFT的TokenId
     * @param _withdrawNFTAddress 要被兑换的NFT提现的钱包地址
     * @param sender 交易触发者
     * @param nonce 交易随机数
     * @return 交易的hash值
     */
    function hashWithdrawNFTTransaction(uint256 _tokenId,address _withdrawNFTContractAddress,uint256 _withdrawNFTTokenID,address _withdrawNFTAddress,address sender, string memory nonce) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(_tokenId,_withdrawNFTContractAddress,_withdrawNFTTokenID,_withdrawNFTAddress,sender,nonce))
            )
        );
        return hash;
    }

    /**
     * @dev 生成抵押NFT交易的hash值
     * @param tokenId 要被抵押的奖品tokenId
     * @param sender 交易触发者
     * @param qty 交易数量
     * @param nonce 交易随机数
     * @param convertType 抵押类型
     * @return 交易的hash值
     */
    function hashConvertNFTTransaction(uint256 tokenId,address sender, uint256 qty, string memory nonce,string memory convertType) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(tokenId,sender,qty,nonce,convertType))
            )
        );
        return hash;
    }

    /**
     * @dev 生成批量抵押NFT交易的hash值
     * @param tokenIdArray 要被抵押的奖品tokenId数组
     * @param sender 交易触发者
     * @param qty 交易数量
     * @param nonce 交易随机数
     * @param convertType 抵押类型
     * @return 交易的hash值
     */
    function hashBathConvertNFTsTransaction(uint256[] memory tokenIdArray,address sender, uint256 qty, string memory nonce,string memory convertType) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encode(tokenIdArray,sender, qty, nonce,convertType))
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
        return signerAddress == recoverSigner(hash,signature);
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
        payable(address(_toAddress)).transfer(_amount);
    }

    /**
     * @dev  提现eth
     */
    function withdraw() public  payable {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        uint256 withdrawETH = address(this).balance -  0.01 ether;
        payable(msg.sender).transfer(withdrawETH);
    }

    function recoverSigner(bytes32 _ethSignedMessageHash, bytes memory _signature) public pure returns (address){
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        return ecrecover(_ethSignedMessageHash, v, r, s);
    }

    function splitSignature(bytes memory sig) public pure returns (bytes32 r, bytes32 s, uint8 v){
        require(sig.length == 65, "invalid signature length");

        assembly {
        /*
        First 32 bytes stores the length of the signature

        add(sig, 32) = pointer of sig + 32
        effectively, skips first 32 bytes of signature

        mload(p) loads next 32 bytes starting at the memory address p into memory
        */

        // first 32 bytes, after the length prefix
            r := mload(add(sig, 32))
        // second 32 bytes
            s := mload(add(sig, 64))
        // final byte (first byte of the next 32 bytes)
            v := byte(0, mload(add(sig, 96)))
        }

        // implicitly return (r, s, v)
    }

}