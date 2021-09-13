// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// bisa pakai safeMath openzeppelin

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

contract Party {
    using SafeERC20 for IERC20;
    // Dummy USDC = 0xfD1e0d4662Ef8Ab1Ff675Da33b8be58A39436261
    // Ropsten USDC = 0x07865c6E87B9F70255377e024ace6630C1Eaa37F
    IERC20 token = IERC20(0x07865c6E87B9F70255377e024ace6630C1Eaa37F);
    address private OWNER; //Dont use immutable, becaue the value will be write to the bytecode
    address private immutable PLATFORM_ADDRESS;
    mapping(address => bool) private member;
    mapping(address => uint256) public balance;
    mapping(address => uint256) public weight;
    address[] public memberList;
    uint256 public balanceParty;
    mapping(string => address payable) public registeredProposal; //pointer id value address proposer, change to string because of uuid

    event DepositEvent(address caller, address partyAddress, uint256 amount);

    event JoinEvent(
        address caller,
        address partyAddress,
        string joinPartyId,
        string userId
    );

    event CreateEvent(
        address caller,
        string partyName,
        string partyId,
        string ownerId
    );

    event ApproveEvent(
        string proposalId,
        address sender,
        address recipient,
        uint256 value,
        uint256 sent
    );

    event ApprovePayerEvent(string proposalId, address[] payers);

    event ProfitEvent(address[] payers, address[] nonPayers, uint256 amount);

    event WithdrawEvent(
        address caller,
        address partyAddress,
        uint256 amount,
        uint256 log1,
        uint256 log2
    );

    event CreateProposalEvent(
        string proposalId,
        string title,
        uint256 amount,
        string partyId,
        address userAddress
    );

    event LeavePartyEvent(
        address userAddress,
        uint256 amount,
        address partyAddress
    );

    event Qoute0xSwap (
        IERC20 sellTokenAddress,
        address spender,
        address swapTarget,
        string transactionType
    );

    event ProfitDepositEvent(uint256 received, address[] payers);
    
    struct Sig {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    event Log(
        uint256 log1,
        uint256 log2,
        uint256 log3,
        uint256 log4,
        uint256 log5,
        uint256 log6
    );

    event Log2(
        IERC20 log1,
        address log2,
        address log3,
        uint256 log4,
        Sig log5
    );

    struct PartyInfo {
        string idParty;
        string ownerId;
        address userAddress;
        address platform_Address;
        string typeP;
        string partyName;
        bool isPublic;
    }

    struct RangeDepth {
        uint256 minDeposit;
        uint256 maxDeposit;
    }

    struct Swap {
        IERC20 sellAddress;
        address spender;
        address payable swapTarget;
        bytes swapCallData;
        uint256 amount;
        Sig inputApproveRSV;
    }

    RangeDepth public rangeDEP;
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
    constructor(
        RangeDepth memory inputRangeDep,
        PartyInfo memory inputPartyInformation,
        Sig memory inputPlatformRSV
    ) {
        rangeDEP = inputRangeDep;
        OWNER = msg.sender;
        PLATFORM_ADDRESS = inputPartyInformation.platform_Address;
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
                inputPlatformRSV
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

    /**
     * @dev Calculate Weight Implementation
     * To calculate the weight after the transaction, this is to ensure that
     * the user have the right weight based on how many deposit the user made.
     *
     * In order to smart contract to be able to calculate percentage or weight of the user,
     * user's balance must be multiplied by 10**4 when calculating the percentage. Then when the
     * percentage is needed for distribution calculation (see approve or profit_deposit function)
     * it will be divided again by 10**4 to restore the same number.
     */
    function calculateWeight(
        uint256 newBalanceParty,
        address sender,
        uint256 typeTransaction
    ) internal isAlive {
        uint256 _temp = 0;
        for (uint256 index = 0; index < memberList.length; index++) {
            if (weight[memberList[index]] == 0) {
                weight[memberList[index]] =
                    ((newBalanceParty - getPartyBalance()) * 10**6) /
                    newBalanceParty;
                _temp += weight[memberList[index]];
            } else {
                if (memberList[index] == sender) {
                    if (typeTransaction == 1) {
                        //deposit
                        require(newBalanceParty > getPartyBalance(), "newBalanceParty is smaller than the current party balance");
                        uint256 normalizeDeposit = (weight[memberList[index]] *
                            getPartyBalance()) / 10**6;
                        uint256 newValue = normalizeDeposit +
                            (newBalanceParty - getPartyBalance());
                        weight[memberList[index]] =
                            (newValue * 10**6) /
                            newBalanceParty;
                        _temp += weight[memberList[index]];
                        emit Log(
                            typeTransaction,
                            newBalanceParty,
                            normalizeDeposit,
                            newValue,
                            weight[memberList[index]],
                            getPartyBalance()
                        );
                    }
                    if (typeTransaction == 2) {
                        //withdraw
                        require(newBalanceParty < getPartyBalance(), "newBalanceParty is bigger than the current party balance");
                        uint256 normalizeWithdraw = (weight[memberList[index]] *
                            getPartyBalance()) / 10**6;
                        uint256 differenceValue = normalizeWithdraw -
                            (getPartyBalance() - newBalanceParty);
                        weight[memberList[index]] =
                            (differenceValue * 10**6) /
                            newBalanceParty;
                        _temp += weight[memberList[index]];
                        emit Log(
                            typeTransaction,
                            newBalanceParty,
                            normalizeWithdraw,
                            differenceValue,
                            weight[memberList[index]],
                            getPartyBalance()
                        );
                    }
                } else {
                    uint256 normalize = (weight[memberList[index]] *
                        getPartyBalance());
                    weight[memberList[index]] = normalize / newBalanceParty;
                    _temp += weight[memberList[index]];
                }
            }
        }
        // If the deviation are getting too big
        _temp = 1000000 - _temp;
        if (_temp > 100000) {
            for (uint256 index = 0; index < memberList.length; index++) {
                weight[memberList[index]] += _temp / memberList.length;
            }
        }

        balanceParty = newBalanceParty;
    }

    function fillQuote(
        IERC20 sellTokenAddress,
        address spender,
        address payable swapTarget,
        bytes memory swapCallData,
        uint256 amount,
        Sig memory inputApproveRSV
    ) public payable onlyOwner {
        require(
            verifySigner(
                PLATFORM_ADDRESS,
                messageHash(
                    abi.encodePacked(
                        sellTokenAddress,
                        spender,
                        swapTarget,
                        amount
                    )
                ),
                inputApproveRSV
            ),
            "Approve Signature Failed"
        );
        require(sellTokenAddress.approve(spender, type(uint256).max));
        (bool success, ) = swapTarget.call{value: msg.value}(swapCallData);
        require(success, "SWAP_CALL_FAILED");
        payable(msg.sender).transfer(address(this).balance);
        sellTokenAddress.approve(spender, 0);
        emit Log2(sellTokenAddress, spender, swapTarget, amount, inputApproveRSV);
        if(sellTokenAddress == token) {
            emit Qoute0xSwap(sellTokenAddress, spender, swapTarget, "BUY");
        } else {
            emit Qoute0xSwap(sellTokenAddress, spender, swapTarget, "SELL");
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
        uint256 newBalanceParty,
        Swap[] memory tokenData
    ) external payable isAlive onlyMember {
        for (uint256 index = 0; index < tokenData.length; index++) {
            fillQuote(
                tokenData[index].sellAddress,
                tokenData[index].spender,
                tokenData[index].swapTarget,
                tokenData[index].swapCallData,
                tokenData[index].amount,
                tokenData[index].inputApproveRSV
            );
        }
        require(
            amount <= token.balanceOf(address(this)),
            "Enter the correct Amount"
        );
        uint256 cut = (amount * 5) / 1000;
        uint256 penalty;
        if (n != 0) {
            uint256 _temp = 17 * 10**8 + (n - 1) * 4160674157; //dikali 10 ** 10
            _temp = (_temp * 10**6) / 10**10;
            penalty = (amount * _temp) / 10**8;
        } else {
            penalty = 0;
        }
        uint256 sent = amount - cut - penalty;
        calculateWeight(newBalanceParty - (cut + penalty), msg.sender, 2);
        token.safeTransfer(PLATFORM_ADDRESS, cut + penalty);
        token.safeTransfer(msg.sender, sent);
        emit WithdrawEvent(msg.sender, partyAddress, sent, cut, penalty);
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
     * //TODO: signature deposit
     */
    function deposit(
        address partyAddress,
        uint256 amount,
        uint256 newBalanceParty
    ) external isAlive {
        uint256 cut = (amount * 5) / 1000;
        calculateWeight(newBalanceParty - cut, msg.sender, 1);
        token.safeTransferFrom(msg.sender, address(this), amount);
        token.safeTransferFrom(msg.sender, PLATFORM_ADDRESS, cut);
        emit DepositEvent(msg.sender, partyAddress, amount);
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
        Sig memory inputJoinPartyPlatformRSV,
        address partyAddress,
        string memory userId,
        string memory joinPartyId,
        uint256 amount,
        uint256 newBalanceParty
    ) external isAlive notAMember reqDeposit(amount) {
        require(
            verifySigner(
                PLATFORM_ADDRESS,
                messageHash(
                    abi.encodePacked(msg.sender, partyAddress, joinPartyId)
                ),
                inputJoinPartyPlatformRSV
            ),
            "Transaction Signature Invalid"
        );
        require(!member[msg.sender], "Member is already registered.");
        memberList.push(msg.sender);
        member[msg.sender] = true;
        uint256 cut = (amount * 5) / 1000;
        uint256 received = amount - cut;
        calculateWeight(newBalanceParty - cut, msg.sender, 1);
        token.safeTransferFrom(msg.sender, address(this), received);
        token.safeTransferFrom(msg.sender, PLATFORM_ADDRESS, cut);
        emit JoinEvent(msg.sender, partyAddress, joinPartyId, userId);
    }

    /**
     * @dev Create Proposal Function
     * create proposal function is for member that want to make a proposal for NFT
     * or other purposes.
     */
    function createProposal(
        string memory title,
        uint256 amount,
        string memory partyId,
        string memory proposalId,
        address recipient,
        Sig memory inputCreateProposalRSV
    ) external onlyMember isAlive {
        require(
            registeredProposal[proposalId] == address(0),
            "Proposal ID already Exist"
        );
        require(
            verifySigner(
                PLATFORM_ADDRESS,
                messageHash(
                    abi.encodePacked(partyId, address(this), proposalId)
                ),
                inputCreateProposalRSV
            )
        );
        require(amount <= getPartyBalance(), "Amount Exceed Party Balance");
        registeredProposal[proposalId] = payable(recipient);
        emit CreateProposalEvent(
            proposalId,
            title,
            amount,
            partyId,
            msg.sender
        );
    }

    function leaveParty(address quittingMember) external onlyMember isAlive {
        uint256 _tempBalance = getPartyBalance() * weight[quittingMember] / 10 ** 6;
        balance[quittingMember] = 0;
        for (uint256 index = 0; index < memberList.length; index++) {
            if (memberList[index] == quittingMember) {
                memberList[index] = memberList[memberList.length - 1];
                memberList.pop();
                break;
            }
        }
        uint256 cut = (_tempBalance * 5) / 1000;
        uint256 sent = _tempBalance - cut;
        member[msg.sender] = false;
        token.safeTransfer(msg.sender, sent);
        token.safeTransfer(PLATFORM_ADDRESS, cut);
        emit LeavePartyEvent(
            quittingMember,
            balance[quittingMember],
            address(this)
        );
    }

    function closeParty() external onlyOwner isAlive {
        OWNER = address(0x0);
        uint256 x = getPartyBalance();
        for (uint256 index = 0; index < memberList.length; index++) {
            uint256 _temp = (weight[memberList[index]] * x) / 10**6;
            token.safeTransfer(memberList[index], _temp);
        }
    }

    modifier onlyOwner() {
        require(msg.sender == OWNER, "not owner");
        _;
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
        require(OWNER != address(0x0), "Party is dead");
        _;
    }

    /**
     * @dev reqDeposit function
     * to ensure the deposit value is correct and doesn't exceed the specified limit
     */
    modifier reqDeposit(uint256 amount) {
        require(!(amount < rangeDEP.minDeposit), "Deposit is not enough");
        require(!(amount > rangeDEP.maxDeposit), "Deposit is too many");
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

    function verifySigner(
        address signer,
        bytes32 ethSignedMessageHash,
        Sig memory inputRSV
    ) internal pure returns (bool) {
        return
            ECDSA.recover(
                ethSignedMessageHash,
                inputRSV.v,
                inputRSV.r,
                inputRSV.s
            ) == signer;
    }
}