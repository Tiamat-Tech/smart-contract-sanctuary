// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interface/IGoatStatus.sol";


contract GoatStatus is IGoatStatus, Ownable {

    using Strings for uint256;

    address public override saleAddress;
    address public override rentalAddress;
    address public override goatNFTAddress;
    address public override rentalWrapperAddress;
    
    uint256 public currencyCount;
    address[] private currencyList;
    
    mapping(address => bool) public override isCurrency;

    mapping (bytes32 => uint256) private tokenStatus;
    mapping (bytes32 => uint256) private auctionType;
    mapping (bytes32 => uint256) private statusAmounts;

    /** ====================  Event  ==================== */
    event LogSetAddress(address saleAddress, address rentalAddress, address goatNFTAddress, address rentalWrapperAddress);
    event LogSetCurrency(address token, bool enable);
    event LogSetTokenStatus(address indexed owner, address indexed token, uint256 indexed id, uint256 status, uint256 auctionType, uint256 amount);

    /** ====================  modifier  ==================== */
    modifier onlySaleOrRentalContract() {
        require(msg.sender == saleAddress || msg.sender == rentalAddress, "5001: caller is not goatSale or goatRental");
        _;
    }

    /** ====================  set address  ==================== */
    function setAddress(
        address _saleAddress,
        address _rentalAddress,
        address _goatNFTAddress,
        address _rentalWrapperAddress
    ) 
        external
        override
        onlyOwner 
    {
        saleAddress = _saleAddress;
        rentalAddress = _rentalAddress;
        goatNFTAddress = _goatNFTAddress;
        rentalWrapperAddress = _rentalWrapperAddress;

        emit LogSetAddress(_saleAddress, _rentalAddress, _goatNFTAddress, _rentalWrapperAddress);
    }

    /** ====================  currency function  ==================== */
    function setCurrencyToken(
        address _token, 
        bool _enable
    ) 
        external 
        onlyOwner
        override 
    {
        if (!isCurrency[_token] && _enable) {
            currencyCount++;
            currencyList.push(_token);
        } else if (isCurrency[_token] && !_enable) {
            currencyCount--;
        }

        isCurrency[_token] = _enable;

        emit LogSetCurrency(_token, _enable);
    }

    function getCurrencyList() 
        external 
        override 
        view 
        returns (address[] memory resCurrencyList) 
    {
        resCurrencyList = new address[](currencyCount);
        
        uint256 counter = 0;
        if (currencyCount > 0) {
            for (uint256 i = 0; i < currencyList.length; i++) {
                address currency = currencyList[i];
                if (isCurrency[currency]) {
                    resCurrencyList[counter] = currency;
                    counter++;
                }
            }
        }
    }

    /** ====================  token status function  ==================== */
    function setTokenStatus(
        address _owner,
        address _token,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        uint256 _tokenStatus,
        uint256 _auctionType
    ) 
        external 
        onlySaleOrRentalContract 
        override 
    {
        for(uint256 i = 0; i < _ids.length; i++) {
            bytes32 key = keccak256(abi.encodePacked(_owner, _token, _ids[i].toString()));
            tokenStatus[key] = _tokenStatus;
            auctionType[key] = _auctionType;
            statusAmounts[key] = _amounts[i];

            emit LogSetTokenStatus(_owner, _token, _ids[i], _tokenStatus, _auctionType, _amounts[i]);
        }
    }

    function getTokenStatus(
        address _owner,
        address _token,
        uint256 _id
    )
        external
        view
        override
        returns (
            uint256 _tokenStatus,
            uint256 _auctionType,
            uint256 _amount
        )
    {
        bytes32 key = keccak256(abi.encodePacked(_owner, _token, _id.toString()));
        _tokenStatus = tokenStatus[key];
        _auctionType = auctionType[key];
        _amount = statusAmounts[key];
    }

}