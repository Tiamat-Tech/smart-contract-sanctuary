// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";


contract RedEnvelope {

    // 开红包奖励冰墩墩
    uint256 private immutable BONUS_DWEN = 6;
    // 打开过期红包需要花费冰墩墩
    uint256 private immutable LUCKY_DRAW_DWEN = 15;

    // 红包编号
    uint256 public counter = 0;

    // 冰墩墩的地址
    address public bingDwenDwenCoinAddr;

    struct RedEnvelopeInfo {
        // 红包创建者
        address creator;
        // token地址
        address tokenAddr;
        // 红包余额
        uint256 amount;
        // 红包数量
        uint256 number;
        // 创建时间
        uint256 createDt;
        // 过期时间
        uint256 expireDt;
        // 红包是否公开
        bool isPublic;
        // 白名单 merkleRoot
        bytes32 merkleRoot;
        // 地址打开红包的金额
        mapping(address => uint256) recipientInfos;
        // 过期红包领取信息
        mapping(address => uint256) luckydrawInfos;
    }

    // 红包详情
    mapping(uint256 => RedEnvelopeInfo) public redEnvelopInfos;

    // 初始化一次
    function initBonusCoin(address tokenAddr) external {
        require(bingDwenDwenCoinAddr == address(0),"Already Initialized");
        bingDwenDwenCoinAddr = tokenAddr;
    }

    // 新建红包事件
    event Create(uint256 envelopeId, uint exprTime);
    // 打开红包事件
    event Open(uint256 envelopeId, uint256 amount);
    // 打开过期红包事件
    event LuckyDraw(uint256 envelopId, uint256 amount);
    // 回撤红包事件
    event DrawBack(uint256 envelopId, uint256 amount);

    modifier NonContract() {
        require(tx.origin == msg.sender, "XRC: contract is not allowed to mint.");
        _;
    }

    function create(address tokenAddr, uint256 amount,uint256 number, uint256 expireDt,bytes32 merkleRoot) external NonContract payable returns (uint256){
        require(amount > 0 ,"Invalid amount");
        require(number > 0 ,"Invalid number");
        // 红包编号+1
        uint256 envelopId = counter = counter + 1;

        // 保存红包详细信息
        RedEnvelopeInfo storage r = redEnvelopInfos[envelopId];
        r.amount = amount;
        r.number = number;
        r.createDt = block.timestamp;
        r.creator = msg.sender;
        r.expireDt = expireDt;
        r.tokenAddr = tokenAddr;
        r.merkleRoot = merkleRoot;
        r.isPublic = false;

        if(merkleRoot.length == 0) {
            r.isPublic = true;
        }
        if (tokenAddr != address(0)){
            IERC20 token = IERC20(tokenAddr);
            // 是否授权足够数量
            require(token.allowance(msg.sender, address(this)) >= amount,"Token allowance fail");
            // 检查是否可以成功将该token转到红包合约下
            require(token.transferFrom(msg.sender, address(this), amount),"Token transfer fail");
        }else {
            require(amount <= msg.value,"Insufficient BNB");
        }
        emit Create(envelopId, r.expireDt);

        return envelopId;
    }

    function open(uint256 redEnvelopId,bytes32[] memory proof) external NonContract {
        RedEnvelopeInfo storage red =  redEnvelopInfos[redEnvelopId];
        require(red.creator != address(0),"Invalid ID");
        require(red.number > 0,"No share left");
        require(red.recipientInfos[msg.sender] == 0,"Already opened");

        if(!red.isPublic){
            // 判断用户是否可以开启红包
            require(MerkleProof.verify(proof, red.merkleRoot, keccak256(abi.encodePacked(msg.sender))),"Invalid proof");
        }

        // 开启红包的随机数
        uint256 amount = _calculateRandomAmount(red.amount,red.number);
        // 用户得到
        red.recipientInfos[msg.sender] = amount;
        // 剩余金额
        red.amount = red.amount - amount;
        // 剩余数量
        red.number = red.number - 1;
        // 将token转给开红包的用户
        _send(red.tokenAddr, payable(msg.sender),amount);

        // 给创建红包和领红包的人发送Dwencoin
        if(IERC20(bingDwenDwenCoinAddr).balanceOf(address(this)) >= BONUS_DWEN + (BONUS_DWEN / 2)){
            require(IERC20(bingDwenDwenCoinAddr).transfer(msg.sender, BONUS_DWEN / 2),"Transfer DWEN failed");
            require(IERC20(bingDwenDwenCoinAddr).transfer(red.creator, BONUS_DWEN),"Transfer DWEN failed");
        }
        // 打开红包事件
        emit Open(redEnvelopId,amount);
    }

    function luckyDraw(uint256 redEnvelopId,bytes32[] memory proof) external NonContract {
        RedEnvelopeInfo storage red =  redEnvelopInfos[redEnvelopId];
        require(red.creator != address(0),"Invalid ID");
        require(block.timestamp > red.expireDt,"Not expired");
        require(red.number > 0,"No share left");
        require(red.luckydrawInfos[msg.sender] == 0,"Already opened");

        if(!red.isPublic){
            // 判断用户是否可以开启红包
            require(MerkleProof.verify(proof, red.merkleRoot, keccak256(abi.encodePacked(msg.sender))),"Invalid proof");
        }
        // 需要支付DWEN
        require(IERC20(bingDwenDwenCoinAddr).balanceOf(msg.sender) >= LUCKY_DRAW_DWEN, "need more DWEN coins");
        // 是否授权足够数量
        require(IERC20(bingDwenDwenCoinAddr).allowance(msg.sender, address(this)) >= LUCKY_DRAW_DWEN,"DWEN allowance fail");
        // 检查是否可以成功将该token转到红包合约下
        require(IERC20(bingDwenDwenCoinAddr).transferFrom(msg.sender, address(this), LUCKY_DRAW_DWEN),"DWEN transfer fail");

        // 开启红包的随机数
        uint256 amount = red.amount;
        // 用户得到
        red.luckydrawInfos[msg.sender] = amount;
        // 剩余金额
        red.amount = 0;
        // 剩余数量
        red.number = 0;
        // 将token转给开红包的用户
        _send(red.tokenAddr, payable(msg.sender),amount);

        // 给创建红包和领红包的人发送Dwencoin
        if(IERC20(bingDwenDwenCoinAddr).balanceOf(address(this)) >= BONUS_DWEN + (BONUS_DWEN / 2)){
            require(IERC20(bingDwenDwenCoinAddr).transfer(msg.sender, BONUS_DWEN / 2),"Transfer DWEN failed");
            require(IERC20(bingDwenDwenCoinAddr).transfer(red.creator, BONUS_DWEN),"Transfer DWEN failed");
        }
        emit LuckyDraw(redEnvelopId,amount);
    }

    function drawBack(uint256 redEnvelopId) external NonContract {
        RedEnvelopeInfo storage red =  redEnvelopInfos[redEnvelopId];
        require(red.creator != address(0),"Invalid ID");
        require(block.timestamp > red.expireDt,"Not expired");
        require(red.creator == msg.sender,"Not creator");
        require(red.amount > 0,"No money left");
        // 开启红包的随机数
        uint256 amount = red.amount;
        // 剩余金额
        red.amount = 0;
        // 剩余数量
        red.number = 0;
        // 将token退回
        _send(red.tokenAddr, payable(msg.sender),amount);
        emit DrawBack(redEnvelopId,amount);
    }

    function info(uint256 redEnvelopId) external view returns (address, address, uint256, uint256, bool, uint) {
        RedEnvelopeInfo storage redEnvelopInfo = redEnvelopInfos[redEnvelopId];
        return (
        redEnvelopInfo.creator,
        redEnvelopInfo.tokenAddr,
        redEnvelopInfo.amount,
        redEnvelopInfo.number,
        redEnvelopInfo.isPublic,
        redEnvelopInfo.expireDt);
    }

    function record(uint256 redEnvelopId, address candidate,bytes32[] memory proof) external view returns (bool, uint256, uint256) {
        return (
        MerkleProof.verify(proof, redEnvelopInfos[redEnvelopId].merkleRoot, keccak256(abi.encodePacked(candidate))),
        redEnvelopInfos[redEnvelopId].recipientInfos[candidate],
        redEnvelopInfos[redEnvelopId].luckydrawInfos[candidate]
        );
    }

    function _send(address tokenAddr, address payable to, uint256 amount) private {
        if (tokenAddr == address(0)) {
            // 如果是BNB或者ETH，直接发送
            require(to.send(amount), "Transfer BNB failed");
        } else {
            // 如果是其他ERC20代币，则调用ERC20的transfer方法发送
            require(IERC20(tokenAddr).transfer(to, amount), "Transfer Token failed");
        }
    }

    function _calculateRandomAmount(uint256 _amount, uint _number) private view returns (uint256) {
        uint256 amount = 0;
        if (_number == 1) {
            // 如果剩余份数只剩一份，那剩下的token全给该用户
            amount = _amount;
        } else if (_amount == _number) {
            // 如果剩余份数=剩余的token数量，那每个人只能分到1个token
            amount = 1;
        } else if (_number < _amount) {
            // 其他情况用_random函数计算随机数
            amount = _random(_amount, _number);
        }
        return amount;
    }

    // 计算随机数算法（参考微信红包）
    function _random(uint256 _amount, uint _number) private view returns (uint256) {
        // 用了区块的时间戳，难度和高度做随机数的seed
        // 随机数算法参考微信红包，随机金额取值范围为1到平均能分到token数量的2倍
        return uint256(keccak256(abi.encode(block.timestamp + block.difficulty + block.number + uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp)))%8))) % (_amount / _number * 2) + 1;
    }

}