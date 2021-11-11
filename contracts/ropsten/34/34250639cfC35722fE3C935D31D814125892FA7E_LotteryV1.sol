// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
//import "@openzeppelin/contracts/utils/Address.sol";

interface Common1155NFT {
    function mint(address account, uint256 id, uint256 amount, bytes memory data) external;
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external;
    function burn(address account, uint256 id, uint256 amount) external;
    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) external;
    function balanceOf(address account, uint256 id) external view returns (uint256);
    function dissolve(address account, uint256 id, uint256 value) external;
    function dissolveBatch(address account, uint256[] memory ids, uint256[] memory values) external;
}

interface Common721NFT {
    function mint(address account, uint256 id) external;
    function exists(uint256 tokenId) external view returns (bool);
    function burn(uint256 tokenId) external;
    function balanceOf(address owner) external returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract LotteryV1 is AccessControl, Pausable {

    /* Variable */
    using SafeMath for uint256;
    uint256 internal eventId = 1;
    address internal signerAddress;//签名钱包地址
    address internal assetsContractAddress;//资产合约地址
    address internal ticketContractAddress;//奖券合约地址
    uint256 internal ticketPrice = 10000000000000000;//奖券价格
    uint256 internal eventTokenIdRange;//场次TokenId范围
    mapping(uint256 => EventInfo) internal EventInfoMap;
    bytes32 public constant EVENT_CREATE_ROLE = keccak256("EVENT_CREATE_ROLE");
    bytes32 public constant ETH_TRANSFER_ROLE = keccak256("ETH_TRANSFER_ROLE");


    //Interface Signature ERC1155 and ERC721
    bytes4 constant private INTERFACE_SIGNATURE_ERC1155 = 0xd9b67a26;
    bytes4 constant private INTERFACE_SIGNATURE_ERC721 = 0x80ac58cd;

    constructor (uint256 _eventTokenIdRange, address _assetsContractAddress, address _ticketContractAddress){
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(EVENT_CREATE_ROLE, msg.sender);
        _setupRole(ETH_TRANSFER_ROLE, msg.sender);
        assetsContractAddress = _assetsContractAddress;
        ticketContractAddress = _ticketContractAddress;
        eventTokenIdRange = _eventTokenIdRange;
        signerAddress = msg.sender;
    }

    struct EventInfo {
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
    event Raffle(uint256 indexed eventId, address indexed buyer, uint256 indexed amount, uint256 ticketNumber, uint256 payType, uint256[] nftTokenIds, string nonce);
    event WithdrawNFT(uint256 indexed _tokenId, address indexed _withdrawNFTContractAddress, uint256 indexed _withdrawNFTTokenID, address _withdrawNFTAddress, address _withdrawNFT2Address, string nonce);
    event WithdrawNFTByMint(uint256 indexed _tokenId, address indexed _withdrawNFTContractAddress, uint256 indexed _withdrawNFTTokenID, address _mintNFTAddress, string nonce);
    event BatchConvertNFT(uint256 indexed _amount, address indexed _from, string indexed _convertType, uint256[] _tokenIds, string nonce);
    event ConvertNFT(uint256 indexed _tokenId, uint256 indexed _amount, address indexed _from, string nonce, string _convertType);

    //Fallback function
    fallback() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }

    //Receive function
    receive() external payable {
        // TODO implementation the receive function
    }

    function createEvent(uint256 _ethPrice, uint256 _ticketNumber, uint256 _NFTNumber, address _NFTContractAddress) public {
        //鉴权
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        //判断要设置的NFTNumber是否合法，max--1000
        require((_NFTNumber > 0) && (_NFTNumber <= 1000), "The NFTNumber is invalid!");
        //记录本场次的详细信息
        EventInfoMap[eventId].ethPrice = _ethPrice;
        EventInfoMap[eventId].NFTNumber = _NFTNumber;
        //判断奖券数量是否为0
        if (_ticketNumber == 0) {
            EventInfoMap[eventId].ticketNumber = _ethPrice.div(ticketPrice);
        } else {
            EventInfoMap[eventId].ticketNumber = _ticketNumber;
        }
        EventInfoMap[eventId].NFTContractAddress = _NFTContractAddress;
        //场次默认关闭
        EventInfoMap[eventId].status = false;
        EventInfoMap[eventId].startTokenId = eventId.mul(eventTokenIdRange);
        //场次自增
        eventId ++;
    }

    function setAssetsContractAddress(address _assetsContractAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        assetsContractAddress = _assetsContractAddress;
    }

    function setNFTContractAddress(uint256 _eventId, address _NFTContractAddress) public {
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        EventInfoMap[_eventId].NFTContractAddress = _NFTContractAddress;
    }

    function setSignerAddress(address _signerAddress) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        signerAddress = _signerAddress;
    }


