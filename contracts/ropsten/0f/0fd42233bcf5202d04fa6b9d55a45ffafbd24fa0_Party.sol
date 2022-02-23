// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./PartyInitializable.sol";
import "./PartyStorage.sol";

// Interfaces
import "./interfaces/IParty.sol";

// Libraries
import "./libraries/Announcements.sol";
import "./libraries/JoinRequests.sol";
import "./libraries/SharedStructs.sol";
import "./libraries/SignatureHelpers.sol";

// @openzeppelin/contracts-upgradeable
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "hardhat/console.sol";

error NotMember(); // "User is not a member"
error AlreadyMember(); // "User is already a member"
error DepositNotEnough(); // "Deposit is not enough"
error DepositExceeded(); // "Deposit exceeds maximum required"
error PartyClosed(); // "Party is closed"
error UserBalanceNotEnough(); // "User balance is not enough"
error InvalidTokenIndex(); // "Token index is not the sellToken"
error OwnerNotKickable(); // "Cannot kick yourself"
error InvalidMemberIndex(); // "Member index is invalid"
error FailedAproveReset(); // "Failed approve reset"
error FailedAprove(); // "Failed approving sellToken"
error ZeroXFail(); // "SWAP_CALL_FAILED"
error InvalidSignature(); // "Invalid approval signature"
error InvalidSwap(); // "Only one swap at a time"
error AlreadyRequested(); // "User has already requested to join"
error AlreadyHandled(); // "Request already handled"
error NeedsInvitation(); // "User needs invitation to join private party"

