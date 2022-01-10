//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/utils//Address.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

contract ArkyciaToken is IERC20{

    using SafeMath for uint256;
    using SafeMath for uint8;
    using Address for address;

    // token data
    string constant _name = "Arkycia";
    string constant _symbol = "ARKY";
    
    // 100 Billion Max Supply
    uint256 _totalSupply = 100 * 10**9 * (10 ** 18);
    uint256 public _maxTxAmount = _totalSupply.div(100); // 1% or 10 Billion
    address public admin;

    // balances
    mapping (address => uint256) _balances;
    mapping (address => mapping (address => uint256)) _allowances;

    // Token Lock Structure
    struct TokenLock {
        bool isLocked;
        //Time when the lock is initialized
        uint256 startTime;
        //Duration of lock
        uint256 duration;
        //No of Tokens that can be used before the lock period is over
        uint256 nTokens;
    }
    //Address that are exempt of tx limit
    mapping(address => bool) _isTxLimitExempt;

    // Token Lockers
    mapping (address => TokenLock) tokenLockers;
    
    //Blacklisted wallets 
    mapping (address => bool) _blacklisted;

    // Pancakeswap V2 Router
    IUniswapV2Router02 router;

    //Address of storageToken
    address public storageToken;

    // matic -> storageToken
    address[] buyPath;
    
    // swapper info
    bool public _manualSwapperDisabled;


    constructor(address _storageToken, address _router) public{
        //Setting admin
        admin = msg.sender;

        // exempt deployer and contract from max limit
        _isTxLimitExempt[msg.sender] = true;
        _isTxLimitExempt[address(this)] = true;

        //Setting router and  busd address
        router = IUniswapV2Router02(_router);
        storageToken = _storageToken;

        //Setting buyPath
        buyPath = new address[](2);
        buyPath[0] = router.WETH();
        buyPath[1] = _storageToken;

        //Minting 10% of total supply to this address and 90% to admin
        _balances[address(this)] = _totalSupply.div(10);
        _balances[msg.sender] = (_totalSupply.mul(9)).div(10);
        emit Transfer(address(0), address(this), _totalSupply, block.timestamp);
    }


    receive() external payable {

        require(!isBlacklisted(msg.sender), "Blacklisted");
        require(!_manualSwapperDisabled, "Swapper is disabled");

        if (msg.sender == address(this)){
                return;
            } 
        
        uint256 storageTokensBefore = IERC20(storageToken).balanceOf(address(this));
        
        try router.swapExactETHForTokens{value: msg.value}(
            0,
            buyPath,
            address(this),
            block.timestamp.add(60)
        ) {} catch {
            revert('Failure On Token Purchase');
            }
        
        uint256 storageTokensReceived = IERC20(storageToken)
                                        .balanceOf(address(this)).sub(storageTokensBefore);
        
        require(storageTokensReceived > 0, "Zero amount");
        bool sent = transfer(msg.sender, storageTokensReceived);
        require(sent, "Failure on purchase");
    }

    //Approving others to spend on our behalf
    function approve(address spender, uint256 amount) 
    public 
    override 
    returns (bool) {
        require(
            balanceOf(msg.sender) >= amount,
            "Balance too low"
        );
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /** Removes Tokens From Circulation */
    function _burn(uint256 tokenAmount) public returns (bool) {
        if (tokenAmount == 0) {
            return false;
        }
        
        // update balance of contract
        _balances[msg.sender] = _balances[msg.sender]
                                .sub(tokenAmount, "Balance too low");
        // update Total Supply
        _totalSupply = _totalSupply.sub(tokenAmount);
        // emit Transfer to Blockchain
        emit Transfer(msg.sender, address(0), tokenAmount);
        return true;
    }

    
    /** Transfer Function */
    function transfer(address recipient, uint256 amount) 
    public 
    override 
    returns (bool) 
    {
        return _transferFrom(msg.sender, recipient, amount);
    }
    
    /** Transfer Function */
    function transferFrom(
        address sender, 
        address recipient, 
        uint256 amount
        ) public 
        override 
        returns (bool) 
    {
        
        _allowances[sender][msg.sender] = 
                        _allowances[sender][msg.sender]
                            .sub(amount, "Insufficient Allowance");

        return _transferFrom(sender, recipient, amount);
    }

    ////////////////////////////////////
    /////    INTERNAL FUNCTIONS    /////
    ////////////////////////////////////
    
    /** Internal Transfer */
    function _transferFrom(
        address sender, 
        address recipient, 
        uint256 amount
        ) internal 
        returns (bool) 
        {
            // make standard checks
            require(recipient != address(0), "BEP20: Invalid Transfer");
            require(amount > 0, "Zero Amount");
            // check if we have reached the transaction limit
            require(
                amount <= _maxTxAmount || 
                _isTxLimitExempt[sender],
                "TX Limit is breached"
                );
            //Check if the wallet is blacklisted
            require(
                !isBlacklisted(sender) && !isBlacklisted(recipient), 
                "Blacklisted"
                );
            // For Time-Locking Tokens
            if (tokenLockers[sender].isLocked) {
                if (tokenLockers[sender].startTime
                        .add(tokenLockers[sender].duration) > block.timestamp) 
                {
                    tokenLockers[sender].nTokens = tokenLockers[sender].nTokens
                                                    .sub(amount, 'Exceeds Token Lock Allowance');
                } 
                else {
                    delete tokenLockers[sender];
                }
            }
            // subtract balance from sender
            _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
            
            // add amount to recipient
            _balances[recipient] = _balances[recipient].add(amount);
            // set shares for distributors 
            emit Transfer(sender, recipient, amount, block.timestamp);
            return true;
    }

   
   
   
   
    ////////////////////////////////////////////////////////
    //////////////////// View Functions ///////////////////
    ///////////////////////////////////////////////////////

    function totalSupply() external view 
    override returns (uint256) { 
        return _totalSupply; 
    }

    function balanceOf(address account) public view 
    override returns (uint256) { 
        return _balances[account]; 
    }

    function allowance(address holder, address spender) external 
    view override returns (uint256) { 
        return _allowances[holder][spender]; 
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function isTxLimitExempt(
        address beneficiary
        ) public 
        view 
        returns(bool){
        return _isTxLimitExempt[beneficiary];
    }

    /** True If Tokens Are Locked For Target, False If Unlocked */
    function isTokenLocked(address target) 
    external 
    view 
    returns 
    (bool) {
        return tokenLockers[target].isLocked;
    }

    /** Time until Tokens Unlock For Target User */    
    function timeLeftUntilTokensUnlock(address target) 
    public 
    view 
    returns (uint256) {
        if (tokenLockers[target].isLocked) {
            uint256 endTime = tokenLockers[target].startTime.add(tokenLockers[target].duration);
            if (endTime <= block.timestamp)
            {
                return 0;
            }   
            return endTime.sub(block.timestamp);
        } else {
            return 0;
        }
    }
    
    /** Number Of Tokens A Locked Wallet Has Left To Spend Before Time Expires */
    function nTokensLeftToSpendForLockedWallet(
        address wallet) 
        external 
        view 
        returns 
        (uint256) {
        return tokenLockers[wallet].nTokens;
    }

    /** Address is blacklisted */
    function isBlacklisted(address wallet) public view returns(bool){
        return _blacklisted[wallet];
    }

    /** Function to view balance of this contract */
    function balanceOfTokensInContract(address token) public view returns(uint256){
        return IERC20(token).balanceOf(address(this));
    }

    /** Function to view matic balance of this contract */
    function maticBalanceOfContract() public view returns (uint256){
        return address(this).balance;
    }

    /** Get storage token balance */
    function storageTokenBalanceOfContract() public view returns(uint256){
        return IERC20(storageToken).balanceOf(address(this));
    }

    /** Arkycia Token balance of contract */
    function arkyciaTokenBalanceOfContract() public view returns(uint256){
        return IERC20(address(this)).balanceOf(address(this));
    }

    //////////////////////////////////////////////////////////
    ///////////////// Admin Functions ////////////////////////
    //////////////////////////////////////////////////////////
    
    //Function to change the admin
    function changeAdmin(address newAdmin) 
    external 
    onlyAdmin{
        address oldAdmin = admin;
        admin = newAdmin;
        emit AdminChanged(oldAdmin, newAdmin, block.timestamp);
    }

    //Function change storage token
    function changeStorageToken(address token) external onlyAdmin{
        address oldStorageToken = storageToken;
        storageToken = token;
        emit StorageTokenChanged(oldStorageToken, token);
    }

    //Function to update router address
    function updateRouterAddress(address _router) 
    external 
    onlyAdmin
    returns(bool){
        require(
            _router != address(router) && 
            _router != address(0), 
            'Invalid Address'
            );

        router = IUniswapV2Router02(_router);
        buyPath[0] = router.WETH();
        emit UpdatePancakeswapRouter(_router);
        return true;
    }
    
    /**Change max transaction amount */
    function changeMaxTxLimit(uint256 amount) external onlyAdmin{
        _maxTxAmount = amount; 
    }

    /** Lock Tokens For A User Over A Set Amount of Time */
    function lockTokens(
        address target, 
        uint256 lockDurationInSeconds, 
        uint256 tokenAllowance
        ) 
        external 
        onlyAdmin 
        returns(bool){
            require(
                lockDurationInSeconds <= 31536000, 
                'Duration must be less than or equal to 1 year'
                );
            //86400 seconds = 1 day 
            require(
                timeLeftUntilTokensUnlock(target) <= 86400, 
                'Not Time'
                );
            tokenLockers[target] = TokenLock({
                isLocked: true,
                startTime: block.timestamp,
                duration: lockDurationInSeconds,
                nTokens: tokenAllowance
            });
            emit TokensLockedForWallet(target, lockDurationInSeconds, tokenAllowance);
            return true;
        }


    //Function to exempt an address from tx limit
    function changeTxLimitPermission(address target, bool isExempt) 
    external 
    onlyAdmin{
        _isTxLimitExempt[target] = isExempt;
    }


    /** Function to withdraw tokens from contract */
    function withdrawToken(address token, address to, uint256 amount) 
    public 
    onlyAdmin 
    returns(bool){
        require(
            IERC20(token).balanceOf(address(this)) >= amount,
            "Balance in the contract too low"
            );
        require(to != address(0), "Cannot withdraw to address(0)");
        bool sent = IERC20(token).transfer(to, amount);
        require(sent, "Failure in token transfer");
        emit TokenTransfer(token, amount, to);
        return true;
    }

    /** Function to withdraw Arkycia tokens from contract */
    function withdrawArkyciaToken(address to, uint256 amount) external onlyAdmin returns(bool){
        bool sent = withdrawToken(address(this), to, amount);
        require(sent, "Failure in withdrawl");
        return true;
    }

    function withdrawStorageToken(address to, uint256 amount) external onlyAdmin returns(bool){
        bool sent = withdrawToken(storageToken, to, amount);
        require(sent, "Failure in withdrawl");
        return true;
    }

    /** Function to withdraw Matic from contract */
    function withdrawMatic(address to, uint256 amount) external onlyAdmin returns(bool){
        require(address(this).balance >= amount, "Matic balance too low in contract");
        (bool sent, ) = to.call{value: amount}("");
        require(sent, "Failure on Matic transfer");
        emit MaticTransfer(to, amount);
        return true;
    }

    /** Disables or Enables the swapping mechanism inside of Arkycia Tokens */
    function setManualSwapperDisabled(bool manualSwapperDisabled) 
    external 
    onlyAdmin {
        _manualSwapperDisabled = manualSwapperDisabled;
        emit UpdatedManualSwapperDisabled(manualSwapperDisabled);
    }

    /** Function to change blacklist */
    function blacklistWallet(address wallet, bool blacklist) external onlyAdmin{
        _blacklisted[wallet] = blacklist;
    }

    
   //////////////////////////////////////////////////////////
   ///////////////////// Modifiers //////////////////////////
   ///////////////////////////////////////////////////////// 
   
   
    modifier onlyAdmin{
        require(msg.sender == admin, "Only admin");
        _;
    }


    //////////////////////////////////////////////////////////
    /////////////////////// Events ///////////////////////////
    //////////////////////////////////////////////////////////

    event AdminChanged(
        address oldAdmin, 
        address newAdmin, 
        uint256 time
        );

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 indexed date
    );

    event StorageTokenChanged(address oldStorageToken, address newStorageToken);

    event TokenTransfer(address indexed token, uint256 amount, address indexed to);

    event MaticTransfer(address recipient, uint256 amount);

    event UpdatedManualSwapperDisabled(bool manualSwapperDisabled);

    event UpdatePancakeswapRouter(address router);

    event TokensLockedForWallet(
        address indexed target, 
        uint256 lockDurationInSeconds, 
        uint256 tokenAllowance
        );

}