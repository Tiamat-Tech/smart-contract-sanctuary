// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.0;
// import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Rounds
/// @author Jonah Burian, Anna Lulushi, Chunda McCain, Sophie Fujiwara
/// @notice This contract is not ready to be deployed on mainnet
/// @dev All function calls are currently in testing
contract Rounds is Ownable {
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    //----------State Variables-----------

    // owner state variable is inherited from Ownable interface

    // The id of the next created offering. incremented each time a offering is created.
    uint private openOfferingId;

    /// @notice The whitelist map for each investor
    /// @dev maps investor => (offeringid => canInvest)
    mapping(address =>  mapping(uint => bool)) public whitelist;

    /// @notice The map to store pending withdraws for each investor
    /// @dev maps investor => (ERC20 => amount : Rejected investments by offerings)
    mapping(address =>  mapping(IERC20 =>  uint)) public pendingWithdrawsMap;

    /// @notice The map of each offering id to OfferingInfo struct
    mapping(uint =>  OfferingInfo) public offeringMap;

    /// @notice OfferingInfo struct for each offering
    /// @param stage current stage of the offering
    /// @param company address of the compainy raising funds
    /// @param ERC20Token ERC20 token used for funding
    /// @param pendingInvestmentMap funds recieved by company but not accepted or rejected
    /// @param canAcceptAll indicates whether the company is able to accept all funds
    struct OfferingInfo {
        Stages stage;
        address company;
        IERC20 ERC20Token;
        mapping(address => PendingInvestment) pendingInvestmentMap;
        bool canAcceptAll;
    }

    /// @notice PendingInvestment struct for each investment
    /// @param canAccept indicates whether the company can accept the investment
    /// @param amount the amount to be invested. When true, withdraw is enabled.
    struct PendingInvestment {
        bool canAccept;
        uint amount;
    }

    /// @notice Stages enum for offerings
    /// @param DoesNotExist only availible function is intializing offering -> OfferingOpen
    /// @param Active 1) Investors can invest, 2) Companies can accept and reject investments, 3) Investors can withdraw rejected funds but NOT pending funds
    /// @param Inactive 1) Investors CANNOT invest, 2) Companies can accept and reject investments, 3) Investors can withdraw rejected funds but NOT pending funds
    /// @param Archived 1) Investors CANNOT invest, 2) Companies CANNOT accept or reject investments, 3) Investors can withdraw rejected funds and pending funds
    enum Stages {
        DoesNotExist,
        Active,
        Inactive,
        Archived
    }

    //----------Events--------------

    event NewOffering(uint id, address company, address ERC20Token);

    event Whitelist(address investor, uint offeringId);

    event NextStage(uint offeringId, Stages stage);

    event SingleInvestmentUnlocked(uint offeringId, address investor);

    event AllInvestmentsUnlocked(uint offeringId);

    event Investment(uint offeringId, address investor, uint amount);

    event InvestmentRejected(uint offeringId, address investor, uint amount);

    event InvestmentAccepted(uint offeringId, address investor, uint amount);

    event InvestorWithdrawFromPendingWithdraws(address investor, address ERC20Token, uint amount);

    event InvestorWithdrawFromFinishedOffering(uint _offeringId, address _investor, uint _amount);

    //----------Modifiers-----------

    //onlyOwner modifier is inherited

    /// @notice Revert if sender is not the owner or company
    /// @param _offeringId The offering of the company
    modifier onlyCompanyOrOwner(uint _offeringId) {
        address sender = msg.sender;
        require(sender == owner() || sender == offeringMap[_offeringId].company, "Caller is not the owner or company");
        _;
    }

    /// @notice Revert if sender is not the company
    /// @param _offeringId The offering of the company
    modifier onlyCompany(uint _offeringId) {
        address sender = msg.sender;
        require(sender == offeringMap[_offeringId].company, "Caller is not the company");
        _;
    }

    /// @notice Revert if an address is the zero address
    /// @param _address The address being tested
    modifier notZeroAddress(address _address) {
        require(_address != address(0), "Cannot be zero address");
        _;
    }

    /// @notice Checks that two addreses are not the same
    /// @param _address1 The first address
    /// @param _address2 The second address
    modifier addressesNotEqual(address _address1, address _address2) {
        require(_address1 != _address2, "Addresses cannot be the same");
        _;
    }

    /// @notice Checks that the offering is at a valid stage
    /// @param _offeringId The id of the offering
    /// @param _stage The valid stage
    modifier atStage(uint _offeringId, Stages _stage) {
        require(offeringMap[_offeringId].stage == _stage, "Action not allowed in current stage");
        _;
    }

    /// @notice Checks that the offering is not at an invalid stage
    /// @param _offeringId The id of the offering
    /// @param _stage The invalid stage
    modifier notAtStage(uint _offeringId, Stages _stage) {
        require(offeringMap[_offeringId].stage != _stage, "Action not allowed in current stage");
        _;
    }


    /// @notice Checks that an investor is whitelisted for a particular offering
    /// @param _offeringId The id of the offering
    modifier investorWhitelisted(uint _offeringId) {
        require(whitelist[msg.sender][_offeringId], "Investor is not whitelisted");
        _;
    }

    /// @notice Checks that an investor is not whitelisted for a particular offering
    /// @param _investor The address of the investor
    /// @param _offeringId The id of the offering
    modifier investorNotWhitelisted(address _investor, uint _offeringId) {
        require(!whitelist[_investor][_offeringId], "Investor is already whitelisted");
        _;
    }

    /// @notice Checks that pending investment is not zero
    /// @param _investor The address of the investor
    /// @param _offeringId The id of the offering
    modifier pendingInvestmentNotZero(uint _offeringId, address _investor) {
        require(_getPendingInvestment(_offeringId, _investor) > 0, "There is no pending investment");
        _;
    }

    /// @notice Checks that there is a balance in pending withdraws
    /// @param _token Token to check
    modifier pendingWithdrawsNotZero(address _investor, IERC20 _token) {
        require(pendingWithdrawsMap[_investor][_token] > 0, "There is no balance to withdraw");
        _;
    }

    /// @notice Checks if the investor is able to withdraw
    /// @param _offeringId The id of the offering
    /// @param _investor The address of the investor
    modifier companyCanAcceptInvestment(uint _offeringId, address _investor) {
        require(_canCompanyAcceptInvestment(_offeringId, _investor), "Company not permitted to accept");
        _;
    }

    modifier companyCantAlreadyHavePermission(uint _offeringId, address _investor) {
        require(!_canCompanyAcceptInvestment(_offeringId, _investor), "Company already permitted to Accept");
        _;
    }
    /// @notice Checks whether the investment amount is greater than zero
    /// @param _amount The amount of the investment
    modifier amountGreaterThanZero(uint _amount) {
        require(_amount > 0, "Investment must be greater than zero");
        _;
    }

    //----------Accessors-----------

    /// @notice Get pending investment amount for a given offering and investor
    /// @param _offeringId The id of the offering
    /// @param _investor The address of the investor
    /// @return amount The amount in pending investment the investor has for given offering
    function getPendingInvestment(uint _offeringId, address _investor) external view returns (uint amount) {
       return _getPendingInvestment(_offeringId, _investor);
    }

    /// @notice Get withdrawable amount for a given IERC20
    /// @dev Function is called by an investor
    /// @param token The desired IERC20
    /// @return amount The withdrawable amount the investor has for given IERC20
    function getWithdrawableAmount(IERC20 token) external view returns (uint amount) {
        return _getWithdrawableAmount(msg.sender, token);
    }

    /// @notice Check whether canAccept field for an investor is set
    /// @param _offeringId The id of the offering
    /// @param _investor The address of the investor
    /// @return canAccept True if the company can accept the investor's investment, false otherwise
    function getCanAccept(uint _offeringId, address _investor) external view returns (bool canAccept) {
        return offeringMap[_offeringId].pendingInvestmentMap[_investor].canAccept;
    }

    //----------External Functions-----------

    /// @notice Does not allow owner to renounce ownership or else funds would get stuck
    /// @dev WE NEED TO RESEARCH WHETHER THIS IS STANDARD
    function renounceOwnership() public virtual onlyOwner override {
        require(false, "Ownership is not transferrable");
    }

    /// @notice Creates a new offering info struct and adds it to the map.
    /// @dev We do not test that the _ERC20Token follows the standared ERC20 interface. We may want to add more modifiers and a return
    /// @param _company Address of the company
    /// @param _ERC20Token Address of the ERC20
    function createOffering(address _company, address _ERC20Token)
        external
        onlyOwner
        addressesNotEqual(_company, _ERC20Token)
        notZeroAddress(_company)
        notZeroAddress(_ERC20Token) {
            uint id = openOfferingId;
            _createOffering(_company, _ERC20Token);
            emit NewOffering(id, _company, _ERC20Token);
    }

    /// @notice Add investor to whitelist
    /// @dev We need to check that we don't want any more modifiers
    /// @param _investor Address of the investor
    /// @param _offeringId The id of the offering
    function addWhitelist(address _investor, uint _offeringId)
        external
        onlyOwner
        notZeroAddress(_investor)
        atStage(_offeringId, Stages(1))
        addressesNotEqual(_investor, offeringMap[_offeringId].company)
        investorNotWhitelisted(_investor, _offeringId) {
            _addWhitelist(_investor, _offeringId);
            emit Whitelist(_investor, _offeringId);
    }

    /// @notice Move a offering to the next stage
    /// @dev We only allow this action in offering 1 or 2. In offering 0, the offering is not created and in offering 3 the offering is closed
    /// @param _offeringId The id of the offering
    function nextStage(uint _offeringId)
        external
        onlyCompanyOrOwner(_offeringId)
        notAtStage(_offeringId, Stages(0))
        notAtStage(_offeringId, Stages(3)) {
            _nextStage(_offeringId);
            //event below
    }

    /// @notice Enable an offering to accept a single investment
    /// @param _offeringId The id of the offering
    /// @param _investor The address of the investor
    function enableCanAcceptSingleInvestment(uint _offeringId, address _investor)
        external
        onlyOwner
        notAtStage(_offeringId, Stages(0))
        notAtStage(_offeringId, Stages(3))
        companyCantAlreadyHavePermission(_offeringId, _investor)
        pendingInvestmentNotZero(_offeringId, _investor) {
            _enableCanAcceptSingleInvestment(_offeringId, _investor);
             emit SingleInvestmentUnlocked(_offeringId, _investor);
    }

    /// @notice Allow a company to accept all investments (should only be called if they have offline cross singned all docs)
    /// @dev Only allowed in stage 2 because there are no new investors
    /// @param _offeringId The id of the offering
    function enableCanAcceptAll(uint _offeringId)
        external
        onlyOwner
        atStage(_offeringId, Stages(2)) {
            _enableCanAcceptAll(_offeringId);
            emit AllInvestmentsUnlocked(_offeringId);
    }

    /// @notice Allow an investor to invest in an offering
    /// @dev Function is called by an investor
    /// @param _offeringId The id of the offering
    /// @param _amount The amount to be invested
    function invest(uint _offeringId, uint _amount)
        external
        investorWhitelisted(_offeringId)
        atStage(_offeringId, Stages(1))
        amountGreaterThanZero(_amount) {
            address investor = msg.sender;
            _invest(investor, _offeringId, _amount);
            emit Investment(_offeringId, investor, _amount);
    }

    /// @notice Rejects an investor's investment for given offering
    /// @param _offeringId The id of the offering
    /// @param _investor The address of the investor
    function rejectInvestment(uint _offeringId, address _investor)
        external
        onlyCompanyOrOwner(_offeringId)
        notAtStage(_offeringId, Stages(0))
        notAtStage(_offeringId, Stages(3))
        pendingInvestmentNotZero(_offeringId, _investor) {
            _rejectInvestment(_offeringId, _investor);
            //event below
    }

    /// @notice Accept an investment for an offering
    /// @param _offeringId The id of the offering
    /// @param _investor The address of theinvestor
    function acceptInvestment(uint _offeringId, address _investor)
        external
        onlyCompany(_offeringId)
        companyCanAcceptInvestment(_offeringId, _investor)
        pendingInvestmentNotZero(_offeringId, _investor) {
            whitelist[_investor][_offeringId] = false;
            uint amount = _getPendingInvestment(_offeringId, _investor);
            _sendPendingInvestment(_offeringId, _investor, msg.sender);
            emit InvestmentAccepted(_offeringId, _investor, amount);
    }

    /// @notice Withdraw all funds from archived offerings for a given token
    /// @dev Function is called by an investor
    /// @param _token IERC20 token to withdraw funds in
    function withdrawFromPendingWithdraws(IERC20 _token)
        external
        pendingWithdrawsNotZero(msg.sender, _token) {
            address investor = msg.sender;
            uint amount = _getWithdrawableAmount(investor, _token);
            _withdrawFromPendingWithdraws(investor, _token);
            emit InvestorWithdrawFromPendingWithdraws(investor, address(_token), amount);
    }

    /// @notice Withdraw pending funds from an archived offering
    /// @dev Function is called by an investor
    /// @param _offeringId The id of the offering
    function withdrawFromFinishedOffering(uint _offeringId)
        external
        atStage(_offeringId, Stages(3))
        pendingInvestmentNotZero(_offeringId, msg.sender) {
            address investor = msg.sender;
            uint amount = _getPendingInvestment(_offeringId, investor);
            _sendPendingInvestment(_offeringId, investor, investor);
             emit InvestorWithdrawFromFinishedOffering(_offeringId, investor, amount);
    }

    //----------Internal Functions-----------

    // @notice Check whether a company can accept an investment from given investor
    /// @param _offeringId The id of the offering
    /// @param _investor The address of the investor
    /// @return locked True if the company can accept the investment, false otherwise
    function canCompanyAcceptInvestment(uint _offeringId, address _investor) external view returns (bool locked) {
        return _canCompanyAcceptInvestment(_offeringId, _investor);
    }


    /// @notice Internal helper function to get pending investment amount for a given offering and investor
    /// @param _offeringId The id of the offering
    /// @param _investor The address of the investor
    /// @return amount The amount in pending investment the investor has for given offering
    function _getPendingInvestment(uint _offeringId, address _investor) internal view returns (uint amount) {
        return offeringMap[_offeringId].pendingInvestmentMap[_investor].amount;
    }

    /// @notice Internal helper function to get withdrawable amount for a given IERC20
    /// @param investor The address of the investor
    /// @param token The desired IERC20
    /// @return amount The withdrawable amount the investor has for given IERC20
    function _getWithdrawableAmount(address investor, IERC20 token) internal view returns (uint amount) {
        return pendingWithdrawsMap[investor][token];
    }

    /// @notice Internal helper function to check whether a company can accept an investment from given investor
    /// @param _offeringId The id of the offering
    /// @param _investor The address of the investor
    /// @return locked True if the company can accept the investment, false otherwise
    function _canCompanyAcceptInvestment(uint _offeringId, address _investor) internal view returns (bool locked) {
        OfferingInfo storage offering = offeringMap[_offeringId];
        bool canAll = offering.canAcceptAll;
        bool canParticular = offering.pendingInvestmentMap[_investor].canAccept;
        Stages stage = offering.stage;
        return (canParticular && (stage == Stages(1))) || ((canParticular || canAll) && (stage == Stages(2)));
    }

    /// @notice Internal helper function to create an offering
    /// @dev Need to figure out what happens if openOfferingId breaks
    /// @param _company Address of the company
    /// @param _ERC20Token Address of the ERC20
    function _createOffering(address _company, address _ERC20Token) internal {
        OfferingInfo storage offering = offeringMap[openOfferingId];
        assert(offering.stage == Stages(0));
        offering.stage = Stages(1);
        offering.company = _company;
        offering.ERC20Token = IERC20(_ERC20Token);
        openOfferingId = openOfferingId.add(1); // next offering will have id 1
    }

    /// @notice Add investor to whitelist helper
    /// @dev Need to figure out what happens if openOfferingId breaks
    /// @param _investor Address of the investor
    /// @param _offeringId The id of the offering
    function _addWhitelist(address _investor, uint _offeringId) internal {
        whitelist[_investor][_offeringId] = true;
    }

    /// @notice Internal helper function to move a offering to the next stage
    /// @dev If the offering is moved to stage 3 the company cannot accept investments
    /// @param _offeringId The id of the offering
    function _nextStage(uint _offeringId) internal {
        Stages currStage = offeringMap[_offeringId].stage;
        Stages newStage = Stages(uint(currStage).add(1));

        //in offering 3 the company cannot accept investments
        if (newStage == Stages(3)) {
            offeringMap[_offeringId].canAcceptAll = false;
        }

        offeringMap[_offeringId].stage = newStage;
        emit NextStage(_offeringId, newStage);
    }

    /// @notice Internal helper function to allow a company to accept all investments
    /// @dev Require canAcceptAll to be false - this can be switched
    /// @param _offeringId The id of the offering
    function _enableCanAcceptAll(uint _offeringId) internal {
        OfferingInfo storage offering = offeringMap[_offeringId];
        require(!offering.canAcceptAll, "canAcceptAll is already true");
        offering.canAcceptAll = true;
    }

    /// @notice Internal helper function to allow an investor to invest in an offering
    /// @param _investor Address of investor
    /// @param _offeringId Id of the offering
    /// @param _amount Amount to be invested
    function _invest(address _investor, uint _offeringId, uint _amount) internal {
        OfferingInfo storage offering = offeringMap[_offeringId];
        assert(_investor != offering.company); //company cannot be investor
        IERC20 token = offering.ERC20Token;

        offering.pendingInvestmentMap[_investor].canAccept = false; //investment is now locked
        whitelist[_investor][_offeringId] = false; //investor cannot invest twice
        uint currAmount = _getPendingInvestment(_offeringId, _investor);

        token.safeTransferFrom(_investor, address(this), _amount); //transfer

        offering.pendingInvestmentMap[_investor].amount = currAmount.add(_amount); //after to prevent reentry attacks
    }

    /// @notice Internal helper function to reject an investment for given offering
    /// @dev Sets fields in pendingInvestmentMap and pendingWithdrawsMap appropriately
    /// @param _offeringId The id of the offering
    /// @param _investor The address of the investor
    function _rejectInvestment(uint _offeringId, address _investor) internal {
        OfferingInfo storage offering = offeringMap[_offeringId];
        IERC20 token = offering.ERC20Token;

        uint currPendingAmount = _getPendingInvestment(_offeringId, _investor);
        uint currWithdrawAmount = pendingWithdrawsMap[_investor][token];

        offering.pendingInvestmentMap[_investor].canAccept = false; //investment is now locked
        offering.pendingInvestmentMap[_investor].amount = 0;
        pendingWithdrawsMap[_investor][token] = currWithdrawAmount.add(currPendingAmount);
        emit InvestmentRejected(_offeringId, _investor, currPendingAmount);
    }

    /// @notice Internal helper function to accept an offering to accept a single investment
    /// @param _offeringId The id of the offering
    /// @param _investor The address of the investor
    function _enableCanAcceptSingleInvestment(uint _offeringId, address _investor) internal {
        OfferingInfo storage offering = offeringMap[_offeringId];
        offering.pendingInvestmentMap[_investor].canAccept = true;
    }

    /// @notice Internal function to send funds for an offering from pendingInvestmentMap to destination
    /// @param _offeringId The id of the offering
    /// @param _investor The address of the investor
    /// @param _to The address where funds are sent
    function _sendPendingInvestment(uint _offeringId, address _investor, address _to) internal {
        OfferingInfo storage offering = offeringMap[_offeringId];
        IERC20 token = offering.ERC20Token;
        uint currPendingAmount = _getPendingInvestment(_offeringId, _investor);
        PendingInvestment storage pending = offering.pendingInvestmentMap[_investor];

        pending.amount = 0;
        pending.canAccept = false;
        token.safeTransfer(_to, currPendingAmount);
    }

    /// @notice Internal function to withdraw all funds from archived offerings for a given token
    /// @dev Function is called by an investor
    /// @param _token IERC20 token to withdraw funds in
    function _withdrawFromPendingWithdraws(address _investor, IERC20 _token) internal {
        uint currPendingAmount = pendingWithdrawsMap[_investor][_token];
        pendingWithdrawsMap[_investor][_token] = 0;
        _token.safeTransfer(_investor, currPendingAmount);
    }
}