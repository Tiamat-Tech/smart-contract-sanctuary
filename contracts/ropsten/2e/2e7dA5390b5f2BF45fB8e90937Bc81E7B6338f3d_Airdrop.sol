// contracts/MyNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/** 
*   @title Airdrop controller
*   @author XAVE Team
*   @notice Make airdrops of a given token, available to a list of accounts.
*   A user with the proper access, creates a "white list" with all the accounts that 
*   can claim tokens as airdrops.
*   Then, each account listed on that white list can take its tokens at any time.
*   There is a maximum amount of claimable tokens for each account on the white list.
*   Since these accounts iniciate the actual transaction, they are the ones who 
*   pay for the gas fee when they claim their tokens.
*/
contract Airdrop is AccessControlEnumerable{

    bytes32 public constant WHITELISTER_ROLE = keccak256("WHITELISTER_ROLE");

    mapping(address => uint256) private whiteList;

    constructor() {
        //Note that unlike grantRole, this function doesn’t perform any checks on the calling account.
        //the owner has admin role
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

   /** 
    * @notice Creates a white list of accounts with the amount of tokens each account can claim. 
    * @param addressList List of accounts to add to the white list.
    * @param amountList List of the amounts each account will be able to claim. 
    *       Assumes the index of amountList[i] corresponds to the same index number of addressList[i]. 
    * @param overrideAmount If true, the old amount assigned to the account (if any) will be 
    *       overridden with the new amount.
    *       If false, the new amount will be added to the previously assigned amount. 
    */
    function addToWhiteList(
                  address[] calldata addressList
                , uint256[] calldata amountList
                , bool overrideAmount) 
            public onlyRole(WHITELISTER_ROLE)
    {
        require(addressList.length == amountList.length, "Array arameters must be the samne size");
        require(addressList.length > 0 ,"Array parameters must contain at least one item");

        for (uint8 i; i < addressList.length; i++) {
            if (overrideAmount){
                whiteList[addressList[i]] = amountList[i];
            }else{
                whiteList[addressList[i]] = whiteList[addressList[i]] + amountList[i];
            }
        }
    }

    /**
    * @notice Increase the claimable ammount of one account on the white list
    * @param accountAddress Account on the white list
    * @param amount Amount of tokens, accountAddress will be able to claim. 
                    This amount will be added to the previously assigned amount, if any.
    */
    function addOnetoWhiteList(address accountAddress, uint256 amount) public onlyRole(WHITELISTER_ROLE) {
        whiteList[accountAddress] = whiteList[accountAddress] + amount;
    }

    /**
    * @notice Reduces the amount of claimable tokens of one account on the white list.
    * @param accountAddress Account from which claimable tokens will be subtracted.
    * @param amount Amount of tokens to subtract. It cannot be higher than current balance.
    */
    function subtractFromWhiteList(address accountAddress, uint256 amount) public onlyRole(WHITELISTER_ROLE) {
        require(whiteList[accountAddress] >= amount,"The amount is to high");
        whiteList[accountAddress] = whiteList[accountAddress] - amount;
    }    

    /**
    * @notice Get the assigned balance for one specific account
    * @param accountAddress Account to query.
    * @return amount Returns the balance. Zero means it may have never been on the white list 
    */
    function getWhiteListedClaimableBalance(address accountAddress)
        public
        view
        onlyRole(WHITELISTER_ROLE)
        returns (uint256 amount)
    {
        return whiteList[accountAddress];
    }

    /**
    * @notice Returns the claimable amount of tokens. 
    *         A user on the white list would could call this function to check its balance.
    * @return amount Returns the balance. Zero means the user may have never been on the white list 
    */
    function getMyClaimableBalance() external view returns(uint256 amount) {
        return whiteList[msg.sender];
    }

    /**
    * @notice The users on the white list call this function to claim their tokens.
    *   IMPORTANT: tokenOwner MUST have given "allowance" to Airdrop contract, for this function to work.
    * @param tokenOwner The account from which the tokens will be withdrawn. 
    * @param tokenAddress The address of the Token contract.
    * @param amount The ammount the user whishes to claim. It could be less than the total claimable amount
    */
    function claimMyTokens(address tokenOwner, address tokenAddress, uint256 amount)  external {

        require(whiteList[msg.sender]!=0, "User not on the list");
        require(whiteList[msg.sender]>= amount, "Not enough on user's claimable balance");
        require(IERC20(tokenAddress).allowance(tokenOwner,address(this))>=amount, 
                    "Need more allowance");
        require(IERC20(tokenAddress).balanceOf(tokenAddress)>=amount,
                    "The source account does not have enough balance");

        //transfers the amount
        IERC20(tokenAddress).transferFrom(tokenOwner, msg.sender, amount);

        //Substracts the amount from user in whiteList
        whiteList[msg.sender] = whiteList[msg.sender] - amount;
    }
}