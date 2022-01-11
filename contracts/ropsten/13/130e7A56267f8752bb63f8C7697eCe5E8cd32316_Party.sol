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

contract Party is Initializable {
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
    event DepositEvent(address caller, address partyAddress, uint256 amount, uint256 cut);
    event JoinEvent(address caller, address partyAddress, string joinPartyId, string userId, uint256 amount, uint256 cut);
    event CreateEvent(address caller, string partyName, string partyId, string ownerId);
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
    function init(uint256 minDeposit, uint256 maxDeposit, PartyInfo memory inputPartyInformation, bytes32 r, bytes32 s, uint8 v, IERC20 stableCoin, uint256 initialDeposit) external payable initializer {
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
                r,s,v
            ),
            "platform signature is invalid"
        );
        emit CreateEvent(inputPartyInformation.userAddress, inputPartyInformation.partyName, inputPartyInformation.idParty, inputPartyInformation.ownerId);

        if (withdrawNonces[msg.sender] == 0) {
            withdrawNonces[msg.sender] = 1;
        }
        
        member[inputPartyInformation.userAddress] = true;
        memberCount++;

        memberBalance[msg.sender] = initialDeposit - cut;
        totalDeposit = initialDeposit - cut;

        tokenAddress.safeTransferFrom(inputPartyInformation.userAddress, address(this), initialDeposit);
        tokenAddress.safeTransferFrom(inputPartyInformation.userAddress, PLATFORM_ADDRESS, cut);
        emit JoinEvent(inputPartyInformation.userAddress, address(this), inputPartyInformation.idParty, inputPartyInformation.ownerId, initialDeposit, cut);
    }

    function fillQuote(IERC20 sellTokenAddress, IERC20 buyTokenAddress, address spender, address payable swapTarget,bytes memory swapCallData, uint256 sellAmount, uint256 buyAmount, bytes32 r, bytes32 s, uint8 v) public isAlive onlyOwner payable {
        require(verifySigner(PLATFORM_ADDRESS, messageHash(abi.encodePacked(sellTokenAddress, buyTokenAddress, spender, swapTarget, sellAmount, buyAmount)),r,s,v), "Approve Signature Failed");
        uint256 fee = getPlatformFee(buyAmount);
        require(sellAmount <= sellTokenAddress.balanceOf(address(this)), "Balance not enough.");
        require(sellTokenAddress.approve(spender, type(uint256).max));
        (bool success, ) = swapTarget.call{value: msg.value}(swapCallData);
        require(success, "SWAP_CALL_FAILED");
        payable(msg.sender).transfer(address(this).balance);
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
     * TODO:
     * - add userAddress
     * - add nonce
     */
    function withdraw(address partyAddress, uint256 withdrawPercentage, uint256 amount, uint256 n, uint256 nonce, SwapWithoutRSV[] memory tokenData, bytes32 r, bytes32 s, uint8 v) external payable isAlive onlyMember handleParty(partyAddress) {
        require(verifySigner(PLATFORM_ADDRESS, messageHash(abi.encodePacked(partyAddress, msg.sender, amount, n, nonce)), r, s, v),"Withdraw platform signature invalid");
        require(withdrawNonces[msg.sender] == nonce, "Invalid nonce!");
        nonceIncrement();
        if (tokenData.length != 0) {
            swapPlaceHolder(tokenData);
        }
        require(amount <= tokenAddress.balanceOf(address(this)), "Enter the correct Amount");
        uint256 cut = getPlatformFee(amount);
        uint256 penalty = calculatePenalty(amount, n);
        uint256 sent = amount - cut - penalty;

        memberBalance[msg.sender] = memberBalance[msg.sender] - sent;
        totalDeposit = totalDeposit - sent;

        tokenAddress.safeTransfer(PLATFORM_ADDRESS, cut + penalty);
        tokenAddress.safeTransfer(msg.sender, sent);
        emit WithdrawEvent(msg.sender, withdrawPercentage, partyAddress, amount, cut, penalty);
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
    function deposit(address partyAddress, uint256 amount) external onlyMember isAlive handleParty(partyAddress) {
        uint256 cut = getPlatformFee(amount);
        memberBalance[msg.sender] = memberBalance[msg.sender] + (amount-cut);
        totalDeposit = totalDeposit + (amount-cut);
        tokenAddress.safeTransferFrom(msg.sender, address(this), amount);
        tokenAddress.safeTransferFrom(msg.sender, PLATFORM_ADDRESS, cut);
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
    function joinParty(bytes32 r, bytes32 s, uint8 v, address partyAddress, string memory userId, string memory joinPartyId, uint256 amount) external isAlive notAMember reqDeposit(amount) handleParty(partyAddress) {
        require(verifySigner(PLATFORM_ADDRESS, messageHash(abi.encodePacked(msg.sender, partyAddress, joinPartyId)), r, s, v), "Transaction Signature Invalid" );
        require(!member[msg.sender], "Member is already registered.");
        member[msg.sender] = true;
        if (withdrawNonces[msg.sender] == 0) {
            withdrawNonces[msg.sender] = 1;
        }
        memberCount++;
        uint256 cut = getPlatformFee(amount);
        memberBalance[msg.sender] = amount - cut;
        totalDeposit = totalDeposit + (amount - cut);
        tokenAddress.safeTransferFrom(msg.sender, address(this), amount);
        tokenAddress.safeTransferFrom(msg.sender, PLATFORM_ADDRESS, cut);
        emit JoinEvent(msg.sender, partyAddress, joinPartyId, userId, amount, cut);
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
     * TODO:
     * - Add partyAddress for validation, so the user can't use another party rsv.
     */
    function leaveParty(address partyAddress, address quittingMember, uint256 addressWeight, uint256 n, SwapWithoutRSV[] memory tokenData,bytes32 r, bytes32 s, uint8 v) external payable onlyMember handleParty(partyAddress) {
        require(verifySigner(PLATFORM_ADDRESS, messageHash(abi.encodePacked(partyAddress, quittingMember, addressWeight)), r, s, v),"Withdraw platform signature invalid");
        uint256 balanceBeforeSwap = getPartyBalance();
        if (tokenData.length != 0) {
            swapPlaceHolder(tokenData);
        }
        uint256 balanceDiff = getPartyBalance() - balanceBeforeSwap;
        uint256 _userBalance = ((balanceBeforeSwap * addressWeight) / 10**6) + balanceDiff;
        uint256 cut = getPlatformFee(_userBalance);
        uint256 penalty = calculatePenalty(_userBalance, n);
        uint256 sent = _userBalance - cut - penalty;
        memberBalance[msg.sender] = memberBalance[msg.sender] - sent;
        totalDeposit = totalDeposit - sent;
        member[msg.sender] = false;
        memberCount--;
        tokenAddress.safeTransfer(msg.sender, sent);
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
     *
     * TODO:
     * - Add partyAddress for validation, so the user can't use another party rsv.
     */
    function kickParty(address partyAddress, address quittingMember, uint256 addressWeight, uint256 n, SwapWithoutRSV[] memory tokenData, bytes32 r, bytes32 s, uint8 v) external payable onlyOwner isAlive handleParty(partyAddress) {
        require(verifySigner(PLATFORM_ADDRESS,messageHash(abi.encodePacked(partyAddress, quittingMember, addressWeight)),r,s,v),"Withdraw platform signature invalid");
        require(member[quittingMember], "The user you kick is not a member");
        uint256 balanceBeforeSwap = getPartyBalance();
        if (tokenData.length != 0) {
            swapPlaceHolder(tokenData);
        }
        uint256 _userBalance = ((balanceBeforeSwap * addressWeight) / 10**6) + (getPartyBalance() - balanceBeforeSwap);
        uint256 cut = getPlatformFee(_userBalance);
        uint256 penalty = calculatePenalty(_userBalance, n);
        uint256 sent = _userBalance - cut - penalty;
        
        memberBalance[msg.sender] = memberBalance[msg.sender] - sent;
        totalDeposit = totalDeposit - sent;

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
    function swapPlaceHolder(SwapWithoutRSV[] memory tokenData)internal returns (uint256) {
        uint256 fee = 0;
        for (uint256 index = 0; index < tokenData.length; index++) {
            fee = getPlatformFee(tokenData[index].buyAmount);
            require(tokenData[index].sellAmount <= tokenData[index].sellTokenAddress.balanceOf(address(this)), "Balance not enough.");
            require(tokenData[index].sellTokenAddress.approve(tokenData[index].spender,type(uint256).max),"Approval invalid");
            (bool success, ) = tokenData[index].swapTarget.call{
                value: msg.value
            }(tokenData[index].swapCallData);
            require(success, "SWAP_CALL_FAILED");
            payable(msg.sender).transfer(address(this).balance);
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
     * TODO:
     * - add partyAddress to message validation
     */
    function closeParty(address partyAddress, bytes32 r, bytes32 s, uint8 v) external payable onlyOwner isAlive handleParty(partyAddress) {
        require(verifySigner(PLATFORM_ADDRESS, messageHash(abi.encodePacked(partyAddress, msg.sender)),r, s, v),"Withdraw platform signature invalid");
        renounceOwnership();
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
    
    function nonceIncrement() internal {
        withdrawNonces[msg.sender] = withdrawNonces[msg.sender] + 1;
    }

    modifier onlyMember() {
        require(member[msg.sender], "User is not a member.");
        _;
    }
    modifier onlyOwner() {
        require(owner() == msg.sender, "User is not party owner");
        _;
    }
    modifier notAMember() {
        require(!member[msg.sender], "User already joined");
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
    function renounceOwnership() public virtual onlyOwner{
        _owner = address(0);
    }
    function transferOwnership(address newOwner) public virtual onlyOwner{
        require(newOwner != address(0), "Ownable: new owner is the zero address.");
    }
    function verifySigner(address signer, bytes32 ethSignedMessageHash, bytes32 r, bytes32 s, uint8 v) internal pure returns (bool) 
    {
        return ECDSA.recover(ethSignedMessageHash, v, r, s ) == signer;
    }
    function getPlatformFee(uint256 amount) internal pure returns (uint256){
        return(amount * 5) / 1000;
    }
}