// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IERC20Proxy {

  event TransferWithReference(
    address tokenAddress,
    address to,
    uint256 amount,
    bytes indexed paymentReference
  );

  function transferFromWithReference(
    address _tokenAddress,
    address _to,
    uint256 _amount,
    bytes calldata _paymentReference
  ) external;
}

interface IEthereumProxy {

    /// Event to declare a transfer with a reference
    event TransferWithReference(
        address to, 
        uint256 amount, 
        bytes indexed paymentReference
    );

    /// @notice Performs an Ethereum transfer with a reference
    /// @param _to Transfer recipient
    /// @param _paymentReference Reference of the payment related
    function transferWithReference(
        address payable _to, 
        bytes calldata _paymentReference
    ) external;
}


contract BatchPayments {
    using SafeERC20 for IERC20;

    IERC20Proxy public erc20Proxy;
    IEthereumProxy public ethereumProxy;

    error Reverted();

    event EthTransfer(address indexed Payer, uint256 receivers);
    
    constructor() {
        erc20Proxy  = IERC20Proxy(0x4556e28DCf17703B94B7BAefF190253ca0D8bA3D);
        ethereumProxy = IEthereumProxy(0x75a8F4Cf5F7eA92D17f12471Da35f6D01D1Fb2f0);
    }

    function recieve() external payable {
        revert Reverted();
    }

    ///
    function batchEtherPayment(
        address[] calldata recipients, 
        uint256[] calldata values
    ) 
        external 
        payable 
    {
        for (uint256 i = 0; i < recipients.length; i++)
            payable(recipients[i]).transfer(values[i]);
        uint256 balance = address(this).balance;
        if (balance > 0)
            payable(msg.sender).transfer(balance);
        
        emit EthTransfer(msg.sender, recipients.length);
    }

    function batchEtherPaymentWithReference(
        address[] calldata recipients, 
        bytes[] calldata paymentReference
    )       
        external 
        payable 
    {
        for (uint256 i = 0; i < recipients.length; i++)
            ethereumProxy.transferWithReference(
                payable(recipients[i]), 
                paymentReference[i]
            );
    }

    /// @notice 
    function batchERC20Payment(
        IERC20 token, 
        address[] calldata recipients, 
        uint256[] calldata values
    ) external {
        for (uint256 i = 0; i < recipients.length; i++)
            token.transferFrom(msg.sender, recipients[i], values[i]);
    }

    /// @notice
    function batchERC20PaymentWithReference(
        IERC20 token, 
        address[] calldata recipients, 
        uint256[] calldata values,
        bytes[] calldata paymentReference
    ) external {

        for (uint256 i = 0; i < recipients.length; i++) {
           (bool status, ) = address(erc20Proxy).delegatecall(
            abi.encodeWithSignature(
            "transferFromWithReference(address,address,uint256,bytes)",
                address(token),
                recipients[i], 
                values[i],
                paymentReference[i]
                )
            );
        require(status, "transferFromWithReference failed");
        }
    }
}