    function setTicketContractAddress(address _ticketContractAddress) public {
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        ticketContractAddress = _ticketContractAddress;
    }

    function setTicketPrice(uint256 _ticketPrice) public {
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        ticketPrice = _ticketPrice;
    }


    function setTicketNumber(uint256 _eventId, uint256 _ticketNumber) public {
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        EventInfoMap[_eventId].ticketNumber = _ticketNumber;
    }


    function setEthPrice(uint256 _eventId, uint256 _ethPrice) public {
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        EventInfoMap[_eventId].ethPrice = _ethPrice;
    }

    function setNFTNumber(uint256 _eventId, uint256 _NFTNumber) public {
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        require((_NFTNumber > 0) && (_NFTNumber <= 1000), "The NFTNumber is invalid!");
        EventInfoMap[_eventId].NFTNumber = _NFTNumber;
    }


    function stopEvent(uint256 _eventId) public {
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        EventInfoMap[_eventId].status = false;
    }


    function startEvent(uint256 _eventId) public {
        require(hasRole(EVENT_CREATE_ROLE, msg.sender));
        EventInfoMap[_eventId].status = true;
    }


    function raffleAll(uint256 _eventId, uint256 _payType, bytes32 hash, bytes memory signature, string memory nonce) public payable whenNotPaused {
        _raffle(_eventId, 0, _payType, hash, signature, nonce);
    }


    function raffle(uint256 _eventId, uint256 _amount, uint256 _payType, bytes32 hash, bytes memory signature, string memory nonce) public payable whenNotPaused {
        _raffle(_eventId, _amount, _payType, hash, signature, nonce);
    }

