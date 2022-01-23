pragma solidity 0.8.4;

import "./interfaces/IERC721Minter.sol";
import "./interfaces/IVestingWallet.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./utils/Month.sol";
import "./utils/AddressMonthClaimed.sol";

// enable withdrawal of funds from this contract ( owner only )
contract Treasury is Ownable{
    using SafeERC20 for IERC20;
    // 400 basis points = 4.00 %
    uint256 constant initialRelease = 400;
    // 800 basis points = 8.00 %
    uint256 constant monthlyRelease = 800;
    // 365 / 12 = 30.4 ( in average, 1 month = 30.4 days = 2700000 unix timestamp seconds )
    // need to change this to be configurable ( initial:  uint256 constant monthAverage = 2700000; )
    uint256 monthAverage;
    // mapping for address => mapping (uint256 ( month ) => uint256 ( claimed ))
    mapping (address => AddressMonthClaimed[]) addressMonthClaimed;
    mapping (address => uint256 ) addressMonthClaimedLastUsedPosition;
    // current month
    Month public current;
    address public erc721MinterAddress;
    address public erc20BetrustAddress;
    address public vestingWalletAddress;
    event Claimable(address receipient, uint256 claimable);
    event Value(uint256 value);
    event ThisHappend(string message);
    error NFTOwnersOnly(string message);
    error NothingToClaim(string message);
    error OwnerOnly(string message);
    error NotEnoughBalance(string message);
    error ERC20AddressNotSet(string message);

    constructor(address _erc721MinterAddress, address _vestingWalletAddress, uint256 _monthAverage) public {
        erc721MinterAddress = _erc721MinterAddress;
        vestingWalletAddress = _vestingWalletAddress;
        monthAverage = _monthAverage;
        current = Month({
            start: block.timestamp,
            end: block.timestamp + monthAverage,
            counter: 0
        });
    }
    function setERC20BetrustAddress(address _erc20BetrustAddress) public returns (address){
        if(_erc20BetrustAddress == address(0)){
            revert OwnerOnly({message: '0address'});
        }
        if(msg.sender != address(owner())){
            revert OwnerOnly({message: '!owner'});
        }
        erc20BetrustAddress = _erc20BetrustAddress;
        return erc20BetrustAddress;
    }
    function getCurrentMonth() public view returns (uint256){
        return current.counter;
    }
    function calculateInitialRelease(uint256 amount) public pure returns (uint256){
        return amount * initialRelease / 10000;
    }
    function calculateMonthlyRelease(uint256 amount) public pure returns (uint256){
        return amount * monthlyRelease / 10000;
    }
    // should be renamed to: calculateCurrentlyClaimableForReceipient()
    function calculateCurrentRelease(address recipient, uint256 amount) public returns (uint256){
            // think about terms when claiming should be prevented;
            uint256 claimable = 0;
            for(uint256 i = 0; i <= current.counter; i++){
            AddressMonthClaimed[] memory amc = addressMonthClaimed[recipient];
            // claims happend? ( this condition is entered only if claim already happened for particular month )
            // issue arrises when we fetch `AddressMonthClaimed` that doesn't exist ( even thought I expected )
            // if we had mapping of last inserted position for an address?
            // example: i = 1 ( 2nd month ), if addressMonthClaimedLastUsedPosition = 0; ( 1st month )
            // if ( addressMonthClaimedLastUsedPosition[recipient] >= i ){}
            // was before
            if (addressMonthClaimed[recipient].length > 0){
                // experimenting now
                if ( addressMonthClaimedLastUsedPosition[recipient] >= i ){
                    AddressMonthClaimed memory amcConcrete = amc[i];
                    if(i == 0){
                        if(amcConcrete.claimed == 0){
                            claimable+= calculateInitialRelease(amount) + calculateMonthlyRelease(amount);
                        }
                        else{
                            claimable+=0;
                        }
                    }
                    else{
                        if(amcConcrete.claimed == 0){
                            claimable+= calculateMonthlyRelease(amount);
                        }
                        else{
                            claimable+=0;
                        }
                    }
                }
                //
                else {
                if(i == 0){
                    claimable+= calculateInitialRelease(amount) + calculateMonthlyRelease(amount);
                }
                else{
                    claimable+= calculateMonthlyRelease(amount);
                }
            }
            }
            // 0 claims happend
            else {
                if(i == 0){
                    claimable+= calculateInitialRelease(amount) + calculateMonthlyRelease(amount);
                }
                else{
                    claimable+= calculateMonthlyRelease(amount);
                }
            }
        }
        emit Claimable(recipient, claimable);
        return claimable;
    }
    //     function calculateCurrentRelease(address recipient, uint256 amount) public returns (uint256){
    //         // think about terms when claiming should be prevented;
    //         uint256 claimable = 0;
    //         for(uint256 i = 0; i <= current.counter; i++){
    //         AddressMonthClaimed[] memory amc = addressMonthClaimed[recipient];
    //         // claims happend? ( this condition is entered only if claim already happened for particular month )
    //         // issue arrises when we fetch `AddressMonthClaimed` that doesn't exist ( even thought I expected )
    //         // if we had mapping of last inserted position for an address?
    //         // example: i = 1 ( 2nd month ), if addressMonthClaimedLastUsedPosition = 0; ( 1st month )
    //         // if ( addressMonthClaimedLastUsedPosition[recipient] >= i ){}
    //         // was before
    //         if (addressMonthClaimed[recipient].length > 0){
    //             // experimenting now
    //             if ( addressMonthClaimedLastUsedPosition[recipient] >= i ){
    //                 AddressMonthClaimed memory amcConcrete = amc[i];
    //                 if(i == 0){
    //                     if(amcConcrete.claimed == 0){
    //                         claimable+= calculateInitialRelease(amount) + calculateMonthlyRelease(amount);
    //                     }
    //                     else{
    //                         claimable+=0;
    //                     }
    //                 }
    //                 else{
    //                     if(amcConcrete.claimed == 0){
    //                         claimable+= calculateMonthlyRelease(amount);
    //                     }
    //                     else{
    //                         claimable+=0;
    //                     }
    //                 }
    //             }
    //             //
    //             else {
    //             if(i == 0){
    //                 claimable+= calculateInitialRelease(amount) + calculateMonthlyRelease(amount);
    //             }
    //             else{
    //                 claimable+= calculateMonthlyRelease(amount);
    //             }
    //         }
    //         }
    //         // 0 claims happend
    //         else {
    //             if(i == 0){
    //                 claimable+= calculateInitialRelease(amount) + calculateMonthlyRelease(amount);
    //             }
    //             else{
    //                 claimable+= calculateMonthlyRelease(amount);
    //             }
    //         }
    //     }
    //     emit Claimable(recipient, claimable);
    //     return claimable;
    // }
    function updateCurrentMonth() public {
        if(block.timestamp > current.end){
            current.start = current.end;
            current.end = current.end + monthAverage;
            current.counter+=1;
        }
    }
    function _saveClaimedAmount(address receipient, uint256 _month, uint256 _amount) internal{
        AddressMonthClaimed memory newClaim = AddressMonthClaimed({
            month: _month,
            claimed: _amount
        });
        addressMonthClaimed[receipient].push(newClaim);
        uint256 position = addressMonthClaimed[receipient].length - 1;
        addressMonthClaimedLastUsedPosition[receipient] = position;
    }
    // was before
    // function claim(address recipient) public returns (uint256){
    //     updateCurrentMonth();
    //     IERC721Minter erc721Minter = IERC721Minter(erc721MinterAddress);
    //     IERC20 erc20Betrust = IERC20(erc20BetrustAddress);
    //     uint256 amount = erc721Minter.calculateERC20Value(recipient);
    //     // we should ask vesting wallet here for amount that is releasable
    //     uint256 cliff = calculateCurrentRelease(recipient, amount);
    //     if(erc20BetrustAddress == address(0)){
    //         revert ERC20AddressNotSet({message:'ERC20BetrustTokenAddressNotSet'});
    //     }
    //     if(amount < 1){
    //         revert NFTOwnersOnly({message: '0NFTsOwned'});
    //     }
    //     if(erc20Betrust.balanceOf(address(this)) < amount){
    //         revert NotEnoughBalance({message:'balance<amount'});
    //     }
    //     if(cliff == 0){
    //         revert NothingToClaim({message:'NothingToClaim'});
    //     }
    //     IERC20(erc20BetrustAddress).safeIncreaseAllowance(address(this), cliff);
    //     IERC20(erc20BetrustAddress).safeTransferFrom(address(this), recipient, cliff);
    //     // to-do save amount claimed in addressMonthClaimed
    //     _saveClaimedAmount(recipient, current.counter, amount);
    //     return amount;
    // }
    function claim(address recipient) public returns (uint256){
        IERC721Minter erc721Minter = IERC721Minter(erc721MinterAddress);
        IERC20 erc20Betrust = IERC20(erc20BetrustAddress);
        IVestingWallet vestingWallet = IVestingWallet(vestingWalletAddress);
        uint256 amount = erc721Minter.calculateERC20Value(recipient);
        // we should ask vesting wallet here for amount that is releasable
        vestingWallet.release(recipient, amount);
        if(erc20BetrustAddress == address(0)){
            revert ERC20AddressNotSet({message:'ERC20BetrustTokenAddressNotSet'});
        }
        if(amount < 1){
            revert NFTOwnersOnly({message: '0NFTsOwned'});
        }
        if(erc20Betrust.balanceOf(address(this)) < amount){
            revert NotEnoughBalance({message:'balance<amount'});
        }
        // to-do save amount claimed in addressMonthClaimed
        _saveClaimedAmount(recipient, current.counter, amount);
        return amount;
    }
    function claimTreasuryFunds(address recipient) public{
        if(recipient == address(0)){
            revert OwnerOnly({message: '0address'});
        }
        if(msg.sender != address(owner())){
            revert OwnerOnly({message: '!owner'});
        }
        Address.sendValue(payable(recipient), address(this).balance);
    }
}