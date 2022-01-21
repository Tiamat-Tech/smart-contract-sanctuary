// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.2/contracts/token/ERC20/utils/SafeERC20.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.2/contracts/token/ERC20/IERC20.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.2/contracts/utils/cryptography/ECDSA.sol";
//import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v4.2/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


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

contract Party is Initializable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    IERC20 tokenAddress;
    address private _owner;
    address internal PLATFORM_ADDRESS;
    mapping(address => bool) public member;
    mapping(address => uint256) public memberBalance;
    mapping(address => uint256) public withdrawNonces;
    uint256 public totalDeposit;
    uint256 private MAX_DEPOSIT;
    uint256 private MIN_DEPOSIT;
    uint256 public memberCount;

    //Event
    event DepositEvent(address userAddress, address partyAddress, uint256 amount, uint256 cut);
    event JoinEvent(address userAddress, address partyAddress, string joinPartyId, string userId, uint256 amount, uint256 cut);
    event CreateEvent(address userAddress, string partyName, string partyId, string ownerId);
    event ApprovePayerEvent(string proposalId, address[] payers);
    event WithdrawEvent(address userAddress, uint256 withdrawPercentage, address partyAddress, uint256 amount, uint256 cut, uint256 penalty);
    event LeavePartyEvent(address userAddress, uint256 weight, address partyAddress, uint256 sent, uint256 cut, uint256 penalty);
    event KickPartyEvent(address userAddress, uint256 weight, address partyAddress, uint256 sent, uint256 cut, uint256 penalty);
    event ClosePartyEvent(address partyAddress, address ownerAddress);
    event Qoute0xSwap(IERC20 sellTokenAddress, IERC20 buyTokenAddress, address spender, address swapTarget, string transactionType, uint256 sellAmount, uint256 buyAmount, uint256 fee);

    //Struct
    struct PartyInfo {string idParty; string ownerId; address userAddress; address platform_Address; string typeP; string partyName; bool isPublic;}
    struct Swap {IERC20 buyTokenAddress; IERC20 sellTokenAddress; address spender; address payable swapTarget; bytes swapCallData; uint256 sellAmount; uint256 buyAmount; bytes32 r; bytes32 s; uint8 v;}
    struct SwapWithoutRSV {IERC20 buyTokenAddress; IERC20 sellTokenAddress; address spender; address payable swapTarget; bytes swapCallData; uint256 sellAmount; uint256 buyAmount;}
    struct Weight {address weightAddress; uint256 weightPercentage;}
    struct Sig {bytes32 r; bytes32 s; uint8 v;}

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
    function init(uint256 minDeposit, uint256 maxDeposit, PartyInfo memory inputPartyInformation, Sig memory platformRSV, IERC20 stableCoin, uint256 initialDeposit) external payable initializer {
        uint256 cut = getPlatformFee(initialDeposit);
        _owner = inputPartyInformation.userAddress;
        MAX_DEPOSIT = maxDeposit;
        MIN_DEPOSIT = minDeposit;
        PLATFORM_ADDRESS = inputPartyInformation.platform_Address;
        tokenAddress = IERC20(stableCoin);
        // Platform verification
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
                platformRSV
            ),
            "platform signature is invalid"
        );
        emit CreateEvent(inputPartyInformation.userAddress, inputPartyInformation.partyName, inputPartyInformation.idParty, inputPartyInformation.ownerId);

        if (withdrawNonces[inputPartyInformation.userAddress] == 0) {
            withdrawNonces[inputPartyInformation.userAddress] = 1;
        }

        member[inputPartyInformation.userAddress] = true;
        memberCount++;

        memberBalance[inputPartyInformation.userAddress] = initialDeposit - cut;
        totalDeposit = initialDeposit - cut;

        tokenAddress.safeTransferFrom(inputPartyInformation.userAddress, address(this), initialDeposit);
        tokenAddress.safeTransferFrom(inputPartyInformation.userAddress, PLATFORM_ADDRESS, cut);
    }

    function fillQuote(IERC20 sellTokenAddress, IERC20 buyTokenAddress, address spender, address payable swapTarget,bytes memory swapCallData, uint256 sellAmount, uint256 buyAmount, Sig memory approveRSV) public isAlive onlyOwner(tx.origin) payable {
        require(verifySigner(PLATFORM_ADDRESS, messageHash(abi.encodePacked(sellTokenAddress, buyTokenAddress, spender, swapTarget, sellAmount, buyAmount)), approveRSV), "Approve Signature Failed");
        uint256 fee = getPlatformFee(buyAmount);
        require(sellAmount <= sellTokenAddress.balanceOf(address(this)), "Balance not enough.");
        require(sellTokenAddress.approve(spender, type(uint256).max));
        (bool success, ) = swapTarget.call{value: msg.value}(swapCallData);
        require(success, "SWAP_CALL_FAILED");
        payable(_owner).transfer(address(this).balance);
        buyTokenAddress.safeTransfer(PLATFORM_ADDRESS, fee);
        sellTokenAddress.approve(spender, 0);
        if (sellTokenAddress == tokenAddress) {
            emit Qoute0xSwap(sellTokenAddress, buyTokenAddress, spender, swapTarget, "BUY", sellAmount, buyAmount, fee);
        } else {
            emit Qoute0xSwap(sellTokenAddress, buyTokenAddress, spender, swapTarget, "SELL", sellAmount, buyAmount, fee);
        }
    }

    /**
     * @dev Withdraw Function
     * Withdraw function is for the user that want their money back.
     */
    function withdraw(address userAddress, address partyAddress, uint256 withdrawPercentage, uint256 amount, uint256 n, uint256 nonce, SwapWithoutRSV[] memory tokenData, Sig memory withdrawRSV) external payable isAlive onlyMember(userAddress) handleParty(partyAddress) nonReentrant {
        require(verifySigner(PLATFORM_ADDRESS, messageHash(abi.encodePacked(partyAddress, userAddress, amount, n, nonce)), withdrawRSV),"Withdraw platform signature invalid");
        require(withdrawNonces[userAddress] == nonce, "Invalid nonce!");
        nonceIncrement(userAddress);

        if (tokenData.length != 0) {
            swapPlaceHolder(tokenData, userAddress);
        }

        require(amount <= tokenAddress.balanceOf(address(this)), "Enter the correct Amount");

        uint256 cut = getPlatformFee(amount);
        uint256 penalty = calculatePenalty(amount, n);

        totalDeposit = totalDeposit - ((memberBalance[userAddress] * withdrawPercentage) / 10**6);
        memberBalance[userAddress] = memberBalance[userAddress] - ((memberBalance[userAddress] * withdrawPercentage) / 10**6);

        tokenAddress.safeTransfer(PLATFORM_ADDRESS, cut + penalty);
        tokenAddress.safeTransfer(userAddress, amount - cut - penalty);
        emit WithdrawEvent(userAddress, withdrawPercentage, partyAddress, amount, cut, penalty);
    }

    function getPartyBalance() public view returns (uint256) {
        return tokenAddress.balanceOf(address(this));
    }

    /**
     * @dev Deposit Function
     * deposit function sents token to sc it self when triggred.
     * in order to trigger deposit function, user must be a member
     * you can see the modifier "onlyMember" inside deposit function
     * if the user is already on member list, then the function will be executed
     */
    function deposit(address partyAddress,address userAddress, uint256 amount) external onlyMember(userAddress) isAlive handleParty(partyAddress) {
        uint256 cut = getPlatformFee(amount);
        memberBalance[userAddress] = memberBalance[userAddress] + (amount-cut);
        totalDeposit = totalDeposit + (amount-cut);
        tokenAddress.safeTransferFrom(userAddress, address(this), amount);
        tokenAddress.safeTransferFrom(userAddress, PLATFORM_ADDRESS, cut);
        emit DepositEvent(userAddress, partyAddress, amount, cut);
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
    function joinParty(Sig memory joinRSV, address userAddress, address partyAddress, string memory userId, string memory joinPartyId, uint256 amount) external isAlive notAMember(userAddress) reqDeposit(amount) handleParty(partyAddress) {
        require(verifySigner(PLATFORM_ADDRESS, messageHash(abi.encodePacked(userAddress, partyAddress, joinPartyId)), joinRSV), "Transaction Signature Invalid" );
        require(!member[userAddress], "Member is already registered.");
        member[userAddress] = true;
        if (withdrawNonces[userAddress] == 0) {
            withdrawNonces[userAddress] = 1;
        }
        memberCount++;
        uint256 cut = getPlatformFee(amount);
        memberBalance[userAddress] = amount - cut;
        totalDeposit = totalDeposit + (amount - cut);
        tokenAddress.safeTransferFrom(userAddress, address(this), amount);
        tokenAddress.safeTransferFrom(userAddress, PLATFORM_ADDRESS, cut);
        emit JoinEvent(userAddress, partyAddress, joinPartyId, userId, amount, cut);
    }

    /**
     * @dev Leave Party Function
     *
     * leave party need validation using rsv, leave party will transfer the token based on how much weight of the user
     * and then set the user to false, so the user can't call the function that supposed to be called by member.
     * platform signature message :
     * - quittingMember:address
     * - addressWeight:address
     *
     */
    function leaveParty(address partyAddress, address quittingMember, uint256 n, SwapWithoutRSV[] memory tokenData, Sig memory leaveRSV) external payable onlyMember(quittingMember) handleParty(partyAddress) {
        require(verifySigner(PLATFORM_ADDRESS, messageHash(abi.encodePacked(partyAddress, quittingMember)), leaveRSV),"Withdraw platform signature invalid");
        uint256 balanceBeforeSwap = getPartyBalance();
        uint256 addressWeight = (memberBalance[quittingMember] * 10**6)/ totalDeposit;
        if (tokenData.length != 0) {
            swapPlaceHolder(tokenData, quittingMember);
        }
        uint256 balanceDiff = getPartyBalance() - balanceBeforeSwap;
        uint256 _userBalance = ((balanceBeforeSwap * addressWeight) / 10**6) + balanceDiff;
        uint256 cut = getPlatformFee(_userBalance);
        uint256 penalty = calculatePenalty(_userBalance, n);
        uint256 sent = _userBalance - cut - penalty;

        memberBalance[quittingMember] = 0;
        totalDeposit = totalDeposit - ((totalDeposit * addressWeight) / 10**6);

        member[quittingMember] = false;
        memberCount--;
        tokenAddress.safeTransfer(quittingMember, sent);
        tokenAddress.safeTransfer(PLATFORM_ADDRESS, cut + penalty);
        emit LeavePartyEvent(quittingMember, addressWeight, address(this), _userBalance,cut, penalty);
    }

    /**
     * @dev Kick Party Function
     *
     * Kick party need validation using rsv, leave party will transfer the token based on how much weight of the user
     * and then set the user to false, so the user can't call the function that supposed to be called by member.
     * platform signature message :
     * - quittingMember:address
     * - addressWeight:address
     */
    function kickParty(address partyAddress, address userAddress, address quittingMember, uint256 n, SwapWithoutRSV[] memory tokenData, Sig memory kickRSV) external payable onlyOwner(userAddress) isAlive handleParty(partyAddress) {
        require(verifySigner(PLATFORM_ADDRESS,messageHash(abi.encodePacked(partyAddress, quittingMember)), kickRSV),"Withdraw platform signature invalid");
        require(member[quittingMember], "The user you kick is not a member");
        uint256 balanceBeforeSwap = getPartyBalance();
        if (tokenData.length != 0) {
            swapPlaceHolder(tokenData, userAddress);
        }
        uint256 addressWeight = (memberBalance[userAddress] * 10**6)/ totalDeposit;
        uint256 _userBalance = ((balanceBeforeSwap * addressWeight) / 10**6) + (getPartyBalance() - balanceBeforeSwap);
        uint256 cut = getPlatformFee(_userBalance);
        uint256 penalty = calculatePenalty(_userBalance, n);
        uint256 sent = _userBalance - cut - penalty;

        memberBalance[quittingMember] = 0;
        totalDeposit = totalDeposit - ((totalDeposit * addressWeight)/10**6);

        member[quittingMember] = false;
        memberCount--;
        tokenAddress.safeTransfer(quittingMember, sent);
        tokenAddress.safeTransfer(PLATFORM_ADDRESS, cut + penalty);
        emit KickPartyEvent(quittingMember, addressWeight, address(this),  _userBalance, cut, penalty);
    }

    /**
     * @dev swapPlaceholder Function
     *
     * swapPlaceholder function is the function that handle the swap process in some function
     * - kickParty
     * - withdraw
     * - leaveParty
     */
    function swapPlaceHolder(SwapWithoutRSV[] memory tokenData, address sender)internal returns (uint256) {
        uint256 fee = 0;
        for (uint256 index = 0; index < tokenData.length; index++) {
            fee = getPlatformFee(tokenData[index].buyAmount);
            require(tokenData[index].sellAmount <= tokenData[index].sellTokenAddress.balanceOf(address(this)), "Balance not enough.");
            require(tokenData[index].sellTokenAddress.approve(tokenData[index].spender,type(uint256).max),"Approval invalid");
            (bool success, ) = tokenData[index].swapTarget.call{
                value: msg.value
            }(tokenData[index].swapCallData);
            require(success, "SWAP_CALL_FAILED");
            payable(sender).transfer(address(this).balance);
            tokenData[index].buyTokenAddress.safeTransfer(PLATFORM_ADDRESS, fee);
            emit Qoute0xSwap(tokenData[index].sellTokenAddress, tokenData[index].buyTokenAddress, tokenData[index].spender, tokenData[index].swapTarget, "SELL", tokenData[index].sellAmount, tokenData[index].buyAmount, fee);
        }
        return fee;
    }

    /**
     * @dev closeParty Function
     *
     * closeParty function will set the owner of the party to address(0) and set the party to death state.
     *
     */
    function closeParty(address partyAddress, address userAddress, Sig memory closeRSV) external payable onlyOwner(userAddress) isAlive handleParty(partyAddress) {
        require(verifySigner(PLATFORM_ADDRESS, messageHash(abi.encodePacked(partyAddress, userAddress)), closeRSV),"Withdraw platform signature invalid");
        renounceOwnership(userAddress);
        emit ClosePartyEvent(address(this), owner());
    }

    function calculatePenalty(uint256 _userBalance, uint256 n) private pure returns (uint256) {
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

    function nonceIncrement(address _userAddress) internal {
        withdrawNonces[_userAddress] = withdrawNonces[_userAddress] + 1;
    }

    modifier onlyMember(address _userAddress) {
        require(member[_userAddress], "User is not a member.");
        _;
    }
    modifier onlyOwner(address _userAddress) {
        require(owner() == _userAddress, "User is not party owner");
        _;
    }
    modifier notAMember(address _userAddress) {
        require(!member[_userAddress], "User already joined");
        _;
    }
    modifier isAlive() {
        require(owner() != address(0), "Party is dead");
        _;
    }
    modifier handleParty(address partyAddress) {
        require(partyAddress == address(this), "Party address is invalid.");
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

    function messageHash(bytes memory abiEncode)internal pure returns (bytes32)
    {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", keccak256(abiEncode)));
    }
    function owner() public view virtual returns (address){
        return _owner;
    }
    function renounceOwnership(address _userAddress) public virtual onlyOwner(_userAddress){
        _owner = address(0);
    }
    function transferOwnership(address newOwner, address _userAddress) public virtual onlyOwner(_userAddress){
        require(newOwner != address(0), "Ownable: new owner is the zero address.");
    }
    function verifySigner(address signer, bytes32 ethSignedMessageHash, Sig memory rsv) internal pure returns (bool)
    {
        return ECDSA.recover(ethSignedMessageHash, rsv.v, rsv.r, rsv.s ) == signer;
    }
    function getPlatformFee(uint256 amount) public pure returns (uint256){
        return(amount * 5) / 1000;
    }
}