    function _raffle(uint256 _eventId, uint256 _amount, uint256 _payType, bytes32 hash, bytes memory signature, string memory nonce) internal {
        uint256 EventId = _eventId;
        string  memory Nonce = nonce;
        uint256 amount = _amount;
        //判断场次是否开启
        assert(EventInfoMap[EventId].status);
        //计算剩余的NFT数量
        uint256 subNFTNumber = EventInfoMap[EventId].NFTNumber.sub(EventInfoMap[EventId].purchasedNumber);
        //若_amount==0 则为全部抽奖
        if (amount == 0) {
            amount = subNFTNumber;
        }
        //判断要参与抽奖的NFT数量是否合法
        require((amount > 0) && (amount <= subNFTNumber), "The amount of Raffle-NFT is insufficient!");
        //验证hash
        require(hashRaffleTransaction(EventId, msg.sender, amount, nonce, _payType) == hash, "Invalid hash!");
        //验证签名
        require(matchAddressSigner(hash, signature), "Invalid signature!");
        //计算参与抽奖的NFT总eth价值
        uint256 totalPrice = amount.mul(EventInfoMap[_eventId].ethPrice);
        //生成需铸造的TokenIdArray.
        uint256[] memory mintNftTokenIds = _getNftTokenIds(_eventId, amount);
        address NFTContractAddress;
        //判断是否已经设置了NFT合约地址
        //如果没有设置合约地址 则将全局
        //资产合约地址变量赋值给NFT地址。
        if (EventInfoMap[_eventId].NFTContractAddress == address(0)) {
            NFTContractAddress = assetsContractAddress;
        } else {
            NFTContractAddress = EventInfoMap[_eventId].NFTContractAddress;
        }
        //判断支付方式 1---eth支付；2---全用代金券支付；3---部分支付，优先使用代金券支付
        if (_payType == 1) {
            require(msg.value >= totalPrice, "The ether of be sent must be more than the totalprice!");
            require(_mintNft(mintNftTokenIds, 1, NFTContractAddress), "NFT mint failed");
            payable(address(this)).transfer(totalPrice);
            if (msg.value > totalPrice) {
                payable(msg.sender).transfer(msg.value - totalPrice);
            }
            emit Raffle(EventId, msg.sender, amount, 0, 1, mintNftTokenIds, Nonce);
        } else {
            //查询拥有的奖券
            Common1155NFT ticketContract = Common1155NFT(ticketContractAddress);
            //拥有的奖券数量
            uint256 ticketNumber = ticketContract.balanceOf(msg.sender, 1);
            //若全部购买要消耗掉的奖券数量
            uint256 burnTicketNumber = amount.mul(EventInfoMap[EventId].ticketNumber);
            //用代金券支付
            if (_payType == 2) {
                require(ticketNumber >= burnTicketNumber, "The tickets are insufficient!");
                require(_mintNft(mintNftTokenIds, 1, NFTContractAddress), "NFT mint failed");
                _burnNFT(ticketContractAddress, 1, burnTicketNumber);
                emit Raffle(EventId, msg.sender, amount, burnTicketNumber, 2, mintNftTokenIds, Nonce);
            }
            //混合支付
            if (_payType == 3) {
                //优先使用代金券支付，当代金券可以完全支付时
                if (ticketNumber >= burnTicketNumber) {
                    require(_mintNft(mintNftTokenIds, 1, NFTContractAddress), "NFT mint failed");
                    ticketContract.burn(msg.sender, 1, burnTicketNumber);
                    emit Raffle(EventId, msg.sender, amount, burnTicketNumber, 3, mintNftTokenIds, Nonce);
                } else {
                    string memory _Nonce = Nonce;
                    uint256 _EventId = EventId;
                    //优先使用代金券支付，当代金券不足时，使用eth抵扣
                    //计算差额代金券
                    uint256 subTicketNumber = burnTicketNumber.sub(ticketNumber);
                    //计算扣除代金券需另支付的eth
                    uint256 subTicketAmount = subTicketNumber.mul(ticketPrice);
                    require(msg.value >= subTicketAmount, "The ether of be sent must be more than the subTicketAmount!");
                    require(_mintNft(mintNftTokenIds, 1, NFTContractAddress), "NFT mint failed!");
                    require(_burnNFT(ticketContractAddress, 1, ticketNumber), "burnNFT failed!");
                    payable(address(this)).transfer(subTicketAmount);
                    if (msg.value > subTicketAmount) {
                        payable(msg.sender).transfer(msg.value - subTicketAmount);
                    }
                    emit Raffle(_EventId, msg.sender, amount, burnTicketNumber, 3, mintNftTokenIds, _Nonce);
                }
            }
        }
        //增加该场次的已购买的NFT数量
        EventInfoMap[EventId].purchasedNumber += amount;
    }

    function _getNftTokenIds(uint256 _eventId, uint256 _arrayLength) internal view returns (uint256[] memory){
        uint256[] memory resultNftTokenIds = new uint256[](_arrayLength);
        uint256 startTokenId = EventInfoMap[_eventId].startTokenId.add(EventInfoMap[_eventId].purchasedNumber);
        for (uint256 i = 0; i < _arrayLength; i++) {
            resultNftTokenIds[i] = startTokenId + i;
        }
        return resultNftTokenIds;
    }


    //铸造NFT
    function _mintNft(uint256[] memory _mintNftTokenIds, uint256 _mintAmount, address _ContractAddress) internal returns (bool) {
        if (_checkProtocol(_ContractAddress) == 1) {
            Common1155NFT Common1155NFTContract = Common1155NFT(_ContractAddress);
            if (_mintNftTokenIds.length == 1) {
                Common1155NFTContract.mint(msg.sender, _mintNftTokenIds[0], _mintAmount, abi.encode(msg.sender));
            } else {
                uint256[] memory amountArray = _generateAmountArray(_mintNftTokenIds.length);
                Common1155NFTContract.mintBatch(msg.sender, _mintNftTokenIds, amountArray, abi.encode(msg.sender));
            }
            return true;
        }
        if (_checkProtocol(_ContractAddress) == 2) {
            Common721NFT Common721NFTContract = Common721NFT(_ContractAddress);
            for (uint256 i = 0; i < _mintNftTokenIds.length; i++) {
                Common721NFTContract.mint(msg.sender, _mintNftTokenIds[i]);
            }
            return true;
        }
        return false;
    }

