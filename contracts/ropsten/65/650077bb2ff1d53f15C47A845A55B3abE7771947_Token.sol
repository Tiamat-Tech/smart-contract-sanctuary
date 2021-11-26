pragma solidity ^0.5.16;
//cToken
import "./CErc20Delegator.sol";
import "./CErc20Delegate.sol";
import "./Token.sol";
//comptroller
import "./Unitroller.sol";
import "./ComptrollerG1.sol";
//interestModel
import "./WhitePaperInterestRateModel.sol";
//priceOracle
import "./SimplePriceOracle.sol";

contract Setup {
    Token public uni;
    CErc20Delegator public cUni;
    CErc20Delegate    public cUniDelegate;
    Unitroller        public unitroller;
    ComptrollerG1    public comptroller;
    ComptrollerG1    public unitrollerProxy;
    WhitePaperInterestRateModel    public whitePaper;
    SimplePriceOracle    public priceOracle;

    constructor() public payable{
        //先初始化priceOracle
        address oracleAddr = 0xB3aF0F6373Be07Cb97D83178493b55b8D74fB53b;
        priceOracle = SimplePriceOracle(oracleAddr);
        //再初始化whitepaper
        address whitPaperAddr = 0xf15D865A2B4059c0776B3DA5FaF0AD46016Eb383;
        whitePaper = WhitePaperInterestRateModel(whitPaperAddr);
        //再初始化comptroller
        //address unitrollerAddr = 0x07A63542af056f7559555B819De644f22d64869a;
        //unitroller = Unitroller(unitrollerAddr);
        unitroller = new Unitroller();

        address comptrollerAddr = 0xB1858Ed4C91A6871D1D0654268BbC166D947E646;
        comptroller = ComptrollerG1(comptrollerAddr);
        unitrollerProxy = ComptrollerG1(address(unitroller));

        unitroller._setPendingImplementation(address(comptroller));
        comptroller._become(unitroller, priceOracle, 500000000000000000, 20, true);

        unitrollerProxy._setPriceOracle(priceOracle);
        unitrollerProxy._setCloseFactor(500000000000000000);
        unitrollerProxy._setMaxAssets(20);
        unitrollerProxy._setLiquidationIncentive(1080000000000000000);
        //最后初始化cToken

        address uniAddr = 0x650077bb2ff1d53f15C47A845A55B3abE7771947;
        uni = Token(uniAddr);

        address cUniDelegateAddr = 0x5FDaD83C21Ea31DBab4525dba2697185dbb0F02F;
        cUniDelegate = CErc20Delegate(cUniDelegateAddr);

        bytes memory data = new bytes(0x00);
        cUni = new CErc20Delegator(
            address(uni),
            ComptrollerInterface(address(unitroller)),
            InterestRateModel(address(whitePaper)),
            200000000000000000000000000,
            "Compound Uniswap",
            "cUNI",
            8,
            address(uint160(address(this))),
            address(cUniDelegate),
            data
        );
        cUni._setImplementation(address(cUniDelegate), false, data);
        cUni._setReserveFactor(250000000000000000);

        //设置uni的价格
        priceOracle.setUnderlyingPrice(CToken(address(cUni)), 1e18);
        //支持的markets
        unitrollerProxy._supportMarket(CToken(address(cUni)));
        unitrollerProxy._setCollateralFactor(CToken(address(cUni)),
            600000000000000000);
    }
}