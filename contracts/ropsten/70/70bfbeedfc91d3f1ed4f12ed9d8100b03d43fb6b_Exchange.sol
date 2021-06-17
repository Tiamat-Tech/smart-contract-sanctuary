pragma solidity 0.7.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract CreatorFund {
    mapping(address => uint256) public funds;

    IERC20 public paymentToken;

    constructor(address _paymentToken) {
        paymentToken = IERC20(_paymentToken);
    }

    function fundOf(address _creator) external view returns (uint256) {
        return funds[_creator];
    }

    function receiveFund(address _creator, uint256 _amount)
        external
        returns (bool)
    {
        bool transferred =
            paymentToken.transferFrom(msg.sender, address(this), _amount);
        if (transferred) {
            funds[_creator] += _amount;
        }
        return transferred;
    }

    function useFund(
        address _creator,
        address _to,
        uint256 _amount
    ) external returns (bool) {
        // Verifying balance of this creator fund should also be done in the front-end side to prevent spamming gas fee of astropenWallet.
        require(funds[_creator] >= _amount, "Fund is not enough");

        bool transferred = paymentToken.transfer(_to, _amount);
        if (transferred) {
            funds[_creator] -= _amount;
        }
        return transferred;
    }
}