    function _generateAmountArray(uint256 _arrayLength) internal pure returns (uint256 [] memory){
        uint256[] memory amountArray = new uint256[](_arrayLength);
        for (uint256 i = 0; i < _arrayLength; i++) {
            amountArray[i] = 1;
        }
        return amountArray;
    }


    function withdrawNFT(uint256 _tokenId, address _withdrawNFTContractAddress, uint256 _withdrawNFTTokenID, address _withdrawNFTAddress, bytes32 hash, bytes memory signature, string memory nonce) public whenNotPaused {
        //验证hash
        require(hashWithdrawNFTTransaction(_tokenId, _withdrawNFTContractAddress, _withdrawNFTTokenID, _withdrawNFTAddress, msg.sender, nonce) == hash, "Invalid hash!");
        //验证签名
        require(matchAddressSigner(hash, signature), "Invalid signature!");
        //验证是否拥有该资产NFT
        require(_validateOwnership(_tokenId), "You don't have this NFT!");
        //转移NFT
        if (_checkProtocol(_withdrawNFTContractAddress) == 1) {
            ERC1155 withdrawNFTContract = ERC1155(_withdrawNFTContractAddress);
            withdrawNFTContract.safeTransferFrom(_withdrawNFTAddress, msg.sender, _withdrawNFTTokenID, 1, abi.encode(msg.sender));
            require(_burnNFT(assetsContractAddress, _tokenId, 1));
            emit WithdrawNFT(_tokenId, _withdrawNFTContractAddress, _withdrawNFTTokenID, _withdrawNFTAddress, msg.sender, nonce);
        }
        if (_checkProtocol(_withdrawNFTContractAddress) == 2) {
            ERC721 withdrawNFTContract = ERC721(_withdrawNFTContractAddress);
            withdrawNFTContract.safeTransferFrom(_withdrawNFTAddress, msg.sender, _withdrawNFTTokenID);
            require(_burnNFT(assetsContractAddress, _tokenId, 1));
            emit WithdrawNFT(_tokenId, _withdrawNFTContractAddress, _withdrawNFTTokenID, _withdrawNFTAddress, msg.sender, nonce);
        }
    }


    function withdrawMintNFT(uint256 _tokenId, address _withdrawNFTContractAddress, uint256 _withdrawNFTTokenID, bytes32 hash, bytes memory signature, string memory nonce, address _creatorAddress) public whenNotPaused {
        //验证hash
        require(hashWithdrawNFTByMintTransaction(_tokenId, _withdrawNFTContractAddress, _withdrawNFTTokenID, msg.sender, nonce, _creatorAddress) == hash, "Invalid hash!");
        //验证签名
        require(matchAddressSigner(hash, signature), "Invalid signature!");
        //验证是否拥有该资产NFT
        require(_validateOwnership(_tokenId), "You don't have this NFT!");
        //转移NFT
        if (_checkProtocol(_withdrawNFTContractAddress) == 1) {
            Common1155NFT withdrawNFTContract = Common1155NFT(_withdrawNFTContractAddress);
            //            assert(withdrawNFTContract.balanceOf(msg.sender,_withdrawNFTTokenID) >0);
            withdrawNFTContract.mint(msg.sender, _withdrawNFTTokenID, 1, abi.encode(_creatorAddress));
            require(_burnNFT(assetsContractAddress, _tokenId, 1));
            emit WithdrawNFTByMint(_tokenId, _withdrawNFTContractAddress, _withdrawNFTTokenID, msg.sender, nonce);
        }
        if (_checkProtocol(_withdrawNFTContractAddress) == 2) {
            Common721NFT withdrawNFTContract = Common721NFT(_withdrawNFTContractAddress);
            //            assert(withdrawNFTContract.ownerOf(_withdrawNFTTokenID) != msg.sender);
            withdrawNFTContract.mint(msg.sender, _withdrawNFTTokenID);
            require(_burnNFT(assetsContractAddress, _tokenId, 1));
            emit WithdrawNFTByMint(_tokenId, _withdrawNFTContractAddress, _withdrawNFTTokenID, msg.sender, nonce);
        }
    }


