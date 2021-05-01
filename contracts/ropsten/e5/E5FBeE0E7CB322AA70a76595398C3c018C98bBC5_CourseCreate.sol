// SPDX-License-Identifier: SimPL-2.0
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CourseCreate {
    using SafeERC20 for IERC20;
    // 绑定token
    IERC20 immutable private _token;

    // 课程简介
    course private _course;

    struct course {
        string title; // 标题
        string content; // 内容
        uint cType; // 类型
        uint classRoomType; // 教室类型
        string cover; // 封面
        uint256 startTime; // 开始时间
        uint256 endTime; // 结束时间
        bool canRedeemAfterStart; // 是否允许开始后兑换
        address host; // 主持人地址
        address admin; // 管理员地址
    }

    // 是否废弃合约(可自行取回token)
    bool private _isDiscard;
    // 是否正常结束合约
    bool private _isNormalEnd;

    // 参与听课学生的名称
    mapping(address => string) private students;
    // 参与听课学生存入的token
    mapping(address => uint256) private beneficiaries;

    /**
     * @return the token being held.
     */
    function token() public view virtual returns (IERC20) {
        return _token;
    }

    constructor (IERC20 token_,
        string memory title, string memory content, uint cType, uint classRoomType,
        string memory cover, uint256 startTime, uint256 endTime, bool canRedeemAfterStart,
        address admin) {
        require(admin != address(0), "Empty admin address");
        _token = token_;
        _course = course(title, content, cType, classRoomType, cover, startTime, endTime,
            canRedeemAfterStart, address(msg.sender), address(admin));
    }

    function getReleaseAmount(address beneficiary) private view returns (uint256) {
        return beneficiaries[beneficiary];
    }

    function clearBeneficiary(address beneficiary) private {
        delete (beneficiaries[beneficiary]);
        delete (students[beneficiary]);
    }

    /**
     * 管理员/老师退回token调用
     */
    function refundTo(address to) public virtual {
        require(address(msg.sender) == _course.admin || address(msg.sender) == _course.host, "no auth");

        uint256 amount = token().balanceOf(address(this));
        uint256 needReleaseAmount = getReleaseAmount(to);
        require(needReleaseAmount > amount, "No tokens to release");
        require(needReleaseAmount > 0, "No tokens to release");

        token().safeTransfer(address(to), needReleaseAmount * 1000);
        clearBeneficiary(to);
    }

    function setIsDiscard() public virtual {
        require(address(msg.sender) == _course.admin || address(msg.sender) == _course.host, "no auth");
        _isDiscard = true;
    }

    function setIsNormalEnd() public virtual {
        require(address(msg.sender) == _course.admin || address(msg.sender) == _course.host, "no auth");
        require(block.timestamp > _course.endTime, "no end time");
        _isNormalEnd = true;
    }

    function setBeneficiary(address beneficiary, uint256 tokenAmount, string memory addressName) private {
        beneficiaries[beneficiary] += tokenAmount;
        students[beneficiary] = addressName;
    }

    // 废止合约，自行取回Token
    function refundBySelf() public virtual {
        uint256 needReleaseAmount = getReleaseAmount(address(msg.sender));
        uint256 selfAmount = token().balanceOf(address(this));
        require(needReleaseAmount <= selfAmount, "No tokens to release");
        require(needReleaseAmount > 0, "No tokens to release");
        require(_isDiscard, "no auth");
        token().safeTransfer(address(msg.sender), needReleaseAmount * 1000);
        clearBeneficiary(address(msg.sender));
    }

    function lock(uint256 amountToLock, string memory addressName) public virtual {
        require(!_isDiscard, "The contract has been discarded");
        // 开课前支付开启 或 时间未到开课时间允许
        require(block.timestamp >= _course.startTime || _course.canRedeemAfterStart, "No auth");
        uint256 amount = token().balanceOf(address(msg.sender));
        require(amountToLock > 0, "You need to lock some token");
        require(amountToLock <= amount, "Not enough tokens to be locked");
        // Before this action you must approve through the token contract.
        // https://forum.openzeppelin.com/t/msg-sender-problem-for-calling-erc20-token-contract-from-another-contract-returns-contract-address/1846/2
        // Only the holder of the tokens can call approve to set an allowance for a spender.
        // A contract cannot call approve on behalf of a holder as the ERC20 token uses msg.sender to determine the holder.
        token().safeTransferFrom(address(msg.sender), address(this), amountToLock * 1000);
        setBeneficiary(address(msg.sender), amountToLock, addressName);
    }

    // 老师或管理员取出
    function unlock() public virtual {
        require(_isNormalEnd == true, "no end time");
        require(address(msg.sender) == _course.admin || address(msg.sender) == _course.host, "No auth");
        require(block.timestamp > _course.endTime, "No end time");
        uint256 allAmount = token().balanceOf(address(this));
        token().safeTransfer(address(msg.sender), allAmount * 1000);
        setIsNormalEnd();
    }

    // view
    function getCourseData() public view returns (string memory title, string memory content, uint cType, uint classRoomType,
        string memory cover,
        uint256 startTime,
        uint256 endTime,
        bool canRedeemAfterStart,
        address host,
        address admin){
        return (_course.title, _course.content, _course.cType, _course.classRoomType, _course.cover,
        _course.startTime, _course.endTime, _course.canRedeemAfterStart, _course.host, _course.admin);
    }
}