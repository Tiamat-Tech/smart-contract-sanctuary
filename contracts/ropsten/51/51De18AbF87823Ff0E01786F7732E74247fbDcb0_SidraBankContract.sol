//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.11;

// multi-class fungible tokens: MCFTs
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ERC1178.sol";
import "hardhat/console.sol";

contract SidraBankContract is ERC1178 {
    using SafeMath for uint256;
    address public Owner;
    uint256 public _totalSupply;
    uint256 currentClass;
    
    struct Transactor {
        address actor;
        uint256 amount;
    }
    struct TokenExchangeRate {
        uint256 heldAmount;
        uint256 takeAmount;
    }
    mapping(uint256 => uint256) public classIdToSupply;
    mapping(address => mapping(uint256 => uint256)) ownerToClassToBalance;
    mapping(address => mapping(uint256 => Transactor)) approvals;
    mapping(uint256 => string) public classNames;
    // owner’s address to classIdHeld => classIdWanted => TokenExchangeRate
    mapping(address => mapping(uint256 => mapping(uint256 => TokenExchangeRate))) exchangeRates;

    // Constructor
    constructor(){
        Owner = msg.sender;
        currentClass = 1;
        _totalSupply = 0;

        // registerArtist('ABC', 1000 * 10**18);
        // minCount = 1000;
        // minTokenPrice = 200000000000000;
        // _setupRole(DEFAULT_ADMIN_ROLE, Owner);
        
        
    }

    function implementsERC1178() public pure override returns (bool) {
        return true;
    }
    // Returns the total number of all MCFTs currently tracked by this contract.
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function individualSupply(uint256 classId)
        public
        view
        override
        returns (uint256)
    {
        return classIdToSupply[classId];
    }

    function balanceOf(address owner, uint256 classId)
        public
        view
        virtual
        override
        returns (uint256)
    {
        
        return ownerToClassToBalance[owner][classId];
    }

    // class of 0 is meaningless and should be ignored.
    // Returns an array of _classId’s of MCFTs that address _owner owns in the contract.
    function classesOwned(address owner)
        public
        view
        override
        returns (uint256[] memory)
    {
        uint256[] memory tempClasses = new uint256[](currentClass - 1);
        uint256 count = 0;
        for (uint256 i = 1; i < currentClass; i++) {
            if (ownerToClassToBalance[owner][i] != 0) {
                tempClasses[count] = ownerToClassToBalance[owner][i];
                count += 1;
            }
        }
        uint256[] memory classes = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            classes[i] = tempClasses[i];
        }
        return classes;
    }

    function transfer(
        address to,
        uint256 classId,
        uint256 quantity
    ) public override {
        require(ownerToClassToBalance[msg.sender][classId] >= quantity);
        ownerToClassToBalance[msg.sender][classId] -= quantity;
        ownerToClassToBalance[to][classId] += quantity;
        Transactor memory zeroApproval;
        zeroApproval = Transactor(address(0), 0);
        approvals[msg.sender][classId] = zeroApproval;
        emit Transfer(msg.sender, to, classId, quantity);
    }

    function approve(
        address to,
        uint256 classId,
        uint256 quantity
    ) public override {
        require(ownerToClassToBalance[msg.sender][classId] >= quantity);
        Transactor memory takerApproval;
        takerApproval = Transactor(to, quantity);
        approvals[msg.sender][classId] = takerApproval;
        emit Approval(msg.sender, to, classId, quantity);
    }

    function approveForToken(
        uint256 classIdHeld,
        uint256 quantityHeld,
        uint256 classIdWanted,
        uint256 quantityWanted
    ) public {
       
        require(ownerToClassToBalance[msg.sender][classIdHeld] >= quantityHeld);
        TokenExchangeRate memory tokenExchangeApproval;
        tokenExchangeApproval = TokenExchangeRate(quantityHeld, quantityWanted);
        exchangeRates[msg.sender][classIdHeld][classIdWanted] = tokenExchangeApproval;
    }

    // A = msg.sender and B = to
    // A wants to exchange his quantityHeld amount of token classIdHeld
    // in exchange for person to’s quantityWanted amount of tokens of classIdWanted
    function exchange(
        address to,
        uint256 classIdPosted,
        uint256 quantityPosted,
        uint256 classIdWanted,
        uint256 quantityWanted
    ) public {
        // check if capital existence requirements are met by both parties
        require(ownerToClassToBalance[msg.sender][classIdPosted] >= quantityPosted);
        require(ownerToClassToBalance[to][classIdWanted] >= quantityWanted);
        // check if approvals are met
        require(approvals[msg.sender][classIdPosted].actor == address(this) && approvals[msg.sender][classIdPosted].amount >= quantityPosted);
        require(approvals[to][classIdWanted].actor == address(this) && approvals[to][classIdWanted].amount >= quantityWanted);

        // check if exchange rate is acceptable
        TokenExchangeRate memory rate = exchangeRates[to][classIdWanted][classIdPosted];

        require(SafeMath.mul(rate.takeAmount, quantityWanted) <= SafeMath.mul(rate.heldAmount, quantityPosted));
        // update balances
        ownerToClassToBalance[msg.sender][classIdPosted] -= quantityPosted;
        ownerToClassToBalance[to][classIdPosted] += quantityPosted;
        ownerToClassToBalance[msg.sender][classIdWanted] += quantityWanted;
        ownerToClassToBalance[to][classIdWanted] -= quantityWanted;
        // update approvals and
        approvals[msg.sender][classIdPosted].amount -= quantityPosted;
        approvals[to][classIdWanted].amount -= quantityWanted;
        
    }

    function transferFrom(
        address from,
        address to,
        uint256 classId
    ) public override {
        Transactor memory takerApproval = approvals[from][classId];
        uint256 quantity = takerApproval.amount;
        require(takerApproval.actor == to && quantity <= ownerToClassToBalance[from][classId]);
        ownerToClassToBalance[from][classId] -= quantity;
        ownerToClassToBalance[to][classId] += quantity;
        Transactor memory zeroApproval;
        zeroApproval = Transactor(address(0), 0);
        approvals[from][classId] = zeroApproval;
        emit Transfer(from, to, classId, quantity);
    }

    function name() public pure override returns (string memory) {
        return "Sidra Token";
    }

    function className(uint256 classId)
        public
        view
        override
        returns (string memory)
    {
         return classNames[classId];
    }

    function symbol() public pure override returns (string memory) {
        return "SIDRA";
    }

    // Artists call this function to create their own token offering
    function registerArtist(string memory artistName, uint256 count)
        public
        // payable
        returns (bool)
    {
        // require(msg.value >= count * minTokenPrice && count >= minCount, 'no enough ethers or count of token');
        ownerToClassToBalance[msg.sender][currentClass] = count;
        classNames[currentClass] = artistName;
        classIdToSupply[currentClass] = count;
        currentClass += 1;
        _totalSupply += count;
        return true;
    }
}