    function _checkProtocol(address _contractAddress) internal view returns (uint256){
        IERC165 Contract = IERC165(_contractAddress);
        if (Contract.supportsInterface(INTERFACE_SIGNATURE_ERC1155)) {
            //1---ERC1155
            return 1;
        }
        if (Contract.supportsInterface(INTERFACE_SIGNATURE_ERC721)) {
            //2---ERC721
            return 2;
        }
        revert("Invalid contract protocol!");
    }


    function convertNFT2ETH(uint256 _tokenId, uint256 _ETHAmount, bytes32 hash, bytes memory signature, string memory nonce) public payable whenNotPaused {
        //验证hash
        require(hashConvertNFTTransaction(_tokenId, msg.sender, _ETHAmount, nonce, "ETH") == hash, "Invalid hash!");
        //验证签名
        require(matchAddressSigner(hash, signature), "Invalid signature!");
        //验证是否拥有该资产NFT
        require(_validateOwnership(_tokenId), "You don't have this NFT!");
        payable(msg.sender).transfer(_ETHAmount);
        //销毁奖品
        require(_burnNFT(assetsContractAddress, _tokenId, 1), "burnNFT failed!");
        emit ConvertNFT(_tokenId, _ETHAmount, msg.sender, nonce, "ETH");
    }


    function batchConvertNFT2ETH(uint256[] memory _tokenIdArray, uint256 _ETHAmount, bytes32 hash, bytes memory signature, string memory nonce) public payable whenNotPaused {
        //验证hash
        require(hashBatchConvertNFTsTransaction(_tokenIdArray, msg.sender, _ETHAmount, nonce, "ETH") == hash, "Invalid hash!");
        //验证签名
        require(matchAddressSigner(hash, signature), "Invalid signature!");
        //验证是否拥有该资产NFT
        require(_batchValidateOwnership(_tokenIdArray), "You don't have these NFT!");
        payable(msg.sender).transfer(_ETHAmount);
        //销毁奖品
        require(_batchBurnNFT(_tokenIdArray), "burnNFT failed!");
        emit BatchConvertNFT(_ETHAmount, msg.sender, "ETH", _tokenIdArray, nonce);
    }


    function convertNFT2Ticket(uint256 _tokenId, uint256 _ticketAmount, bytes32 hash, bytes memory signature, string memory nonce) public whenNotPaused {
        //验证hash
        require(hashConvertNFTTransaction(_tokenId, msg.sender, _ticketAmount, nonce, "Ticket") == hash, "Invalid hash!");
        //验证签名
        require(matchAddressSigner(hash, signature), "Invalid signature!");
        //验证是否拥有该资产NFT
        require(_validateOwnership(_tokenId), "You don't have this NFT!");
        uint256[] memory a = new uint256[](1);
        a[0] = 1;
        //铸造奖券
        _mintNft(a, _ticketAmount, ticketContractAddress);
        //销毁奖品
        require(_burnNFT(assetsContractAddress, _tokenId, 1), "burnNFT failed!");
        emit ConvertNFT(_tokenId, _ticketAmount, msg.sender, nonce, "Ticket");
    }


    function batchConvertNFT2Ticket(uint256[] memory _tokenIdArray, uint256 _ticketAmount, bytes32 hash, bytes memory signature, string memory nonce) public whenNotPaused {
        //验证hash
        require(hashBatchConvertNFTsTransaction(_tokenIdArray, msg.sender, _ticketAmount, nonce, "Ticket") == hash, "Invalid hash!");
        //验证签名
        require(matchAddressSigner(hash, signature), "Invalid signature!");
        //批量验证是否拥有该资产NFT
        require(_batchValidateOwnership(_tokenIdArray), "You don't have these NFT!");
        //批量铸造
        _mintNft(_generateAmountArray(_tokenIdArray.length), _ticketAmount, ticketContractAddress);
        //销毁奖品
        require(_batchBurnNFT(_tokenIdArray), "burnNFT failed!");
        emit BatchConvertNFT(_ticketAmount, msg.sender, "Ticket", _tokenIdArray, nonce);
    }


