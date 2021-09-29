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

//TODO: Remove calculateWeight

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

    event DepositEvent(
        address caller,
        address partyAddress,
        uint256 amount,
        uint256 cut
    );

    event JoinEvent(
        address caller,
        address partyAddress,
        string joinPartyId,
        string userId,
        uint256 amount,
        uint256 cut
    );

    event CreateEvent(
        address caller,
        string partyName,
        string partyId,
        string ownerId
    );

    event ApprovePayerEvent(string proposalId, address[] payers);

    event WithdrawEvent(
        address caller,
        address partyAddress,
        uint256 amount,
        uint256 cut,
        uint256 penalty
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
        uint256 weight,
        address partyAddress,
        uint256 sent,
        uint256 cut,
        uint256 penalty
    );

    event ClosePartyEvent(
        address partyAddress,
        address ownerAddress
    );

    event Qoute0xSwap(
        IERC20 sellTokenAddress,
        IERC20 buyTokenAddress,
        address spender,
        address swapTarget,
        string transactionType,
        uint256 sellAmount,
        uint256 buyAmount,
        uint256 fee
    );

    struct Sig {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

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
        IERC20 buyTokenAddress;
        IERC20 sellTokenAddress;
        address spender;
        address payable swapTarget;
        bytes swapCallData;
        uint256 sellAmount;
        uint256 buyAmount;
        Sig inputApproveRSV;
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

    function fillQuote(
        IERC20 sellTokenAddress,
        IERC20 buyTokenAddress,
        address spender,
        address payable swapTarget,
        bytes memory swapCallData,
        uint256 sellAmount,
        uint256 buyAmount,
        Sig memory inputApproveRSV
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
                inputApproveRSV
            ),
            "Approve Signature Failed"
        );
        uint256 fee = (buyAmount * 5) / 1000;
        uint256 outAmount = sellAmount;
        require(
            outAmount <= sellTokenAddress.balanceOf(address(this)),
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
        Sig memory withdrawRSV
    ) external payable isAlive onlyMember {
        require(
            verifySigner(
                PLATFORM_ADDRESS,
                messageHash(abi.encodePacked(partyAddress, amount, n)),
                withdrawRSV
            ),
            "Withdraw platform signature invalid"
        );
        uint256 fee = 0;
        for (uint256 index = 0; index < tokenData.length; index++) {
            fee = (tokenData[index].buyAmount * 5) / 1000;
            uint256 outAmount = tokenData[index].sellAmount;
            require(
                outAmount <=
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
        require(
            amount <= token.balanceOf(address(this)),
            "Enter the correct Amount"
        );
        uint256 cut = (amount * 5) / 1000; // 1000 * 100000 = 100000000
        uint256 penalty;
        if (n != 0) {
            uint256 _temp = 17 * 10**8 + (n - 1) * 4160674157; //dikali 10 ** 10
            _temp = (_temp * 10**6) / 10**10;
            penalty = (amount * _temp) / 10**8;
        } else {
            penalty = 0;
        }
        uint256 sent = amount - cut - penalty;
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
        Sig memory inputJoinPartyPlatformRSV,
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
                inputJoinPartyPlatformRSV
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

    /**
     * @dev Create Proposal Function
     * create proposal function is for member that want to make a proposal for NFT
     * or other purposes. ONLY FOR DEMOCRACY
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

    function leaveParty(
        address quittingMember,
        uint256 addressWeight,
        uint256 n,
        SwapWithoutRSV[] memory tokenData,
        Sig memory leavePartyRSV
    ) external payable onlyMember isAlive {
        require(
            verifySigner(
                PLATFORM_ADDRESS,
                messageHash(abi.encodePacked(quittingMember, addressWeight)),
                leavePartyRSV
            ),
            "Withdraw platform signature invalid"
        );
        uint256 fee = 0;
        for (uint256 index = 0; index < tokenData.length; index++) {
            fee = (tokenData[index].buyAmount * 5) / 1000;
            uint256 outAmount = tokenData[index].sellAmount;
            require(
                outAmount <=
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

        uint256 _tempBalance = (getPartyBalance() * addressWeight) / 10**6;
        for (uint256 index = 0; index < memberList.length; index++) {
            if (memberList[index] == quittingMember) {
                memberList[index] = memberList[memberList.length - 1];
                memberList.pop();
                break;
            }
        }
        uint256 cut = (_tempBalance * 5) / 1000; // 1000 * 100000 = 100000000
        uint256 penalty;
        if (n != 0) {
            uint256 _temp = 17 * 10**8 + (n - 1) * 4160674157; //dikali 10 ** 10
            _temp = (_temp * 10**6) / 10**10;
            penalty = (_tempBalance * _temp) / 10**8;
        } else {
            penalty = 0;
        }
        uint256 sent = _tempBalance - cut - penalty;
        member[msg.sender] = false;
        token.safeTransfer(msg.sender, sent);
        token.safeTransfer(PLATFORM_ADDRESS, cut + penalty);
        emit LeavePartyEvent(quittingMember, addressWeight, address(this), sent, cut, penalty);
    }

    function closeParty(
        Weight[] memory weightArray,
        SwapWithoutRSV[] memory tokenData,
        Sig memory closePartyRSV
    ) external payable onlyOwner isAlive {
        require(
            verifySigner(
                PLATFORM_ADDRESS,
                messageHash(abi.encodePacked(msg.sender)),
                closePartyRSV
            ),
            "Withdraw platform signature invalid"
        );
        uint256 fee = 0;
        for (uint256 index = 0; index < tokenData.length; index++) {
            fee = (tokenData[index].buyAmount * 5) / 1000;
            uint256 outAmount = tokenData[index].sellAmount;
            require(
                outAmount <=
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
            token.safeTransfer(PLATFORM_ADDRESS, fee);
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
        address _temp = OWNER;
        OWNER = address(0x0);
        uint256 x = getPartyBalance();
        for (uint256 index = 0; index < weightArray.length; index++) {
            uint256 value = ((weightArray[index].weightPercentage * x) / 10**6);
            fee = (value * 5) / 1000;
            token.safeTransfer(weightArray[index].weightAddress, value - fee);
            token.safeTransfer(PLATFORM_ADDRESS, fee);
        }
        emit ClosePartyEvent(address(this), _temp);
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