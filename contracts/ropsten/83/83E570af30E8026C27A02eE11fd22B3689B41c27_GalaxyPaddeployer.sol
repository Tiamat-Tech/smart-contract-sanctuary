pragma solidity ^0.8.9;

// SPDX-License-Identifier: MIT

import './PreSaleBnb.sol';

contract GalaxyPaddeployer is ReentrancyGuard {

    using SafeMath for uint256;
    address payable public admin;
    IERC20 public token;
    address public routerAddress;

    uint256 public adminFee;
    uint256 public adminFeePercent;

    mapping(address => bool) public isPreSaleExist;
    mapping(address => address) public getPreSale;
    address[] public allPreSales;

    modifier onlyAdmin(){
        require(msg.sender == admin,"GalaxyPad: Not an admin");
        _;
    }

    event PreSaleCreated(address indexed _token, address indexed _preSale, uint256 indexed _length);

    constructor( ) {
        admin = payable(msg.sender);
        adminFee = 100e18;
        adminFeePercent = 2;
        routerAddress = (0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    }

    receive() payable external{}


    function createPreSaleBNB(
        IERC20 _token,
        uint256 [6] memory values
    ) external isHuman returns(address preSaleContract) {
        token = _token;
        require(address(token) != address(0), 'GalaxyPad: ZERO_ADDRESS');
        require(isPreSaleExist[address(token)] == false, 'GalaxyPad: PRESALE_EXISTS'); // single check is sufficient

        bytes memory bytecode = type(preSaleBnb).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token, msg.sender));

        assembly {
            preSaleContract := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }

        IPreSale(preSaleContract).initialize(
            msg.sender,
            token,
            values,
            routerAddress
        );
        
        uint256 tokenAmount = getTotalNumberOfTokens(
            values[0],
            values[4],
            values[2],
            values[5]
        );

        tokenAmount = tokenAmount.mul(10 ** (token.decimals()));
        token.transferFrom(msg.sender, preSaleContract, tokenAmount);
        getPreSale[address(token)] = preSaleContract;
        isPreSaleExist[address(token)] = true; // setting preSale for this token to aviod duplication
        allPreSales.push(preSaleContract);

        emit PreSaleCreated(address(token), preSaleContract, allPreSales.length);
    }

    function getTotalNumberOfTokens(
        uint256 _tokenPrice,
        uint256 _listingPrice,
        uint256 _hardCap,
        uint256 _liquidityPercent
    ) public pure returns(uint256){

        uint256 tokensForSell = _hardCap.mul(_tokenPrice).mul(1000).div(1e18);
        tokensForSell = tokensForSell.add(tokensForSell.mul(2).div(100));
        uint256 tokensForListing = (_hardCap.mul(_liquidityPercent).div(100)).mul(_listingPrice).mul(1000).div(1e18);
        return tokensForSell.add(tokensForListing).div(1000);

    }

    function setAdmin(address payable _admin) external onlyAdmin{
        admin = _admin;
    }

    function setRouterAddress(address _routerAddress) external onlyAdmin{
        routerAddress = _routerAddress;
    }
    
    function setAdminFee(uint256 _fee) external onlyAdmin{
        adminFee = _fee;
    }
    
    function getAllPreSalesLength() external view returns (uint) {
        if(allPreSales.length == 0){
            return allPreSales.length;
        }else{
            return allPreSales.length-1;
        }
    }

    function getCurrentTime() public view returns(uint256){
        return block.timestamp;
    }

}