pragma solidity 0.8.4;

import "./interfaces/IERC721Minter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./utils/Month.sol";
import "./utils/AddressMonthClaimed.sol";

contract Treasury is Ownable{
    using SafeERC20 for IERC20;
    // 400 basis points = 4.00 %
    uint256 constant initialRelease = 400;
    // 800 basis points = 8.00 %
    uint256 constant monthlyRelease = 800;
    // 365 / 12 = 30.4 ( in average, 1 month = 30.4 days = 2700000 unix timestamp seconds )
    uint256 constant monthAverage = 2700000;
    // mapping for address => mapping (uint256 ( month ) => uint256 ( claimed ))
    mapping (address => AddressMonthClaimed[]) addressMonthClaimed;
    // current month
    Month public current;
    address public erc721MinterAddress;
    address public erc20BetrustAddress;
    event Current(uint256 current);
    event NewPendingOwner(address pendingAdmin);
    event amc(AddressMonthClaimed amc);
    error NFTOwnersOnly(string message);
    error OwnerOnly(string message);
    error NotEnoughBalance(string message);
    error ERC20AddressNotSet(string message);

    constructor(address _erc721MinterAddress) public {
        erc721MinterAddress = _erc721MinterAddress;
        current = Month({
            start: block.timestamp,
            end: block.timestamp + monthAverage,
            counter: 1
        });
        emit Current(current.counter);
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
    function calculateInitialRelease(uint256 amount) public pure returns (uint256){
        return amount * initialRelease / 10000;
    }
    function calculateMonthlyRelease(uint256 amount) public pure returns (uint256){
        return amount * monthlyRelease / 10000;
    }
    // was before
    // function calculateCurrentRelease(address recipient, uint256 amount) public view returns (uint256){
    //         uint256 sum = 0;
    //         for(uint256 i = 0; i <= current.counter; i++){
    //             AddressMonthClaimed memory amc = addressMonthClaimed[recipient][i];
    //             if(i == 0){
    //                 if(amc.claimed == 0){
    //                     sum+= calculateInitialRelease(amount) + calculateMonthlyRelease(amount);
    //                 }
    //                 else{
    //                     sum+=0;
    //                 }
    //             }
    //             else{
    //                 if(amc.claimed == 0){
    //                     sum+= calculateMonthlyRelease(amount);
    //                 }
    //                 else{
    //                     sum+=0;
    //                 }
    //             }
    //         }
    //         return calculateMonthlyRelease(amount + sum);
    // }

    // experimenting now
    function calculateCurrentRelease(address recipient, uint256 amount) public returns (uint256){
        // think about terms when claiming should be prevented;
            uint256 sum = 0;
            for(uint256 i = 0; i < current.counter; i++){
            emit Current(i);
            emit Current(current.counter);
            // problematic line, obviously ( AddressMonthClaimed memory amc = addressMonthClaimed[recipient][i] )
            if(addressMonthClaimed[recipient][i].claimed == 0){
                emit Current(10);
            }
            // problematic line, obviously
            // struct exists?
            // if(amc[i].claimed != 0){
            //     AddressMonthClaimed memory amcConcrete = amc[i];
            //     if(i == 0){
            //         if(amcConcrete.claimed == 0){
            //             sum+= calculateInitialRelease(amount) + calculateMonthlyRelease(amount);
            //         }
            //         else{
            //             sum+=0;
            //         }
            //     }
            //     else{
            //         if(amcConcrete.claimed == 0){
            //             sum+= calculateMonthlyRelease(amount);
            //         }
            //         else{
            //             sum+=0;
            //         }
            //     }
            // }
            // else calculate
            // else {
            //     if(i == 0){
            //         sum+= calculateInitialRelease(amount) + calculateMonthlyRelease(amount);
            //     }
            //     sum+= calculateMonthlyRelease(amount);
            // }
        }
        return sum;
    }
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
    }
    function claim(address recipient) public returns (uint256){
        updateCurrentMonth();   
        IERC721Minter erc721Minter = IERC721Minter(erc721MinterAddress);
        IERC20 erc20Betrust = IERC20(erc20BetrustAddress);
        uint256 amount = erc721Minter.calculateERC20Value(recipient);
        uint256 cliff = calculateCurrentRelease(recipient, amount);
        if(erc20BetrustAddress == address(0)){
            revert ERC20AddressNotSet({message:'ERC20BetrustTokenAddressNotSet'});
        }
        if(amount < 1){
            revert NFTOwnersOnly({message: '0NFTsOwned'});
        }
        if(erc20Betrust.balanceOf(address(this)) < amount){
            revert NotEnoughBalance({message:'balance<amount'});
        }
        IERC20(erc20BetrustAddress).safeIncreaseAllowance(address(this), cliff);
        IERC20(erc20BetrustAddress).safeTransferFrom(address(this), recipient, cliff);
        // to-do save amount claimed in addressMonthClaimed
        _saveClaimedAmount(recipient, current.counter, amount);
        return amount;
    }
}