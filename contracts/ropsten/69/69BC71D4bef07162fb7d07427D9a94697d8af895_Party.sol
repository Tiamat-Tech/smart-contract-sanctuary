// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

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
    IERC20 token = IERC20(0x07865c6E87B9F70255377e024ace6630C1Eaa37F);
    address private OWNER; //Dont use immutable, becaue the value will be write to the bytecode
    address private immutable PLATFORMADDRESS;
    mapping(address => bool) private member;
    mapping(address => uint256) public balance;
    address[] public memberList;
    uint256 public balanceParty;
    mapping(string => address payable) public registeredProposal; //pointer id value address proposer, change to string because of uuid

    event DepositEvent(
        address caller,
        address partyAddress,
        uint256 amount
    );

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
        uint256 amount
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

    struct Sig {
        bytes32 r;
        bytes32 s;
        uint8 v;
    }

    event ProfitDepositEvent(
        uint256 received,
        address[] payers
    );

    struct PartyInfo {
        string idParty;
        string ownerId;
        address userAddress;
        address platformAddress;
        string typeP;
        string partyName;
        bool isPublic;
    }

    struct RangeDepth {
        uint256 minDeposit;
        uint256 maxDeposit;
    }

    RangeDepth rangeDEP;

    /**
     * @dev Create Party Message Combination
     * platform signature message :
     *  -  idParty:string
     *  -  userAddress:address
     *  -  platformAddress:address
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
        PLATFORMADDRESS = inputPartyInformation.platformAddress;
        //platform verification purpose
        require(
            verifySigner(
                inputPartyInformation.platformAddress,
                messageHash(
                    abi.encodePacked(
                        inputPartyInformation.idParty,
                        inputPartyInformation.userAddress,
                        inputPartyInformation.platformAddress,
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
    function calculateWeight(address user, uint256 nonPayersToken)
        public
        view
        returns (uint256)
    {
        if (balance[user] <= 0) return 0;
        return ((balance[user] * 10**4) /
            (token.balanceOf(address(this)) - nonPayersToken));
    }

    /**
     * @dev Withdraw Function
     * Withdraw function is for the user that want their money back.
     */
    function withdraw(address partyAddress, uint256 amount) public onlyMember {
        require(
            amount <= token.balanceOf(address(this)),
            "Enter the correct Amount"
        );
        require(amount <= balance[msg.sender]);
        uint256 cut = amount * 5 / 1000;
        balance[msg.sender] -= amount;
        balanceParty -= amount;
        token.safeTransfer(PLATFORMADDRESS, cut);
        token.safeTransfer(msg.sender, amount - cut);
        emit WithdrawEvent(msg.sender, partyAddress, amount);
    }

    function getPartyBalance() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function checkDifferenceInBalance() public view returns (int) {
        return int(getPartyBalance()) - int(balanceParty);
    }

    /**
     * @dev Deposit Function
     * deposit function sents token to sc it self when triggred.
     * in order to trigger deposit function, user must be a member
     * you can see the modifier "onlyMember" inside deposit function
     * if the user is already on member list, then the function will be executed
     */
    function deposit(
        address partyAddress,
        uint256 amount
    ) public {

        uint256 cut = amount * 5 / 1000;

        token.safeTransferFrom(msg.sender, address(this), amount);
        token.safeTransferFrom(msg.sender, PLATFORMADDRESS, cut);
        balance[msg.sender] += amount;
        balanceParty += amount;
        emit DepositEvent(
            msg.sender, partyAddress, amount
        );
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
    ) public notAMember reqDeposit(amount) {
        require(
            verifySigner(
                PLATFORMADDRESS,
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
        token.safeTransferFrom(msg.sender, address(this), amount);
        balance[msg.sender] = balance[msg.sender] + amount;
        balanceParty += amount;
        emit JoinEvent(
            msg.sender,
            partyAddress,
            joinPartyId,
            userId
        );
    }

    //For Debug Allowance Value
    function getAllowance() public view returns (uint256) {
        return token.allowance(msg.sender, address(this));
    }

    function getSummary()
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            address
        )
    {
        return (
            rangeDEP.minDeposit,
            rangeDEP.maxDeposit,
            getPartyBalance(),
            OWNER
        );
    }

    function getMemberList() external view returns (address[] memory) {
        return memberList;
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
    ) external onlyMember {
        require(
            registeredProposal[proposalId] == address(0),
            "Proposal ID already Exist"
        );
        require(
            verifySigner(
                PLATFORMADDRESS,
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

    /**
     * @dev Approve function
     * Approve function approves a certain proposal when triggered
     * the function then will distribute the cost according to members weight
     *
     * #Known Bug:
     * function amount - calculateWeight, total balanceUser not sync with total balance party
     *
     */
    function approve(
        string memory proposalId,
        address payable recipient,
        uint256 amount
    ) external onlyOwner {
        require(
            recipient == registeredProposal[proposalId],
            "Invalid Recipient"
        );
        require(
            registeredProposal[proposalId] != payable(address(0)),
            "Proposal already approved"
        );
        uint256 sent = 0;
        for (uint256 index = 0; index < memberList.length; index++) {
            uint256 userWeight = (amount *
                calculateWeight(memberList[index], 0)) / 10**4;
            balance[memberList[index]] =
                balance[memberList[index]] -
                (userWeight);
            sent = sent + userWeight;
        }
        uint cut = amount * 5 / 1000;
        registeredProposal[proposalId] = payable(address(0));
        balanceParty -= sent;
        token.safeTransfer(PLATFORMADDRESS, cut);
        token.safeTransfer(recipient, sent - cut);
        emit ApproveEvent(proposalId, msg.sender, recipient, amount, sent);
    }

    /**
     * @dev Profit Deposit Function
     * for giving the profits back to the party, still not being used because its not clear yet
     * if the process will use manual transfer or using the system (Smart Contract).
     */
    function profitDeposit (uint256 amount, address[] memory nonPayers) public {
        uint256 nonPayersToken = 0;
        for(uint256 i = 0; i < nonPayers.length; i++){
            nonPayersToken = nonPayersToken + balance[nonPayers[i]];
        }
        uint256 payersLength = memberList.length - nonPayers.length;
        address[] memory payers = new address[](payersLength);
        address[] memory _tempArray = memberList;
        // delete every element on _tempArray that exist on nonPayers, _tempArray will be checked per indexed element
        for(uint256 i = 0; i < _tempArray.length; i++){
            for(uint256 j=0; j < nonPayers.length; j++){
                if(keccak256(abi.encodePacked(_tempArray[i])) == keccak256(abi.encodePacked(nonPayers[j]))){
                    delete _tempArray[i];
                    break;
                }
            }
        }
        // populate payers array with _tempArray
        uint256 _temp = 0;
        for(uint256 i = 0; i < memberList.length; i++){
            if(keccak256(abi.encodePacked(_tempArray[i])) == keccak256(abi.encodePacked(memberList[i]))){
                payers[_temp] = memberList[i];
                _temp++;
            }
            if(payersLength == _temp) break;
        }
        // distribute the amount to the payers
        uint256 _receive = 0;
        for(uint i =0; i < payers.length; i++){
            uint256 userWeight = (amount *
                calculateWeight(payers[i], nonPayersToken)) / 10**4;
            balance[payers[i]] =  balance[payers[i]] + userWeight;
            _receive += userWeight;
        }
        balanceParty += _receive;
        token.safeTransferFrom(msg.sender, address(this), _receive);
        emit ProfitDepositEvent(_receive, payers);
    // emit profit_event(payers, nonPayers, amount, tokenTransferStatus);
    }

    function leaveParty(address quittingMember) public onlyMember {
        uint256 _tempBalance = balance[quittingMember];
        balance[quittingMember] = 0;
        for (uint256 index = 0; index < memberList.length; index++) {
            if (memberList[index] == quittingMember) {
                memberList[index] = memberList[memberList.length - 1];
                memberList.pop();
                break;
            }
        }
        member[msg.sender] = false;
        token.safeTransfer(msg.sender, _tempBalance);
        balanceParty -= _tempBalance;
        emit LeavePartyEvent(
            quittingMember,
            balance[quittingMember],
            address(this)
        );
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
    ) private pure returns (bool) {
        return ECDSA.recover(ethSignedMessageHash, inputRSV.v, inputRSV.r, inputRSV.s) == signer;
    }
}