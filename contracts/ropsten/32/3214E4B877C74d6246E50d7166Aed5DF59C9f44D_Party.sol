// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.2/contracts/token/ERC20/utils/SafeERC20.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.2/contracts/token/ERC20/IERC20.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.2/contracts/utils/cryptography/ECDSA.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.2/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev Party Contract.
 * Becasue this smart contract use many off chain data for its transactions, there are needs
 * to make sure that the data came from the right source or valid. In this implementation we use Signature
 * method. In this smart contract, off chain data will be signed using the user's or the platform's
 * private key. But in order to minimize the cost only the RSV of said signature get sent to the
 * smart contract. The smart contract then must also receive signature's message combination alongside
 * the RSV in order to verify the signature.
 */

/**
 * @dev Member signature is deleted because the member is no need to be verified, because the signature
 * is always the same.
 */

//TODO: Remove calculateWeight

contract Party is Ownable {
    using SafeERC20 for IERC20;
    IERC20 token;
    address private immutable PLATFORM_ADDRESS;
    mapping(address => bool) private member;
    address[] public memberList;
    uint256 public balanceParty;
    uint256 private MAX_DEPOSIT;
    uint256 private MIN_DEPOSIT;

    //EVENTS
    event DepositEvent(address caller, address partyAddress, uint256 amount, uint256 cut);
    event JoinEvent(address caller, address partyAddress, string joinPartyId, string userId, uint256 amount, uint256 cut);
    event CreateEvent(address caller, string partyName, string partyId, string ownerId);
    event ApprovePayerEvent(string proposalId, address[] payers);
    event WithdrawEvent(address caller, address partyAddress, uint256 amount, uint256 cut, uint256 penalty);
    event LeavePartyEvent(address userAddress, uint256 weight, address partyAddress, uint256 sent, uint256 cut, uint256 penalty);
    event KickPartyEvent(address userAddress, uint256 weight, address partyAddress, uint256 sent, uint256 cut, uint256 penalty);
    event ClosePartyEvent(address partyAddress, address ownerAddress);
    event Qoute0xSwap(IERC20 sellTokenAddress, IERC20 buyTokenAddress, address spender, address swapTarget, string transactionType, uint256 sellAmount, uint256 buyAmount, uint256 fee);

    //Struct

    struct PartyInfo {
        string idParty;
        string ownerId;
        address userAddress;
        address platform_Address;
        string typeP;
        string partyName;
        bool isPublic;
    }

    struct Swap {
        IERC20 buyTokenAddress;
        IERC20 sellTokenAddress;
        address spender;
        address payable swapTarget;
        bytes swapCallData;
        uint256 sellAmount;
        uint256 buyAmount;
        bytes32 r; bytes32 s; uint8 v;
    }

    struct SwapWithoutRSV {
        IERC20 buyTokenAddress;
        IERC20 sellTokenAddress;
        address spender;
        address payable swapTarget;
        bytes swapCallData;
        uint256 sellAmount;
        uint256 buyAmount;
    }

    struct Weight {
        address weightAddress;
        uint256 weightPercentage;
    }

    Swap private swap;

    /**
     * @dev Create Party Message Combination
     * platform signature message :
     *  -  idParty:string
     *  -  userAddress:address
     *  -  platform_Address:address
     *  -  ownerId:string
     *  -  isPublic:bool
     */
    constructor(uint256 minDeposit, uint256 maxDeposit, PartyInfo memory inputPartyInformation, bytes32 r, bytes32 s, uint8 v, IERC20 stableCoin) {
        // rangeDEP = inputRangeDep;
        MAX_DEPOSIT = maxDeposit;
        MIN_DEPOSIT = minDeposit;
        PLATFORM_ADDRESS = inputPartyInformation.platform_Address;
        token = IERC20(stableCoin);
        //platform verification purpose
        require(
            verifySigner(
                inputPartyInformation.platform_Address,
                messageHash(
                    abi.encodePacked(
                        inputPartyInformation.idParty,
                        inputPartyInformation.userAddress,
                        inputPartyInformation.platform_Address,
                        inputPartyInformation.ownerId,
                        inputPartyInformation.isPublic
                    )
                ),
                r,s,v
            ),
            "platform invalid"
        );
        emit CreateEvent(
            msg.sender,
            inputPartyInformation.partyName,
            inputPartyInformation.idParty,
            inputPartyInformation.ownerId
        );
    }

    function fillQuote(
        IERC20 sellTokenAddress,
        IERC20 buyTokenAddress,
        address spender,
        address payable swapTarget,
        bytes memory swapCallData,
        uint256 sellAmount,
        uint256 buyAmount,
        bytes32 r, bytes32 s, uint8 v
    ) public payable {
        require(
            verifySigner(
                PLATFORM_ADDRESS,
                messageHash(
                    abi.encodePacked(
                        sellTokenAddress,
                        buyTokenAddress,
                        spender,
                        swapTarget,
                        sellAmount,
                        buyAmount
                    )
                ),
                r,s,v
            ),
            "Approve Signature Failed"
        );
        uint256 fee = (buyAmount * 5) / 1000;
        require(
            sellAmount <= sellTokenAddress.balanceOf(address(this)),
            "Balance not enough."
        );
        require(sellTokenAddress.approve(spender, type(uint256).max));
        (bool success, ) = swapTarget.call{value: msg.value}(swapCallData);
        require(success, "SWAP_CALL_FAILED");
        payable(msg.sender).transfer(address(this).balance);
        buyTokenAddress.safeTransfer(PLATFORM_ADDRESS, fee);
        sellTokenAddress.approve(spender, 0);
        if (sellTokenAddress == token) {
            emit Qoute0xSwap(
                sellTokenAddress,
                buyTokenAddress,
                spender,
                swapTarget,
                "BUY",
                sellAmount,
                buyAmount,
                fee
            );
        } else {
            emit Qoute0xSwap(
                sellTokenAddress,
                buyTokenAddress,
                spender,
                swapTarget,
                "SELL",
                sellAmount,
                buyAmount,
                fee
            );
        }
    }

    /**
     * @dev Withdraw Function
     * Withdraw function is for the user that want their money back.
     * //WORK IN PROGRESS
     */
    function withdraw(
        address partyAddress,
        uint256 amount,
        uint256 n,
        SwapWithoutRSV[] memory tokenData,
        bytes32 r, bytes32 s, uint8 v
    ) external payable isAlive onlyMember {
        require(
            verifySigner(
                PLATFORM_ADDRESS,
                messageHash(abi.encodePacked(partyAddress, amount, n)),
                r,s,v
            ),
            "Withdraw platform signature invalid"
        );
        uint256 fee = 0;
        for (uint256 index = 0; index < tokenData.length; index++) {
            fee = (tokenData[index].buyAmount * 5) / 1000;
            require(
                tokenData[index].sellAmount <=
                    tokenData[index].sellTokenAddress.balanceOf(address(this)),
                "Balance not enough."
            );
            require(
                tokenData[index].sellTokenAddress.approve(
                    tokenData[index].spender,
                    type(uint256).max
                ),
                "Approval invalid"
            );
            (bool success, ) = tokenData[index].swapTarget.call{
                value: msg.value
            }(tokenData[index].swapCallData);
            require(success, "SWAP_CALL_FAILED");
            payable(msg.sender).transfer(address(this).balance);
            tokenData[index].buyTokenAddress.safeTransfer(
                PLATFORM_ADDRESS,
                fee
            );
            emit Qoute0xSwap(
                tokenData[index].sellTokenAddress,
                tokenData[index].buyTokenAddress,
                tokenData[index].spender,
                tokenData[index].swapTarget,
                "SELL",
                tokenData[index].sellAmount,
                tokenData[index].buyAmount,
                fee
            );
        }
        require(
            amount <= token.balanceOf(address(this)),
            "Enter the correct Amount"
        );
        uint256 cut = (amount * 5) / 1000; // 1000 * 100000 = 100000000
        uint256 penalty = calculatePenalty(amount, n);
        uint256 sent = amount - cut - penalty;
        token.safeTransfer(PLATFORM_ADDRESS, cut + penalty);
        token.safeTransfer(msg.sender, sent);
        emit WithdrawEvent(msg.sender, partyAddress, amount, cut, penalty);
    }

    function getPartyBalance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    /**
     * @dev Deposit Function
     * deposit function sents token to sc it self when triggred.
     * in order to trigger deposit function, user must be a member
     * you can see the modifier "onlyMember" inside deposit function
     * if the user is already on member list, then the function will be executed
     *
     */
    function deposit(address partyAddress, uint256 amount) external isAlive {
        uint256 cut = (amount * 5) / 1000;
        token.safeTransferFrom(msg.sender, address(this), amount);
        token.safeTransferFrom(msg.sender, PLATFORM_ADDRESS, cut);
        emit DepositEvent(msg.sender, partyAddress, amount, cut);
    }

    /**
     * @dev Join Party Function
     *
     * join party function need rsv parameters and messages parameters from member
     * this both parameters is needed to do some validation within member it self, before the member can join party
     * when the user succeed joining party, users will be added to memberlist.
     *
     * platform signature message :
     *  - ownerAddress:address
     *  - partyAddress:address
     *  - joinPartyId:string
     */
    function joinParty(
        bytes32 r, bytes32 s, uint8 v,
        address partyAddress,
        string memory userId,
        string memory joinPartyId,
        uint256 amount
    ) external isAlive notAMember reqDeposit(amount) {
        require(
            verifySigner(
                PLATFORM_ADDRESS,
                messageHash(
                    abi.encodePacked(msg.sender, partyAddress, joinPartyId)
                ),
                r,s,v
            ),
            "Transaction Signature Invalid"
        );
        require(!member[msg.sender], "Member is already registered.");
        memberList.push(msg.sender);
        member[msg.sender] = true;
        uint256 cut = (amount * 5) / 1000;
        token.safeTransferFrom(msg.sender, address(this), amount);
        token.safeTransferFrom(msg.sender, PLATFORM_ADDRESS, cut);
        emit JoinEvent(
            msg.sender,
            partyAddress,
            joinPartyId,
            userId,
            amount,
            cut
        );
    }

    function leaveParty(
        address quittingMember,
        uint256 addressWeight,
        uint256 n,
        SwapWithoutRSV[] memory tokenData,
        bytes32 r, bytes32 s, uint8 v
    ) external payable onlyMember isAlive {
        require(
            verifySigner(
                PLATFORM_ADDRESS,
                messageHash(abi.encodePacked(quittingMember, addressWeight)),
                r,s,v
            ),
            "Withdraw platform signature invalid"
        );
        uint256 balanceBeforeSwap = getPartyBalance();
        if (tokenData.length != 0) {
            swapPlaceHolder(tokenData);
        }
        uint256 balanceDiff = getPartyBalance() - balanceBeforeSwap;
        uint256 _userBalance = ((balanceBeforeSwap * addressWeight) / 10**6) +
            balanceDiff;
        removeMember(quittingMember);
        uint256 cut = (_userBalance * 5) / 1000; // 1000 * 100000 = 100000000
        uint256 penalty = calculatePenalty(_userBalance, n);
        uint256 sent = _userBalance - cut - penalty;
        member[msg.sender] = false;
        token.safeTransfer(msg.sender, sent);
        token.safeTransfer(PLATFORM_ADDRESS, cut + penalty);
        emit LeavePartyEvent(
            quittingMember,
            addressWeight,
            address(this),
            _userBalance,
            cut,
            penalty
        );
    }

    function kickParty(
        address quittingMember,
        uint256 addressWeight,
        uint256 n,
        SwapWithoutRSV[] memory tokenData,
        bytes32 r, bytes32 s, uint8 v
    ) external payable onlyOwner isAlive {
        require(
            verifySigner(
                PLATFORM_ADDRESS,
                messageHash(abi.encodePacked(quittingMember, addressWeight)),
                r,s,v
            ),
            "Withdraw platform signature invalid"
        );
        uint256 balanceBeforeSwap = getPartyBalance();
        if (tokenData.length != 0) {
            swapPlaceHolder(tokenData);
        }
        uint256 _userBalance = ((balanceBeforeSwap * addressWeight) / 10**6) +
            (getPartyBalance() - balanceBeforeSwap);
        removeMember(quittingMember);
        uint256 cut = (_userBalance * 5) / 1000; // 1000 * 100000 = 100000000
        uint256 penalty = calculatePenalty(_userBalance, n);
        uint256 sent = _userBalance - cut - penalty;
        member[quittingMember] = false;
        token.safeTransfer(quittingMember, sent);
        token.safeTransfer(PLATFORM_ADDRESS, cut + penalty);
        emit KickPartyEvent(
            quittingMember,
            addressWeight,
            address(this),
            _userBalance,
            cut,
            penalty
        );
    }

    function swapPlaceHolder(SwapWithoutRSV[] memory tokenData)
        internal
        isAlive
        returns (uint256)
    {
        uint256 fee = 0;
        for (uint256 index = 0; index < tokenData.length; index++) {
            fee = (tokenData[index].buyAmount * 5) / 1000;
            require(
                tokenData[index].sellAmount <= tokenData[index].sellTokenAddress.balanceOf(address(this)), "Balance not enough."
            );
            require(
                tokenData[index].sellTokenAddress.approve(
                    tokenData[index].spender,
                    type(uint256).max
                ),
                "Approval invalid"
            );
            (bool success, ) = tokenData[index].swapTarget.call{
                value: msg.value
            }(tokenData[index].swapCallData);
            require(success, "SWAP_CALL_FAILED");
            payable(msg.sender).transfer(address(this).balance);
            tokenData[index].buyTokenAddress.safeTransfer(
                PLATFORM_ADDRESS,
                fee
            );
            // tokenData[index].sellTokenAddress.approve(
            //     tokenData[index].spender,
            //     0
            // );
            emit Qoute0xSwap(
                tokenData[index].sellTokenAddress,
                tokenData[index].buyTokenAddress,
                tokenData[index].spender,
                tokenData[index].swapTarget,
                "SELL",
                tokenData[index].sellAmount,
                tokenData[index].buyAmount,
                fee
            );
        }
        return fee;
    }

    function closeParty(
        Weight[] memory weightArray,
        SwapWithoutRSV[] memory tokenData,
        bytes32 r, bytes32 s, uint8 v
    ) external payable onlyOwner isAlive {
        require(
            verifySigner(
                PLATFORM_ADDRESS,
                messageHash(abi.encodePacked(msg.sender)),
                r,s,v
            ),
            "Withdraw platform signature invalid"
        );
        if (tokenData.length != 0) {
            swapPlaceHolder(tokenData);
        }
        uint256 fee = 0;
        //address _temp = OWNER;
        // OWNER = address(0x0);
        //@dev owner is now set to 0x0
        renounceOwnership();
        uint256 x = getPartyBalance();
        for (uint256 index = 0; index < weightArray.length; index++) {
            uint256 value = ((weightArray[index].weightPercentage * x) / 10**6);
            fee = (value * 5) / 1000;
            token.safeTransfer(weightArray[index].weightAddress, value - fee);
            token.safeTransfer(PLATFORM_ADDRESS, fee);
            emit LeavePartyEvent(
                weightArray[index].weightAddress,
                weightArray[index].weightPercentage,
                address(this),
                value,
                fee,
                0
            );
        }
        emit ClosePartyEvent(address(this), owner());
    }

    function calculatePenalty(uint256 _userBalance, uint256 n)
        private
        pure
        returns (uint256)
    {
        uint256 penalty;
        if (n != 0) {
            uint256 _temp = 17 * 10**8 + (n - 1) * 4160674157; //times 10 ** 10
            _temp = (_temp * 10**6) / 10**10;
            penalty = (_userBalance * _temp) / 10**8;
        } else {
            penalty = 0;
        }
        return penalty;
    }

    function removeMember(address quittingMember) private {
        for (uint256 index = 0; index < memberList.length; index++) {
            if (memberList[index] == quittingMember) {
                memberList[index] = memberList[memberList.length - 1];
                memberList.pop();
                break;
            }
        }
    }
    modifier onlyMember() {
        require(member[msg.sender], "havent join party yet");
        _;
    }
    modifier notAMember() {
        require(!member[msg.sender], "havent join party yet");
        _;
    }
    modifier isAlive() {
        require(owner() != address(0), "Party is dead");
        _;
    }

    /**
     * @dev reqDeposit function
     * to ensure the deposit value is correct and doesn't exceed the specified limit
     */
    modifier reqDeposit(uint256 amount) {
        require(!(amount < MIN_DEPOSIT), "Deposit is not enough");
        require(!(amount > MAX_DEPOSIT), "Deposit is too many");
        _;
    }

    function messageHash(bytes memory abiEncode)
        internal
        pure
        returns (bytes32)
    {
        return
            keccak256(
                abi.encodePacked(
                    "\x19Ethereum Signed Message:\n32",
                    keccak256(abiEncode)
                )
            );
    }

     function verifySigner(address signer, bytes32 ethSignedMessageHash, bytes32 r, bytes32 s, uint8 v) internal pure returns (bool) {
        return ECDSA.recover(ethSignedMessageHash, v, r, s ) == signer;
    }
}