    function _validateOwnership(uint256 _tokenId) internal view returns (bool){
        IERC1155 Common1155NFTContract = IERC1155(assetsContractAddress);
        require(Common1155NFTContract.balanceOf(msg.sender, _tokenId) > 0);
        return true;
    }


    function _batchValidateOwnership(uint256[] memory _tokenIdArray) internal view returns (bool){
        IERC1155 Common1155NFTContract = IERC1155(assetsContractAddress);
        for (uint256 i = 0; i < _tokenIdArray.length; i++) {
            require(Common1155NFTContract.balanceOf(msg.sender, _tokenIdArray[i]) > 0);
        }
        return true;
    }


    function _burnNFT(address _burnNFTContractAddress, uint256 _tokenId, uint256 _burnNFTAmount) internal returns (bool){
        Common1155NFT Common1155NFTContract = Common1155NFT(_burnNFTContractAddress);
        Common1155NFTContract.dissolve(msg.sender, _tokenId, _burnNFTAmount);
        return true;
    }


    function _batchBurnNFT(uint256[] memory _tokenIdArray) internal returns (bool){
        Common1155NFT Common1155NFTContract = Common1155NFT(assetsContractAddress);
        uint256[] memory burnNFTAmountArray = _generateAmountArray(_tokenIdArray.length);
        Common1155NFTContract.dissolveBatch(msg.sender, _tokenIdArray, burnNFTAmountArray);
        return true;
    }

    function hashRaffleTransaction(uint256 _eventId, address sender, uint256 qty, string memory nonce, uint256 _payType) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(_eventId, sender, qty, nonce, _payType))
            )
        );
        return hash;
    }


    function hashWithdrawNFTTransaction(uint256 _tokenId, address _withdrawNFTContractAddress, uint256 _withdrawNFTTokenID, address _withdrawNFTAddress, address sender, string memory nonce) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(_tokenId, _withdrawNFTContractAddress, _withdrawNFTTokenID, _withdrawNFTAddress, sender, nonce))
            )
        );
        return hash;
    }

    function hashWithdrawNFTByMintTransaction(uint256 _tokenId, address _withdrawNFTContractAddress, uint256 _withdrawNFTTokenID, address sender, string memory nonce, address _creatorAddress) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(_tokenId, _withdrawNFTContractAddress, _withdrawNFTTokenID, sender, nonce, _creatorAddress))
            )
        );
        return hash;
    }


    function hashConvertNFTTransaction(uint256 tokenId, address sender, uint256 qty, string memory nonce, string memory convertType) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encodePacked(tokenId, sender, qty, nonce, convertType))
            )
        );
        return hash;
    }


    function hashBatchConvertNFTsTransaction(uint256[] memory tokenIdArray, address sender, uint256 qty, string memory nonce, string memory convertType) private pure returns (bytes32) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                "\x19Ethereum Signed Message:\n32",
                keccak256(abi.encode(tokenIdArray, sender, qty, nonce, convertType))
            )
        );
        return hash;
    }


    function matchAddressSigner(bytes32 hash, bytes memory signature) private view returns (bool) {
        return signerAddress == recoverSigner(hash, signature);
    }


    function transferETH(address _toAddress, uint256 _amount) public payable {
        require(hasRole(ETH_TRANSFER_ROLE, msg.sender));
        uint256 contractBalance = address(this).balance;
        require(contractBalance >= _amount, "The ether of be sent must be less than the contractBalance!");
        payable(address(_toAddress)).transfer(_amount);
    }

    /**
     * @dev  提现eth
     */
    function withdraw() public payable {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender));
        uint256 withdrawETH = address(this).balance - 0.01 ether;
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