contract Party is PartyInitializable, PartyStorage, IParty {
    /***************
    LIBRARIES
    ***************/
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /***************
    EVENTS
    ***************/
    /// @dev inherited from IPartyEvents

    /***************
    MODIFIERS
    ***************/
    modifier onlyMember() {
        if (!member[msg.sender]) revert NotMember();
        _;
    }
    modifier notMember() {
        if (member[msg.sender]) revert AlreadyMember();
        _;
    }
    modifier handleDeposit(uint256 amount) {
        if (amount < partyInfo.minDeposit) revert DepositNotEnough();
        if (partyInfo.maxDeposit > 0 && amount > partyInfo.maxDeposit)
            revert DepositExceeded();
        _;
    }
    modifier isAlive() {
        if (owner() == address(0)) revert PartyClosed();
        _;
    }
    modifier joiningAllowed() {
        if (!partyInfo.isPublic && !joinRequests.accepted[msg.sender])
            revert NeedsInvitation();
        _;
    }

    /***************
    INITIALIZATION
    ***************/
    // /// @custom:oz-upgrades-unsafe-allow constructor
    // constructor() initializer {}

    /**
     * @notice Creates a party
     * @dev Called by the PartyFactory after minimal cloning the new party
     * @param creator The address of the party creator
     * @param _partyInfo Struct that contains the party information
     * @param initialDeposit The initial deposit of the creator
     * @param dAsset The address of the denomination asset
     * @param dAssetDecimals The decimals of the denomination asset
     * @param platform The platform collector address
     * @param platformFee The platform collector fee to be taken
     */
    function initialize(
        address creator,
        SharedStructs.PartyInfo memory _partyInfo,
        uint256 initialDeposit,
        address dAsset,
        uint256 dAssetDecimals,
        address platform,
        uint256 platformFee
    ) external payable initializer {
        // Init functions
        __ERC20_init(partyInfo.name, "PARTY");
        __ERC20Burnable_init();
        __ReentrancyGuard_init();
        __Ownable_init();

        // Set Factory
        factory = msg.sender;

        // Safe init upgrade
        if (creator != address(0)) {
            // Party ownership
            transferOwnership(creator);

            // Platform
            PLATFORM_ADDRESS = platform;
            PLATFORM_FEE = platformFee;

            // Party info
            partyInfo = _partyInfo;

            // Set DA token
            mainToken = dAsset;
            DA_DECIMALS = dAssetDecimals;
            tokens.push(mainToken);
            token[mainToken] = true;

            // Add member
            member[creator] = true;
            members.push(creator);

            // Mint Party tokens
            uint256 mintedPT = (initialDeposit / 10**DA_DECIMALS) *
                10**decimals();
            _mint(creator, mintedPT);

            // Emit PartyCreated event
            emit PartyCreated(
                creator,
                _partyInfo.name,
                _partyInfo.isPublic,
                dAsset,
                _partyInfo.minDeposit,
                _partyInfo.maxDeposit,
                mintedPT
            );
        }
    }

    /***************
    PARTY FUNCTIONS
    ***************/
    /// @inheritdoc IPartyActions
    function joinParty(
        uint256 amount,
        SharedStructs.Allocation memory allocation,
        SignatureHelpers.Sig memory approval,
        uint256 ts
    ) external payable override notMember joiningAllowed nonReentrant isAlive {
        // Add user as member
        member[msg.sender] = true;
        members.push(msg.sender);

        // Deposit, collect fees and mint party tokens
        (uint256 fee, uint256 mintedPT) = mintPartyTokens(
            amount,
            allocation,
            approval,
            ts
        );

        // Emit Join event
        emit Join(msg.sender, address(this), mainToken, amount, fee, mintedPT);
    }

    /// @inheritdoc IPartyMemberActions
    function deposit(
        uint256 amount,
        SharedStructs.Allocation memory allocation,
        SignatureHelpers.Sig memory approval,
        uint256 ts
    ) external payable override onlyMember nonReentrant isAlive {
        // console.log("on deposit method: amount is %s", amount);
        // Deposit, collect fees and mint party tokens
        (uint256 fee, uint256 mintedPT) = mintPartyTokens(
            amount,
            allocation,
            approval,
            ts
        );

        // Emit Deposit event
        emit Deposit(
            msg.sender,
            address(this),
            mainToken,
            amount,
            fee,
            mintedPT
        );
    }

    /// @inheritdoc IPartyMemberActions
    function withdraw(uint256 amountPT)
        external
        payable
        override
        onlyMember
        nonReentrant
    {
        // Withdraw, collect fees and burn party tokens
        (
            uint256[] memory amounts,
            uint256[] memory fees,
            uint256 burnedPT
        ) = redeemPartyTokens(amountPT, msg.sender);

        // Emit Withdraw event
        emit Withdraw(
            msg.sender,
            address(this),
            tokens,
            amounts,
            fees,
            burnedPT
        );
    }

    /// @inheritdoc IPartyOwnerActions
    function swapToken(
        SharedStructs.Allocation memory allocation,
        uint256 sellTokenIndex, // Off-chain: determine the sellTokenIndex from tokens array
        SignatureHelpers.Sig memory approval,
        uint256 ts
    ) external payable override onlyOwner nonReentrant {
        // console.log("sellTokenIndex %s", sellTokenIndex);
        if (allocation.sellTokens.length != 1) revert InvalidSwap();

        if (tokens[sellTokenIndex] != allocation.sellTokens[0])
            revert InvalidTokenIndex();

        // -> Validate authenticity of assets allocation
        // console.log("Pre validate authenticity of asset allocation");
        if (
            !SignatureHelpers.isValidSig(
                PLATFORM_ADDRESS,
                SignatureHelpers.getMessageHash(
                    abi.encodePacked(
                        address(this),
                        ts,
                        allocation.sellTokens,
                        allocation.sellAmounts,
                        allocation.buyTokens,
                        allocation.spenders,
                        allocation.swapsTargets
                    )
                ),
                approval,
                ts
            )
        ) {
            revert InvalidSignature();
        }
        // console.log("Post validate authenticity of assets allocation");

        // Fill 0x Quote
        SharedStructs.FilledQuote memory filledQuote = fillQuote(
            allocation.sellTokens[0],
            allocation.sellAmounts[0],
            allocation.buyTokens[0],
            allocation.spenders[0],
            allocation.swapsTargets[0],
            allocation.swapsCallData[0]
        );

        // console.log("soldAmount %s", filledQuote.soldAmount);
        // console.log("boughtAmount %s", filledQuote.boughtAmount);
        // console.log("initialSellBalance %s", filledQuote.initialSellBalance);

        // Collect fees
        uint256 fee = getPlatformFee(filledQuote.boughtAmount);
        IERC20Upgradeable(allocation.buyTokens[0]).safeTransfer(
            PLATFORM_ADDRESS,
            fee
        );

        // Check if bought asset is new
        if (!token[allocation.buyTokens[0]]) {
            // Adding new asset to list
            token[allocation.buyTokens[0]] = true;
            tokens.push(allocation.buyTokens[0]);
        }

        // Check if sold asset is used
        if (
            allocation.sellTokens[0] != mainToken &&
            filledQuote.initialSellBalance == filledQuote.soldAmount
        ) {
            // Delete unused asset
            delete token[allocation.buyTokens[0]];
            tokens[sellTokenIndex] = tokens[tokens.length - 1];
            tokens.pop();
        }

        // Emit SwapToken event
        emit SwapToken(
            msg.sender,
            address(this),
            address(allocation.sellTokens[0]),
            address(allocation.buyTokens[0]),
            filledQuote.soldAmount,
            filledQuote.boughtAmount,
            fee
        );
    }

    /// @inheritdoc IPartyOwnerActions
    function kickMember(address kickingMember, uint256 memberIdx)
        external
        payable
        override
        onlyOwner
        nonReentrant
    {
        if (kickingMember == msg.sender) revert OwnerNotKickable();
        if (members[memberIdx] != kickingMember) revert InvalidMemberIndex();

        // Get total PT from kicking member
        uint256 kickingMemberPT = balanceOf(kickingMember);
        // console.log("kicking member current pt %s", kickingMemberPT);
        (
            uint256[] memory amounts,
            uint256[] memory fees,
            uint256 burnedPT
        ) = redeemPartyTokens(kickingMemberPT, kickingMember);

        // Remove user as a member
        delete member[kickingMember];
        members[memberIdx] = members[members.length - 1];
        members.pop();

        // Emit Kick event
        emit Kick(
            kickingMember,
            msg.sender,
            address(this),
            tokens,
            amounts,
            fees,
            burnedPT
        );
    }

    /// @inheritdoc IPartyMemberActions
    function leaveParty(uint256 memberIdx)
        external
        payable
        override
        onlyMember
        nonReentrant
    {
        if (members[memberIdx] != msg.sender) revert InvalidMemberIndex();

        // Get total PT from member
        uint256 leavingMemberPT = balanceOf(msg.sender);
        (
            uint256[] memory amounts,
            uint256[] memory fees,
            uint256 burnedPT
        ) = redeemPartyTokens(leavingMemberPT, msg.sender);

        // Remove user as a member
        delete member[msg.sender];
        members[memberIdx] = members[members.length - 1];
        members.pop();

        // Emit Leave event
        emit Leave(msg.sender, address(this), tokens, amounts, fees, burnedPT);
    }

    /// @inheritdoc IPartyOwnerActions
    function closeParty() external payable override onlyOwner isAlive {
        // Transfer ownership to 0xdead
        renounceOwnership();

        // Emit Close event
        emit Close(msg.sender, address(this), totalSupply());
    }

    /***************
    PARTY TOKEN FUNCTIONS
    ***************/
    function mintPartyTokens(
        uint256 amountDA,
        SharedStructs.Allocation memory allocation,
        SignatureHelpers.Sig memory approval,
        uint256 ts
    ) private isAlive returns (uint256 fee, uint256 mintedPT) {
        // 1) Declare initial party value in DA
        uint256 partyValueDA = IERC20Upgradeable(mainToken).balanceOf(
            address(this)
        );

        // 2) Get protocol fees
        fee = getPlatformFee(amountDA);

        // 3) Transfer DA from user (deposit + fees)
        IERC20Upgradeable(mainToken).transferFrom(
            msg.sender,
            address(this),
            amountDA + fee
        );

        // 4) Collect protocol fees
        IERC20Upgradeable(mainToken).transfer(PLATFORM_ADDRESS, fee);

        // 5) Swap DA to current asset distribution
        // -> Validate authenticity of asset allocation
        // console.log("Pre validate authenticity of asset allocation");
        if (
            !SignatureHelpers.isValidSig(
                PLATFORM_ADDRESS,
                SignatureHelpers.getMessageHash(
                    abi.encodePacked(
                        address(this),
                        ts,
                        allocation.sellTokens,
                        allocation.sellAmounts,
                        allocation.buyTokens,
                        allocation.spenders,
                        allocation.swapsTargets
                    )
                ),
                approval,
                ts
            )
        ) {
            revert InvalidSignature();
        }
        // console.log("Post validate authenticity of asset allocation");
        SharedStructs.Allocated memory allocated;
        // Declaring array with a known length
        allocated.sellTokens = new address[](allocation.sellTokens.length);
        allocated.buyTokens = new address[](allocation.sellTokens.length);
        allocated.soldAmounts = new uint256[](allocation.sellTokens.length);
        allocated.boughtAmounts = new uint256[](allocation.sellTokens.length);
        for (uint256 i = 0; i < allocation.sellTokens.length; i++) {
            SharedStructs.FilledQuote memory filledQuote = fillQuote(
                allocation.sellTokens[i],
                allocation.sellAmounts[i],
                allocation.buyTokens[i],
                allocation.spenders[i],
                allocation.swapsTargets[i],
                allocation.swapsCallData[i]
            );

            // Since this swaps are between a DA and other asset
            // we can get what was the token price relative to the DA
            // before the swap was made.
            if (filledQuote.initialBuyBalance > 0) {
                partyValueDA +=
                    filledQuote.initialBuyBalance *
                    (filledQuote.soldAmount / filledQuote.boughtAmount);
            }
            allocated.sellTokens[i] = address(allocation.sellTokens[i]);
            allocated.buyTokens[i] = address(allocation.buyTokens[i]);
            allocated.soldAmounts[i] = filledQuote.soldAmount;
            allocated.boughtAmounts[i] = filledQuote.boughtAmount;
        }

        // 6) Emit AllocationFilled
        emit AllocationFilled(
            msg.sender,
            address(this),
            allocated.sellTokens,
            allocated.buyTokens,
            allocated.soldAmounts,
            allocated.boughtAmounts,
            partyValueDA
        );

        // 7) Mint PartyTokens to user
        uint256 totalSupply = totalSupply();
        if (totalSupply == 0) {
            mintedPT = (amountDA / 10**DA_DECIMALS) * 10**decimals();
            _mint(msg.sender, mintedPT);
        } else {
            // console.log("total supply is %s", totalSupply);
            // console.log("amountDA is %s", amountDA);
            // console.log("partyValueDA is %s", partyValueDA);
            mintedPT = (totalSupply * amountDA) / partyValueDA;
            _mint(msg.sender, mintedPT);
        }
    }

    function redeemPartyTokens(uint256 amountPT, address _memberAddress)
        private
        isAlive
        returns (
            uint256[] memory,
            uint256[] memory,
            uint256
        )
    {
        // Declaring array with a known length
        uint256[] memory amounts = new uint256[](tokens.length);
        uint256[] memory fees = new uint256[](tokens.length);

        // 1) Check if user has PartyTokens balance to redeem
        if (amountPT > balanceOf(_memberAddress)) revert UserBalanceNotEnough();

        // 2) Get the total supply of PartyTokens
        // console.log("amountPT %s", amountPT);
        uint256 totalSupply = totalSupply();
        // console.log("totalSupply %s", totalSupply);

        // 3) Burn PartyTokens
        _burn(_memberAddress, amountPT);

        if (amountPT > 0) {
            // @ubinatus: needs work
            // 4) Transfer assets to user. Here we got two options:
            //      i) transfer back current tokens
            //      ii) swap tokens to DA and transfer DA
            // -> doing i) for simplicity for now. should add both options for the user.

            // i) transfer back current tokens
            for (uint256 i = 0; i < tokens.length; i++) {
                // Get amount to transfer
                uint256 tBalance = IERC20Upgradeable(tokens[i]).balanceOf(
                    address(this)
                );
                // console.log("tokenBalance %s", tBalance);
                uint256 amount = ((tBalance * amountPT) / totalSupply);
                // console.log("amount %s", amount);
                // Get fee
                uint256 fee = getPlatformFee(amount);
                // console.log("fee %s", fee);
                // Transfer asset to user
                IERC20Upgradeable(tokens[i]).transfer(
                    _memberAddress,
                    amount - fee
                );
                amounts[i] = (amount - fee);
                // Collect fee
                IERC20Upgradeable(tokens[i]).transfer(PLATFORM_ADDRESS, fee);
                fees[i] = fee;
                // console.log("token %s finished transfer", i);
            }
        }
        return (amounts, fees, amountPT);
    }

    /***************
    HELPER FUNCTIONS
    ***************/
    // Swap a token held by this contract using a 0x-API quote.
    function fillQuote(
        address sellToken,
        uint256 sellAmount,
        address buyToken,
        address spender,
        address payable swapTarget,
        bytes memory swapCallData
    ) private returns (SharedStructs.FilledQuote memory filledQuote) {
        if (!IERC20Upgradeable(sellToken).approve(spender, 0))
            revert FailedAproveReset();
        if (!IERC20Upgradeable(sellToken).approve(spender, sellAmount))
            revert FailedAprove();

        // Track initial balance of the sellToken to determine how much we've sold.
        filledQuote.initialSellBalance = IERC20Upgradeable(sellToken).balanceOf(
            address(this)
        );
        // console.log("initial SellToken balance is %s", initialSellBalance);

        // Track initial balance of the buyToken to determine how much we've bought.
        filledQuote.initialBuyBalance = IERC20Upgradeable(buyToken).balanceOf(
            address(this)
        );
        // console.log("initial BuyToken balance is %s", initialBuyBalance);

        // Execute 0xSwap
        (bool success, ) = swapTarget.call{value: msg.value}(swapCallData);
        if (!success) revert ZeroXFail();
        // console.log("Swap success!");

        // Get how much we've sold.
        filledQuote.soldAmount =
            filledQuote.initialSellBalance -
            IERC20Upgradeable(sellToken).balanceOf(address(this));
        // console.log("soldAmount is %s", soldAmount);

        // Get how much we've bought.
        filledQuote.boughtAmount =
            IERC20Upgradeable(buyToken).balanceOf(address(this)) -
            filledQuote.initialBuyBalance;
        // console.log("boughtAmount is %s", boughtAmount);
    }

    function getPlatformFee(uint256 amount) internal view returns (uint256) {
        return (amount * PLATFORM_FEE) / 10000;
    }

    /***************
    OTHER PARTY FUNCTIONS
    ***************/
    /// @inheritdoc IPartyState
    function getMembers() external view override returns (address[] memory) {
        return members;
    }

    /// @inheritdoc IPartyState
    function getTokens() external view override returns (address[] memory) {
        return tokens;
    }

    /// @inheritdoc IPartyState
    function getJoinRequests()
        external
        view
        override
        returns (address[] memory)
    {
        return joinRequests.requests;
    }

    /// @inheritdoc IPartyActions
    function joinRequest() external override notMember isAlive {
        if (!JoinRequests.create(joinRequests)) revert AlreadyRequested();
    }

    /// @inheritdoc IPartyOwnerActions
    function handleRequest(bool accepted, address user)
        external
        override
        onlyOwner
        isAlive
    {
        if (!JoinRequests.handle(joinRequests, accepted, user))
            revert AlreadyHandled();
    }

    /// @inheritdoc IPartyState
    function getPosts()
        external
        view
        override
        returns (Announcements.Post[] memory)
    {
        return announcements.posts;
    }

    /// @inheritdoc IPartyOwnerActions
    function createPost(
        string memory title,
        string memory description,
        string memory url
    ) external override onlyOwner isAlive {
        Announcements.create(announcements, title, description, url);
    }

    /// @inheritdoc IPartyOwnerActions
    function editPost(
        string memory title,
        string memory description,
        string memory url,
        uint256 announcementIdx
    ) external override onlyOwner isAlive {
        Announcements.edit(
            announcements,
            title,
            description,
            url,
            announcementIdx
        );
    }

    /// @inheritdoc IPartyOwnerActions
    function deletePost(uint256 announcementIdx)
        external
        override
        onlyOwner
        isAlive
    {
        Announcements.remove(announcements, announcementIdx);
    }
}