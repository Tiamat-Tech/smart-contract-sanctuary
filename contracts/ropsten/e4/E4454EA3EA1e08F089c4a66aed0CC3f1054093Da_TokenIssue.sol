pragma solidity >=0.6.0 <0.8.0;

import './libraries/Ownable.sol';
import './libraries/SafeMath.sol';
import './interface/IERC20Sumswap.sol';
import './interface/ISumma.sol';
import './interface/IAccessControl.sol';

contract TokenIssue is Ownable {

    using SafeMath for uint256;

    uint256 public constant INIT_MINE_SUPPLY = 32000000 * 10 ** 18;

    uint256 public issuedAmount = INIT_MINE_SUPPLY;

    uint256 public surplusAmount = 2.88 * 10 ** 8 * 10 ** 18;

    uint256 public TOTAL_AMOUNT = 3.2 * 10 ** 8 * 10 ** 18;

    uint256 public constant MONTH_SECONDS = 225 * 24 * 30;

    bytes32 public constant TRANS_ROLE = keccak256("TRANS_ROLE");

    // utc 2021-05-01
    //    uint256 public startIssueTime = 0;
    uint256 public startIssueTime = 0;

    address public summa;

    address public summaPri;

    uint256[] public issueInfo;

    constructor(address _summa,address _summaPri) public {
        summa = _summa;
        summaPri = _summaPri;
        initialize();
    }

    function initialize() private {
        issueInfo.push(1920000 * 10 ** 18);
        issueInfo.push(2035200 * 10 ** 18);
        issueInfo.push(2157312.0000000005 * 10 ** 18);
        issueInfo.push(2286750.72 * 10 ** 18);
        issueInfo.push(2423955.763200001 * 10 ** 18);
        issueInfo.push(2569393.108992 * 10 ** 18);
        issueInfo.push(2723556.6955315205 * 10 ** 18);
        issueInfo.push(2886970.0972634126 * 10 ** 18);
        issueInfo.push(3060188.303099217 * 10 ** 18);
        issueInfo.push(3243799.6012851703 * 10 ** 18);
        issueInfo.push(3438427.577362281 * 10 ** 18);
        issueInfo.push(3644733.232004018 * 10 ** 18);
        issueInfo.push(2575611.4839495043 * 10 ** 18);
        issueInfo.push(2678635.943307485 * 10 ** 18);
        issueInfo.push(2785781.3810397848 * 10 ** 18);
        issueInfo.push(2897212.636281376 * 10 ** 18);
        issueInfo.push(3013101.141732631 * 10 ** 18);
        issueInfo.push(3133625.187401936 * 10 ** 18);
        issueInfo.push(3258970.1948980135 * 10 ** 18);
        issueInfo.push(3389329.0026939344 * 10 ** 18);
        issueInfo.push(3524902.1628016927 * 10 ** 18);
        issueInfo.push(3665898.24931376 * 10 ** 18);
        issueInfo.push(3812534.17928631 * 10 ** 18);
        issueInfo.push(3965035.546457763 * 10 ** 18);
        issueInfo.push(2061818.484158036 * 10 ** 18);
        issueInfo.push(2103054.8538411967 * 10 ** 18);
        issueInfo.push(2145115.9509180207 * 10 ** 18);
        issueInfo.push(2188018.269936382 * 10 ** 18);
        issueInfo.push(2231778.6353351087 * 10 ** 18);
        issueInfo.push(2276414.208041811 * 10 ** 18);
        issueInfo.push(2321942.4922026475 * 10 ** 18);
        issueInfo.push(2368381.3420467 * 10 ** 18);
        issueInfo.push(2415748.9688876346 * 10 ** 18);
        issueInfo.push(2464063.948265387 * 10 ** 18);
        issueInfo.push(2513345.227230695 * 10 ** 18);
        issueInfo.push(2563612.131775309 * 10 ** 18);
        issueInfo.push(2614884.3744108155 * 10 ** 18);
        issueInfo.push(2667182.061899032 * 10 ** 18);
        issueInfo.push(2720525.703137012 * 10 ** 18);
        issueInfo.push(2774936.2171997526 * 10 ** 18);
        issueInfo.push(2830434.941543747 * 10 ** 18);
        issueInfo.push(2887043.6403746223 * 10 ** 18);
        issueInfo.push(2944784.513182115 * 10 ** 18);
        issueInfo.push(3003680.2034457573 * 10 ** 18);
        issueInfo.push(3063753.807514673 * 10 ** 18);
        issueInfo.push(3125028.883664966 * 10 ** 18);
        issueInfo.push(3187529.461338266 * 10 ** 18);
        issueInfo.push(3251280.0505650314 * 10 ** 18);
        issueInfo.push(1658152.825788165 * 10 ** 18);
        issueInfo.push(1674734.3540460467 * 10 ** 18);
        issueInfo.push(1691481.6975865073 * 10 ** 18);
        issueInfo.push(1708396.5145623726 * 10 ** 18);
        issueInfo.push(1725480.479707996 * 10 ** 18);
        issueInfo.push(1742735.2845050762 * 10 ** 18);
        issueInfo.push(1760162.6373501269 * 10 ** 18);
        issueInfo.push(1777764.263723628 * 10 ** 18);
        issueInfo.push(1795541.9063608644 * 10 ** 18);
        issueInfo.push(1813497.3254244728 * 10 ** 18);
        issueInfo.push(1831632.2986787176 * 10 ** 18);
        issueInfo.push(1849948.621665505 * 10 ** 18);
        issueInfo.push(1868448.10788216 * 10 ** 18);
        issueInfo.push(1887132.5889609817 * 10 ** 18);
        issueInfo.push(1906003.9148505912 * 10 ** 18);
        issueInfo.push(1925063.9539990975 * 10 ** 18);
        issueInfo.push(1944314.5935390887 * 10 ** 18);
        issueInfo.push(1963757.7394744793 * 10 ** 18);
        issueInfo.push(1983395.316869224 * 10 ** 18);
        issueInfo.push(2003229.2700379163 * 10 ** 18);
        issueInfo.push(2023261.5627382956 * 10 ** 18);
        issueInfo.push(2043494.1783656788 * 10 ** 18);
        issueInfo.push(2063929.1201493354 * 10 ** 18);
        issueInfo.push(2084568.4113508288 * 10 ** 18);
        issueInfo.push(2105414.0954643367 * 10 ** 18);
        issueInfo.push(2126468.23641898 * 10 ** 18);
        issueInfo.push(2147732.91878317 * 10 ** 18);
        issueInfo.push(2169210.247971002 * 10 ** 18);
        issueInfo.push(2190902.350450712 * 10 ** 18);
        issueInfo.push(2212811.373955219 * 10 ** 18);
        issueInfo.push(2234939.4876947715 * 10 ** 18);
        issueInfo.push(2257288.882571719 * 10 ** 18);
        issueInfo.push(2279861.7713974365 * 10 ** 18);
        issueInfo.push(2302660.389111411 * 10 ** 18);
        issueInfo.push(2325686.9930025246 * 10 ** 18);
        issueInfo.push(2348943.8629325503 * 10 ** 18);
        issueInfo.push(1897946.6412495002 * 10 ** 18);
        issueInfo.push(1913130.2143794964 * 10 ** 18);
        issueInfo.push(1928435.2560945326 * 10 ** 18);
        issueInfo.push(1943862.7381432885 * 10 ** 18);
        issueInfo.push(1959413.6400484347 * 10 ** 18);
        issueInfo.push(1975088.9491688225 * 10 ** 18);
        issueInfo.push(1990889.6607621727 * 10 ** 18);
        issueInfo.push(2006816.7780482706 * 10 ** 18);
        issueInfo.push(2022871.3122726567 * 10 ** 18);
        issueInfo.push(2039054.282770838 * 10 ** 18);
        issueInfo.push(2055366.7170330046 * 10 ** 18);
        issueInfo.push(2071809.6507692689 * 10 ** 18);
        issueInfo.push(2088384.1279754227 * 10 ** 18);
        issueInfo.push(2105091.200999226 * 10 ** 18);
        issueInfo.push(2121931.93060722 * 10 ** 18);
        issueInfo.push(2138907.386052078 * 10 ** 18);
        issueInfo.push(2156018.645140494 * 10 ** 18);
        issueInfo.push(2173266.794301619 * 10 ** 18);
        issueInfo.push(2190652.928656032 * 10 ** 18);
        issueInfo.push(2208178.15208528 * 10 ** 18);
        issueInfo.push(2225843.5773019614 * 10 ** 18);
        issueInfo.push(2243650.3259203774 * 10 ** 18);
        issueInfo.push(2261599.528527741 * 10 ** 18);
        issueInfo.push(2279692.324755963 * 10 ** 18);
        issueInfo.push(2297929.86335401 * 10 ** 18);
        issueInfo.push(2316313.302260842 * 10 ** 18);
        issueInfo.push(2334843.8086789288 * 10 ** 18);
        issueInfo.push(2353522.559148361 * 10 ** 18);
        issueInfo.push(2372350.7396215475 * 10 ** 18);
        issueInfo.push(2391329.54553852 * 10 ** 18);
        issueInfo.push(2410460.1819028277 * 10 ** 18);
        issueInfo.push(2429743.8633580506 * 10 ** 18);
        issueInfo.push(2449181.8142649154 * 10 ** 18);
        issueInfo.push(2468775.2687790347 * 10 ** 18);
        issueInfo.push(2488525.470929267 * 10 ** 18);
        issueInfo.push(2508433.674696701 * 10 ** 18);
        issueInfo.push(2528501.1440942744 * 10 ** 18);
        issueInfo.push(2548729.153247029 * 10 ** 18);
    }

    function issueInfoLength() external view returns (uint256) {
        return issueInfo.length;
    }

    function currentCanIssueAmount() public view returns (uint256){
        uint256 currentTime = block.number;
        if (currentTime <= startIssueTime || startIssueTime <= 0) {
            return INIT_MINE_SUPPLY.sub(issuedAmount);
        }
        uint256 timeInterval = currentTime - startIssueTime;
        uint256 monthIndex = timeInterval.div(MONTH_SECONDS);
        if (monthIndex < 1) {
            return issueInfo[monthIndex].div(MONTH_SECONDS).mul(timeInterval).add(INIT_MINE_SUPPLY).sub(issuedAmount);
        } else if (monthIndex < issueInfo.length) {
            uint256 tempTotal = INIT_MINE_SUPPLY;
            for (uint256 j = 0; j < monthIndex; j++) {
                tempTotal = tempTotal.add(issueInfo[j]);
            }
            uint256 calcAmount = timeInterval.sub(monthIndex.mul(MONTH_SECONDS)).mul(issueInfo[monthIndex].div(MONTH_SECONDS)).add(tempTotal);
            if (calcAmount > TOTAL_AMOUNT) {
                return TOTAL_AMOUNT.sub(issuedAmount);
            }
            return calcAmount.sub(issuedAmount);
        } else {
            return TOTAL_AMOUNT.sub(issuedAmount);
        }
    }

    function currentBlockCanIssueAmount() public view returns (uint256){
        uint256 currentTime = block.number;
        if (currentTime <= startIssueTime || startIssueTime <= 0) {
            return 0;
        }
        uint256 timeInterval = currentTime - startIssueTime;
        uint256 monthIndex = timeInterval.div(MONTH_SECONDS);
        if (monthIndex < 1) {
            return issueInfo[monthIndex].div(MONTH_SECONDS);
        } else if (monthIndex < issueInfo.length) {
            uint256 tempTotal = INIT_MINE_SUPPLY;
            for (uint256 j = 0; j < monthIndex; j++) {
                tempTotal = tempTotal.add(issueInfo[j]);
            }
            uint256 actualBlockIssue = issueInfo[monthIndex].div(MONTH_SECONDS);
            uint256 calcAmount = timeInterval.sub(monthIndex.mul(MONTH_SECONDS)).mul(issueInfo[monthIndex].div(MONTH_SECONDS)).add(tempTotal);
            if (calcAmount > TOTAL_AMOUNT) {
                if (calcAmount.sub(TOTAL_AMOUNT) <= actualBlockIssue) {
                    return actualBlockIssue.sub(calcAmount.sub(TOTAL_AMOUNT));
                }
                return 0;
            }
            return actualBlockIssue;
        } else {
            return 0;
        }

    }

    function issueAnyOne() public {
        uint256 currentCanIssue = currentCanIssueAmount();
        if (currentCanIssue > 0) {
            issuedAmount = issuedAmount.add(currentCanIssue);
            surplusAmount = surplusAmount.sub(currentCanIssue);
            ISumma(summa).issue(address(this), currentCanIssue);
        }
    }

    function withdrawETH() public onlyOwner {
        msg.sender.transfer(address(this).balance);
    }

    function setStart() public onlyOwner {
        if (startIssueTime <= 0) {
            startIssueTime = block.number;
        }
    }

    function transByContract(address to,uint256 amount) public{
        require(IAccessControl(summaPri).hasRole(TRANS_ROLE, _msgSender()), "Caller is not a transfer role");
        if(amount > IERC20Sumswap(summa).balanceOf(address(this))){
            issueAnyOne();
        }
        require(amount <= IERC20Sumswap(summa).balanceOf(address(this)),"not enough,please check code");
        IERC20Sumswap(summa).transfer(to,amount);
    }

    function withdrawToken(address addr) public onlyOwner {
        IERC20Sumswap(addr).transfer(_msgSender(), IERC20Sumswap(addr).balanceOf(address(this)));
    }

    receive() external payable {
    }
}