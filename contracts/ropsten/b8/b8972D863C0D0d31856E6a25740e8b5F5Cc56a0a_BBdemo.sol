//SPDX-License-Identifier: UNLICENSED"
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";

contract BBdemo is ERC1155, Ownable, Pausable {


    //////////////////////////////////////////// 变量 /////////////////////////////////////////////
    using Strings for string;
    using SafeMath for uint256;
    //NFT和创建者地址映射。
    mapping (uint256 => address) internal creators;
    //账户地址和NFT数量映射。
    mapping (address => mapping(uint256 => uint256)) internal balances;
    //账户授权关系映射。
    mapping (address => mapping(address => bool)) internal operators;
    //当前的token_ID。
    //    uint256 private _currentTokenID = 0;
    //NFT和NFT供应量映射。
    mapping (uint256 => uint256) public tokenSupply;
    //NFT和其自定义URI映射。
    mapping (uint256 => string) internal customUri;
    // 智能合约的名字。
    string public name = "Beastbox";
    // 智能合约的symbol。
    string public symbol = "BBT";

    //////////////////////////////////////////// 构造函数 ////////////////////////////////////////////////
    constructor() ERC1155("https://nft.ohdat.org/v1/{id}") {
    }

    /////////////////////////////////////////// 函数限定修饰符 ////////////////////////////////////////////
    /**
     * @dev 创建者限定。
     */
    modifier creatorOnly(uint256 _id) {
        require(creators[_id] == _msgSender(), "ERC1155Tradable#creatorOnly: ONLY_CREATOR_ALLOWED");
        _;
    }
    /**
     * @dev 拥有者限定。
     */
    modifier ownersOnly(uint256 _id) {
        require(balanceOf(_msgSender(), _id) > 0, "ERC1155Tradable#ownersOnly: ONLY_OWNERS_ALLOWED");
        _;
    }

    //////////////////////////////////////////// metadata-URI ////////////////////////////////////////////
    /**
      * @dev 返回查询某个token_id的uri。
      * @param _id 传入要查询的token_id。
      */
    function uri(uint256 _id) override public view returns (string memory) {
        //必须存在此token_id对应的token。
        require(_exists(_id), "ERC1155Tradable#uri: NONEXISTENT_TOKEN");
        //将字符串转换为字节来检查uri是否存在。
        bytes memory customUriBytes = bytes(customUri[_id]);
        if (customUriBytes.length > 0) {
            return customUri[_id];
        } else {
            return super.uri(_id);
        }
    }
    /**
     * @dev 更新某个token的URI。
     * @param _tokenId 要更新的token_id。 _msgSender()必须是它的创建者。
     * @param _newURI 给这个uri传入的新的uri。
     */
    function setCustomURI(uint256 _tokenId, string memory _newURI) public creatorOnly(_tokenId) {
        customUri[_tokenId] = _newURI;
        //触发URI事件log
        emit URI(_newURI, _tokenId);
    }

    //////////////////////////////////////////// 铸造NFT ////////////////////////////////////////////
    /**
      * @dev 创建一个新的token给一个地址,并传入一个初始供应量的数值。
      * NOTE:必须传入token_ID这一个参数。
      * @param _initialOwner 代币的第一个所有者的个人地址。
      * @param _id 要创建的token_ID（此token当前必须不存在）。
      * @param _initialSupply 供应给第一个所有者的金额。
      * @param _uri Optional 可选的URI给这个token。
      * @param _data 如果接收者是一个合约，则要传递给它的数据。
      * @return 返回新创建的token_id。
      */
    function mint(address _initialOwner, uint256 _id, uint256 _initialSupply, string memory _uri, bytes memory _data) public onlyOwner returns (uint256) {
        //当前的NFT必须不存在！
        require(!_exists(_id), "token _id already exists");
        //将调用者的地址设置为创建者。
        creators[_id] = _msgSender();
        //初始化URI。
        if (bytes(_uri).length > 0) {
            customUri[_id] = _uri;
            //触发URI事件。
            emit URI(_uri, _id);
        }
        //调用内部的铸造函数。
        _mint(_initialOwner, _id, _initialSupply, _data);
        //将此tokensupply对应的token_id增加对应的_initialSupply数量。
        tokenSupply[_id] = _initialSupply;
        //返回生成的token_id。
        return _id;
    }


    /**
      * @dev                 批量铸造NFT。
      * @param _to          要给其铸造的代币的地址。
      * @param _ids         分配的token——id的数组。
      * @param _quantities  和token_id,相对应的铸造数量数组。
      * @param _data        如果接收者是合约，则要给其传递的数据。
      */
    function batchMint(address _to, uint256[] memory _ids, uint256[] memory _quantities, bytes memory _data) public {
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 _id = _ids[i];
            require(creators[_id] == _msgSender(), "ERC1155Tradable#batchMint: ONLY_CREATOR_ALLOWED");
            uint256 quantity = _quantities[i];
            tokenSupply[_id] = tokenSupply[_id].add(quantity);
        }
        _mintBatch(_to, _ids, _quantities, _data);
    }


    // /**
    //   * @dev         更改给定token创建者的地址。
    //   * @param _to   新创建者的地址。
    //   * @param _ids  用于更改创建者的token_ID数组。
    //   */
    // function setCreator(address _to, uint256[] memory _ids) override public creatorOnly(_to) {
    //     //要求更改的新创建者的地址不能是空地址。
    //     require(_to != address(0), "ERC1155ffffffTradable#setCreator: INVALID_ADDRESS.");
    //     //遍历更改。
    //     for (uint256 i = 0; i < _ids.length; i++) {
    //         uint256 id = _ids[i];
    //         _setCreator(_to, id);
    //     }
    // }


    // function _setCreator(address _to, uint256 _id) internal creatorOnly(_id) {
    //   creators[_id] = _to;
    // }


    //////////////////////////////////////////// Approve授权 ////////////////////////////////////////////

    function setApprovalForAll(address operator, bool approved) public virtual override {
        require(_msgSender() != operator, "ERC1155: setting approval status for self");
        operators[_msgSender()][operator] = approved;
        emit ApprovalForAll(_msgSender(), operator, approved);
    }

    function isApprovedForAll(address _owner, address _operator) override public view returns (bool isOperator) {
        return ERC1155.isApprovedForAll(_owner, _operator);
    }

    //////////////////////////////////////////// 检查 ////////////////////////////////////////////
    /**
      * @dev 通过检查指定的token_id是否具有创建者，来判断此token代币是否存在。
      * @param _id 要检查的token_id。
      */
    function _exists(uint256 _id) internal view returns (bool) {
        return creators[_id] != address(0);
    }

    function exists(uint256 _id) external view returns (bool) {
        return _exists(_id);
    }

    //////////////////////////////////////////// 销毁NFT ////////////////////////////////////////////

    /**
     * @notice Burn    要销毁的指定token——id的数量。
     * @param _from    要销毁的NFT的来源地址。
     * @param _id      要销毁的token_id。
     * @param _amount  要销毁的数量。
     */
    function _burn(address _from, uint256 _id, uint256 _amount) override internal {
        //相应的balance减去一定的数量。
        balances[_from][_id] = balances[_from][_id].sub(_amount);
        // 触发销毁的TransferSingle事件log。
        emit TransferSingle(msg.sender, _from, address(0x0), _id, _amount);
    }

    /**
     * @notice 批量销毁NFT,_ids和_amounts两个数组元素需要一一对应。)
     * @param _from     要销毁的NFT的来源地址。
     * @param _ids      要销毁的NFT的token_id数组。
     * @param _amounts  要销毁的NFT的数量。
     */
    function _batchBurn(address _from, uint256[] memory _ids, uint256[] memory _amounts) internal {
        // 将要销毁的数量。
        uint256 nBurn = _ids.length;
        //需要_ids数组长度和_amounts数组长度相匹配。
        require(nBurn == _amounts.length, "ERC1155MintBurn#batchBurn: INVALID_ARRAYS_LENGTH");
        // 遍历执行所有的销毁操作。
        for (uint256 i = 0; i < nBurn; i++) {
            // 更新balance。
            balances[_from][_ids[i]] = balances[_from][_ids[i]].sub(_amounts[i]);
        }
        // 触发批量销毁的事件。
        emit TransferBatch(msg.sender, _from, address(0x0), _ids, _amounts);
    }


    //////////////////////////////////////////// 转移NFT ////////////////////////////////////////////
    /**
     * @notice         安全单个转移。
     * @param _from    源地址
     * @param _to      目标地址
     * @param _id      token_id。
     * @param _amount  转移的数量
     * @param _data    Additional data with no specified format, sent in call to `_to`
     */
    function  safeTransferFrom(address _from, address _to, uint256 _id, uint256 _amount, bytes memory _data)override public {
        require((msg.sender == _from) || isApprovedForAll(_from, msg.sender), "ERC1155#safeTransferFrom: INVALID_OPERATOR");
        require(_to != address(0),"ERC1155#safeTransferFrom: INVALID_RECIPIENT");
        // require(_amount <= balances[_from][_id]) is not necessary since checked with safemath operations
        _safeTransferFrom(_from, _to, _id, _amount);
        //        _callonERC1155Received(_from, _to, _id, _amount, gasleft(), _data);
    }

    function _safeTransferFrom(address _from, address _to, uint256 _id, uint256 _amount)internal{
        // 更新balance
        balances[_from][_id] = balances[_from][_id].sub(_amount); // Subtract amount
        balances[_to][_id] = balances[_to][_id].add(_amount);     // Add amount
        // 触发TransferSingle事件log
        emit TransferSingle(msg.sender, _from, _to, _id, _amount);
    }
    /**
     * @notice 验证接收者是否是合约，如果是，则调用 (_to).onERC1155Received(...)
     */
    //    function _callonERC1155Received(address _from, address _to, uint256 _id, uint256 _amount, uint256 _gasLimit, bytes memory _data)internal{
    //        // 检查接收者是否是一个合约。
    //        if (_to.isContract()) {
    //            IERC1155TokenReceiver(_to).onERC1155Received{gas: _gasLimit}(msg.sender, _from, _id, _amount, _data);
    ////            bytes4 retval = IERC1155TokenReceiver(_to).onERC1155Received{gas: _gasLimit}(msg.sender, _from, _id, _amount, _data);
    ////            require(retval == ERC1155_RECEIVED_VALUE, "ERC1155#_callonERC1155Received: INVALID_ON_RECEIVE_MESSAGE");
    //        }
    //    }

    /**
     * @notice          安全批量转移
     * @param _from     源地址
     * @param _to       目标地址
     * @param _ids      IDs of each token type
     * @param _amounts  Transfer amounts per token type
     * @param _data     Additional data with no specified format, sent in call to `_to`
         */
    function safeBatchTransferFrom(address _from, address _to, uint256[] memory _ids, uint256[] memory _amounts, bytes memory _data)override public {
        // Requirements
        require((msg.sender == _from) || isApprovedForAll(_from, msg.sender), "ERC1155#safeBatchTransferFrom: INVALID_OPERATOR");
        require(_to != address(0), "ERC1155#safeBatchTransferFrom: INVALID_RECIPIENT");
        _safeBatchTransferFrom(_from, _to, _ids, _amounts);
        //        _callonERC1155BatchReceived(_from, _to, _ids, _amounts, gasleft(), _data);
    }

    /**
     * @notice          安全批量转移。
     * @param _from     源地址
     * @param _to       目标地址。
     * @param _ids      token_ID数组。
     * @param _amounts  和token_ID数组相对应的转移数量数组。
     */
    function _safeBatchTransferFrom(address _from, address _to, uint256[] memory _ids, uint256[] memory _amounts) internal {
        require(_ids.length == _amounts.length, "ERC1155#_safeBatchTransferFrom: INVALID_ARRAYS_LENGTH");
        // 定义一个变量表示要执行转移的数量。
        uint256 nTransfer = _ids.length;
        // 执行所有transfer
        for (uint256 i = 0; i < nTransfer; i++) {
            balances[_from][_ids[i]] = balances[_from][_ids[i]].sub(_amounts[i]);
            balances[_to][_ids[i]] = balances[_to][_ids[i]].add(_amounts[i]);
        }
        // 触发批量转移事件log
        emit TransferBatch(msg.sender, _from, _to, _ids, _amounts);
    }

    //    /**
    //     * @notice 验证接收者是否是合约，如果是，则调用 (_to).onERC1155BatchReceived(...)
    //     */
    //    function _callonERC1155BatchReceived(address _from, address _to, uint256[] memory _ids, uint256[] memory _amounts, uint256 _gasLimit, bytes memory _data) internal {
    //    // 如果收件人是合约，则给其传递数据。
    //    if (_to.isContract()) {
    //        bytes4 retval = IERC1155TokenReceiver(_to).onERC1155BatchReceived{gas: _gasLimit}(msg.sender, _from, _ids, _amounts, _data);
    //        require(retval == ERC1155_BATCH_RECEIVED_VALUE, "ERC1155#_callonERC1155BatchReceived: INVALID_ON_RECEIVE_MESSAGE");
    //        }
    //    }


    //////////////////////////////////////////// 查询balance ////////////////////////////////////////////

    /**
     * @notice        获取账户持有的token的余额。
     * @param _owner  代币持有者的地址
     * @param _id     Token_ID。
     * @return        返回地址相对应的Token的余额。
     */
    function balanceOf(address _owner, uint256 _id)override public  view returns (uint256){
        return balances[_owner][_id];
    }

    /**
     * @notice 获取多个(owner, id) 相对应的余额。
     * @param _owners 代币持有者的地址数组。
     * @param _ids    token_id的数组。
     * @return        返回一个 (owner, id) 相对应的余额数组。
     */
    function balanceOfBatch(address[] memory _owners, uint256[] memory _ids) override public  view returns (uint256[] memory){
        // _owners数组长度必须和token_ids的数组相等。
        require(_owners.length == _ids.length, "ERC1155#balanceOfBatch: INVALID_ARRAY_LENGTH");
        //定义一个长度为_owners数组长度的定长数组。
        uint256[] memory batchBalances = new uint256[](_owners.length);
        //遍历每个所有者和token_ID
        for (uint256 i = 0; i < _owners.length; i++) {
            batchBalances[i] = balances[_owners[i]][_ids[i]];
        }
        return batchBalances;
    }
}