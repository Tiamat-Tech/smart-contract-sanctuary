// SPDX-License-Identifier: MIT
/* ============================================== DEFI HUNTERS DAO =================================================
                                           https://defihuntersdao.club/
---------------------------------------------------- Feb 2021 ------------------------------------------------------
 NNNNNNNNL     NNNNNNNNL       .NNNN.      .NNNNNNN.          JNNNNNN) (NN)         JNNNL     (NN)   NNNN     NNNN)   
 NNNNNNNNNN.   NNNNNNNNNN.     JNNNN)     JNNNNNNNNNL       (NNNNNNNN` (NN)        .NNNNN     (NN)   NNNN)   (NNNN)   
 NNN    4NNN   NNN    4NNN     NNNNNN    (NNN`   `NNN)     (NNNF       (NN)        (NNNNN)    (NN)  (NNNNN   JNNNN)   
 NNN     NNN)  NNN     NNN)   (NN)4NN)   NNN)     (NNN     NNN)        (NN)        NNN`NNN    (NN)  (NNNNN) .NNNNN)   
 NNN     4NN)  NNN     4NN)   NNN (NNN   NNN`     `NNN     NNN`        (NN)       (NN) NNN)   (NN)  (NN)NNL (NN(NN)   
 NNN     JNN)  NNN     JNN)  (NNF  NNN)  NNN       NNN     NNN         (NN)       NNN` (NNN   (NN)  (NN)4NN NN)(NNN   
 NNN     NNN)  NNN     NNN)  JNNNNNNNNL  NNN)     (NNN     NNN)        (NN)      .NNNNNNNNN.  (NN)  JNN (NNNNN` NNN   
 NNN    JNNN   NNN    JNNN  .NNNNNNNNNN  4NNN     NNNF     4NNN.       (NN)      JNNNNNNNNN)  (NN)  NNN  NNNNF  NNN   
 NNN___NNNN`   NNN___NNNN`  (NNF    NNN)  NNNNL_JNNNN       NNNNNL_JN  (NNL_____ NNN`   (NNN  (NN)  NNN  (NNN`  NNN   
 NNNNNNNNN`    NNNNNNNNN`   NNN`    (NNN   4NNNNNNNF         4NNNNNNN) (NNNNNNNN(NNF     NNN) (NN)  NNN   NNN   NNN   
 """"""`       """"""`      """      """     """""             `"""""  `""""""""`""`     `""`                         
                    (NN)  NNN
          .NNNN.    (NN)  NNN                                                     JNNNNN.     _NNN
          JNNNN)    (NN)  NNN                                  JNN               NNNNNNNN.  NNNNNN
          NNNNNN    (NN)  NNN     ____.       ____.  .____.    NNN       ___.   (NNF  (NNL  4N"NNN
         (NN)4NN)   (NN)  NNN   JNNNNNNN.   JNNNNN) (NNNNNNL (NNNNNN)  NNNNNNN. NNN)  `NNN     NNN
         NNN (NNN   (NN)  NNN  (NNN""4NNN. NNNN"""` `F" `NNN)`NNNNNN) JNNF 4NNL NNN    NNN     NNN
        (NNF  NNN)  (NN)  NNN  NNN)   4NN)(NNN       .JNNNNN)  NNN   (NNN___NNN NNN    NNN     NNN
        JNNNNNNNNL  (NN)  NNN  NNN    (NN)(NN)      JNNNNNNN)  NNN   (NNNNNNNNN NNN)   NNN     NNN
       .NNNNNNNNNN  (NN)  NNN  NNN)   JNN)(NNN     (NNN  (NN)  NNN   (NNN       4NN)  (NNN     NNN
       (NNF    NNN) (NN)  NNN  (NNN__JNNN  NNNN___.(NNN__NNN)  NNNL_. NNNN____. `NNNL_NNN`     NNN
       NNN`    (NNN (NN)  NNN   4NNNNNNN`  `NNNNNN) NNNNNNNN)  (NNNN) `NNNNNNN)  `NNNNNN)      NNN
       """      """               """"`      `""""`  `""` ""`   `"""`    """""     """"        `" 
================================================================================================================ */
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DDAOClaimAlloc01 is AccessControl
{
	using SafeMath for uint256;
	using SafeERC20 for IERC20;
	IERC20 public token;

	address public owner = _msgSender();
	mapping (address => uint256) claimers;
	mapping (address => uint256) public Sended;

	// testnet
	address public TokenAddr = 0x228845a7D11e6657B2F0934c5E31Aa99B376548D;
	// mainnet
	//address public TokenAddr = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

	uint8 public ClaimCount;
	uint256 public ClaimedAmount;

	event textLog(address,uint256,uint256);

	constructor() 
	{
	_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        claimers[0x871cAEF9d39e05f76A3F6A3Bb7690168f0188925] = 5710 * 10**6;    // 1    10000 / 4290 / 5710
        claimers[0x99CD484206f19A0341f06228BF501aBfee457b95] = 3710 * 10**6;    // 2    8000 / 4290 / 3710
        claimers[0x5dfCDA39199c47a962e39975C92D91E76d16a335] = 3110 * 10**6;    // 3    7400 / 4290 / 3110
        claimers[0x67C5A03d5769aDEe5fc232f2169aC5bf0bb7f18F] = 1716 * 10**6;    // 4    2010 / 294 / 1716
        claimers[0xda7B5C50874a82C0262b4eA6e6001E2b002829E9] = 710 * 10**6;     // 5    5000 / 4290 / 710
        claimers[0xBD0aa1CF9FB2af52d6E81ef95828B0F54baDf343] = 710 * 10**6;     // 6    5000 / 4290 / 710
        claimers[0x0026Ec57900Be57503Efda250328507156dAC982] = 710 * 10**6;     // 7    5000 / 4290 / 710
        claimers[0xa4885613eE8344E5745022b18BD4160AeD4d36db] = 709 * 10**6;     // 8    1003 / 294 / 709
        claimers[0x68cf193fFE134aD92C1DB0267d2062D01FEFDD06] = 706 * 10**6;     // 9    1000 / 294 / 706
        claimers[0x7A4Ad79C4EACe6db85a86a9Fa71EEBD9bbA17Af2] = 706 * 10**6;     // 10   1000 / 294 / 706
        claimers[0x96C7fcC0d3426714Bf62c4B508A0fBADb7A9B692] = 706 * 10**6;     // 11   1000 / 294 / 706
        claimers[0xA183B2f9d89367D935EC1Ebd1d33288a7113a971] = 706 * 10**6;     // 12   1000 / 294 / 706
        claimers[0xB83FC0c399e46b69e330f19baEB87B6832Ec890d] = 706 * 10**6;     // 13   1000 / 294 / 706
        claimers[0xa6700EA3f19830e2e8b35363c2978cb9D5630303] = 706 * 10**6;     // 14   1000 / 294 / 706
        claimers[0xb30ec70639a499af4B4040e2bE7385D44009af7f] = 706 * 10**6;     // 15   1000 / 294 / 706
        claimers[0xB6a95916221Abef28339594161cd154Bc650c515] = 706 * 10**6;     // 16   1000 / 294 / 706
        claimers[0x55fb5D5ae4A4F8369209fEf691587d40227166F6] = 706 * 10**6;     // 17   1000 / 294 / 706
        claimers[0xDE92728804683EC03EFAF6C293e428fc72C2ec95] = 706 * 10**6;     // 18   1000 / 294 / 706
        claimers[0xE40Cc4De1a57e83AAc249Bb4EF833B766f26e2F2] = 706 * 10**6;     // 19   1000 / 294 / 706
        claimers[0xF33782f1384a931A3e66650c3741FCC279a838fC] = 706 * 10**6;     // 20   1000 / 294 / 706
        claimers[0x5D10100d130467cf8DBE2B904100141F1a63318F] = 706 * 10**6;     // 21   1000 / 294 / 706
        claimers[0x8ad686fB89b2944B083C900ec5dDCd2bB02af1D0] = 706 * 10**6;     // 22   1000 / 294 / 706
        claimers[0x18668B0244949570ec637465BAFdDe4d082afa69] = 706 * 10**6;     // 23   1000 / 294 / 706
        claimers[0x184cfB6915daDb4536D397fEcfA4fD8A18823719] = 621 * 10**6;     // 24   915 / 294 / 621
        claimers[0x4D38C1D5f66EA0307be14017deC6A572017aCfE4] = 606 * 10**6;     // 25   900 / 294 / 606
        claimers[0x523bd9c190df614F1e98611793EaA8d1A0914B8B] = 506 * 10**6;     // 26   800 / 294 / 506
        claimers[0x9D1c7A6BF4258B77343f9212e2BaEB9538620911] = 418 * 10**6;     // 27   5000 / 4582 / 418
        claimers[0xa542e3CDd21841CcBcCA70017101eb6a2fc68723] = 417 * 10**6;     // 28   5000 / 4583 / 417
        claimers[0xE088efbff6aA52f679F76F33924C61F2D79FF8E2] = 406 * 10**6;     // 29   700 / 294 / 406
        claimers[0x2E5F97Ce8b95Ffb5B007DA1dD8fE0399679a6F23] = 406 * 10**6;     // 30   700 / 294 / 406
        claimers[0x4F80d10339CdA1EDc936e15E7066C1DBbd8Eb01F] = 383 * 10**6;     // 31   677 / 294 / 383
        claimers[0x42A6396437eBA7bFD6B5195B7134BE64443521ed] = 335 * 10**6;     // 32   629 / 294 / 335
        claimers[0x4460dD70a847481f63e015b689a9E226E8bD5b71] = 306 * 10**6;     // 33   600 / 294 / 306
        claimers[0x1d69159798e83d8eB39842367869D52be5EeD87d] = 306 * 10**6;     // 34   600 / 294 / 306
        claimers[0x81cee999e0cf2DA5b420a5c02649C894F69C86bD] = 306 * 10**6;     // 35   600 / 294 / 306
        claimers[0xdFA56E55811b6F9548F4cB876CC796a6A4071993] = 292 * 10**6;     // 36   586 / 294 / 292
        claimers[0xD05Da93aEa709abCc31979A63eC50F93c29999C4] = 231 * 10**6;     // 37   525 / 294 / 231
        claimers[0x2F275B5bAb3C35F1070eDF2328CB02080Cd62D7D] = 210 * 10**6;     // 38   504 / 294 / 210
        claimers[0xa66a4b8461e4786C265B7AbD1F5dfdb6e487f809] = 208 * 10**6;     // 39   501 / 293 / 208
        claimers[0xb14ae50038abBd0F5B38b93F4384e4aFE83b9350] = 207 * 10**6;     // 40   500 / 293 / 207
        claimers[0xC4b1bb0c1c8c29E234F1884b7787c7e14E1bC0a1] = 207 * 10**6;     // 41   500 / 293 / 207
        claimers[0x2FfF3F5b8560407781dFCb04a068D7635A179EFE] = 207 * 10**6;     // 42   500 / 293 / 207
        claimers[0xfB89fBaFE753873386D6E46dB066c47d8Ef857Fa] = 207 * 10**6;     // 43   500 / 293 / 207
        claimers[0x94d3B13745c23fB57a9634Db0b6e4f0d8b5a1053] = 207 * 10**6;     // 44   500 / 293 / 207
        claimers[0x46f75A3e9702d89E3E269361D9c1e4D2A9779044] = 207 * 10**6;     // 45   500 / 293 / 207
        claimers[0x7eE33a8939C6e08cfE207519e220456CB770b982] = 207 * 10**6;     // 46   500 / 293 / 207
        claimers[0x77724E749eFB937CE0a78e16E1f1ec5979Cba55a] = 207 * 10**6;     // 47   500 / 293 / 207
        claimers[0x7d2D2E04f1Db8B54746eFA719CB62F32A6C84a84] = 207 * 10**6;     // 48   500 / 293 / 207
        claimers[0x3a026dCc53A4bc80b4EdcC155550d444c4e0eBF8] = 207 * 10**6;     // 49   500 / 293 / 207
        claimers[0x585a003aA0b446C0F9baD7b3b0BAc5A809988588] = 207 * 10**6;     // 50   500 / 293 / 207
        claimers[0x390b07DC402DcFD54D5113C8f85d90329A0141ef] = 207 * 10**6;     // 51   500 / 293 / 207
        claimers[0x77167885E8393f1052A8cE8D5dfF2fF16c08f98d] = 207 * 10**6;     // 52   500 / 293 / 207
        claimers[0x498E96c727700a6B7aC2c4EfBd3E9a5DA4F0d137] = 111 * 10**6;     // 53   404 / 293 / 111
        claimers[0xb20Ce1911054DE1D77E1a66ec402fcB3d06c06c2] = 107 * 10**6;     // 54   400 / 293 / 107
        claimers[0xCDCaDF2195c1376f59808028eA21630B361Ba9b8] = 107 * 10**6;     // 55   400 / 293 / 107
        claimers[0x3ef7Bf350074EFDE3FD107ce38e652a10a5750f5] = 87 * 10**6;      // 56   380 / 293 / 87
        claimers[0x6592aB22faD2d91c01cCB4429F11022E2595C401] = 47 * 10**6;      // 57   340 / 293 / 47
        claimers[0xC03992cF3626321b81600a3457225f3f8A732837] = 46 * 10**6;      // 58   339 / 293 / 46
        claimers[0xcB60257f43Db2AE8f743c863d561528EedeaA409] = 40 * 10**6;      // 59   333 / 293 / 40
        claimers[0x5f3E1bf780cA86a7fFA3428ce571d4a6D531575D] = 38 * 10**6;      // 60   3000 / 2962 / 38
        claimers[0x3A79caC51e770a84E8Cb5155AAafAA9CaC83F429] = 38 * 10**6;      // 61   3000 / 2962 / 38
        claimers[0x2aE024C5EE8dA720b9A51F50D53a291aca37dEb1] = 37 * 10**6;      // 62   330 / 293 / 37
        claimers[0xF6d670C5C0B206f44E93dE811054F8C0b6e15905] = 26 * 10**6;      // 63   319 / 293 / 26
        claimers[0x2A716b58127BC4341231833E3A586582b07bBB22] = 17 * 10**6;      // 64   310 / 293 / 17
        claimers[0x330eC7c6AfC3cF19511Ad4041e598B235D44862f] = 8 * 10**6;       // 65   301 / 293 / 8
        claimers[0x23D623D3C6F334f55EF0DDF14FF0e05f1c88A76F] = 7 * 10**6;       // 66   300 / 293 / 7
        claimers[0xeD08e8D72D35428b28390B7334ebe7F9f7a64822] = 7 * 10**6;       // 67   300 / 293 / 7
        claimers[0x237b3c12D93885b65227094092013b2a792e92dd] = 7 * 10**6;       // 68   300 / 293 / 7
        claimers[0x57dA448673AfB7a06150Ab7a92c7572e7c75D2E5] = 7 * 10**6;       // 69   300 / 293 / 7
        claimers[0x65772909024899817Fb7333EC50e4B05534e3dB1] = 7 * 10**6;       // 70   300 / 293 / 7
        claimers[0xDfB78f8181A5e82e8931b0FAEBe22cC4F94CD788] = 7 * 10**6;       // 71   300 / 293 / 7
        claimers[0x1bdaA24527F033ABBe9Bc51b63C0F2a3e913485b] = 7 * 10**6;       // 72   300 / 293 / 7
        claimers[0x49e03A6C22602682B3Fbecc5B181F7649b1DB6Ad] = 7 * 10**6;       // 73   300 / 293 / 7
        claimers[0xF93b47482eCB4BB738A640eCbE0280549d83F562] = 7 * 10**6;       // 74   300 / 293 / 7
        claimers[0xD0929C7f44AB8cda86502baaf9961527fC856DDC] = 7 * 10**6;       // 75   300 / 293 / 7
        claimers[0x61603cD19B067B417284cf9fC94B3ebF5703824a] = 7 * 10**6;       // 76   300 / 293 / 7
        claimers[0xF7f341C7Cf5557536eBADDbe1A55dFf0a4981F51] = 7 * 10**6;       // 77   300 / 293 / 7
        claimers[0x687922176D1BbcBcdC295E121BcCaA45A1f40fCd] = 7 * 10**6;       // 78   300 / 293 / 7
        claimers[0xC64E4d5Ecda0b4D8d9255340c9E3B138c846F17F] = 7 * 10**6;       // 79   300 / 293 / 7
        claimers[0x76b2e65407e9f24cE944B62DB0c82e4b61850233] = 7 * 10**6;       // 80   300 / 293 / 7
        claimers[0x826121D2a47c9D6e71Fd4FED082CECCc8A5381b1] = 7 * 10**6;       // 81   300 / 293 / 7
        claimers[0x882bBB07991c5c2f65988fd077CdDF405FE5b56f] = 7 * 10**6;       // 82   300 / 293 / 7
        claimers[0x0c2262b636d91Ec5582f4F95b40988a56496B8f1] = 7 * 10**6;       // 83   300 / 293 / 7
        claimers[0x931ddC55Ea7074a190ded7429E82dfAdFeDC0269] = 7 * 10**6;       // 84   300 / 293 / 7
        claimers[0x9867EBde73BD54d2D7e55E28057A5Fe3bd2027b6] = 7 * 10**6;       // 85   300 / 293 / 7
        claimers[0xA0f31bF73eD86ab881d6E8f5Ae2E4Ec9E81f04Fc] = 7 * 10**6;       // 86   300 / 293 / 7
        claimers[0x2F48e68D0e507AF5a278130d375AA39f4966E452] = 7 * 10**6;       // 87   300 / 293 / 7
        claimers[0x6F255406306D6D78e97a29F7f249f6d2d85d9801] = 7 * 10**6;       // 88   300 / 293 / 7
        claimers[0xC60Eec28b22F3b7A70fCAB10A5a45Bf051a83d2B] = 7 * 10**6;       // 89   300 / 293 / 7
        claimers[0x6B745dEfEE931Ee790DFe5333446eF454c45D8Cf] = 7 * 10**6;       // 90   300 / 293 / 7
        claimers[0x2E72d671fa07be54ae9671f793895520268eF00E] = 7 * 10**6;       // 91   300 / 293 / 7
        claimers[0xB4264E181207E2e701f72331E0998c38e04c8512] = 7 * 10**6;       // 92   300 / 293 / 7
        claimers[0xb521154e8f8978f64567FE0FA7359Ab47f7363fA] = 7 * 10**6;       // 93   300 / 293 / 7
        claimers[0xb5C2Bc605CfE15d31554C6aD0B6e0844132BE3cb] = 7 * 10**6;       // 94   300 / 293 / 7
        claimers[0x2CE83785eD44961959bf5251e85af897Ba9ddAC7] = 7 * 10**6;       // 95   300 / 293 / 7
        claimers[0xbD0Ad704f38AfebbCb4BA891389938D4177A8A92] = 7 * 10**6;       // 96   300 / 293 / 7
        claimers[0xbF6077D70CAEDF2D36e914273be8e8D4B2c5adF1] = 7 * 10**6;       // 97   300 / 293 / 7
        claimers[0x093E088901909dEecC1b4a1479fBcCE1FBEd31E7] = 7 * 10**6;       // 98   300 / 293 / 7
        claimers[0x80C01D52e55e5e870C43652891fb44D1810b28A2] = 6 * 10**6;       // 99   6 / 0 / 6
	}

	// Start: Admin functions
	event adminModify(string txt, address addr);
	modifier onlyAdmin() 
	{
		require(IsAdmin(_msgSender()), "Access for Admin's only");
		_;
	}

	function IsAdmin(address account) public virtual view returns (bool)
	{
		return hasRole(DEFAULT_ADMIN_ROLE, account);
	}
	function AdminAdd(address account) public virtual onlyAdmin
	{
		require(!IsAdmin(account),'Account already ADMIN');
		grantRole(DEFAULT_ADMIN_ROLE, account);
		emit adminModify('Admin added',account);
	}
	function AdminDel(address account) public virtual onlyAdmin
	{
		require(IsAdmin(account),'Account not ADMIN');
		require(_msgSender()!=account,'You can`t remove yourself');
		revokeRole(DEFAULT_ADMIN_ROLE, account);
		emit adminModify('Admin deleted',account);
	}
	// End: Admin functions

	function TokenAddrSet(address addr)public virtual onlyAdmin
	{
		TokenAddr = addr;
	}

	function ClaimCheckEnable(address addr)public view returns(bool)
	{
		bool status = false;
		if(claimers[addr] > 0)status = true;
		return status;
	}
	function ClaimCheckAmount(address addr)public view returns(uint value)
	{
		value = claimers[addr];
	}
	function Claim(address addr)public virtual
	{
		//address addr;
		//addr = _msgSender();
		require(TokenAddr != address(0),"Admin not set TokenAddr");

		bool status = false;
		if(claimers[addr] > 0)status = true;

		require(status,"Token has already been requested or Wallet is not in the whitelist [check: Sended and claimers]");
		uint256 SendAmount;
		SendAmount = ClaimCheckAmount(addr);
		if(Sended[addr] > 0)SendAmount = SendAmount.sub(Sended[addr]);
		Sended[addr] = SendAmount;
		claimers[addr] = 0;

		IERC20 ierc20Token = IERC20(TokenAddr);
		require(SendAmount <= ierc20Token.balanceOf(address(this)),"Not enough tokens to receive");
		ierc20Token.safeTransfer(addr, SendAmount);

		ClaimCount++;
		ClaimedAmount = ClaimedAmount.add(SendAmount);
		emit textLog(addr,SendAmount,claimers[addr]);
	}
	
	function AdminGetCoin(uint256 amount) public onlyAdmin
	{
		payable(_msgSender()).transfer(amount);
	}

	function AdminGetToken(address tokenAddress, uint256 amount) public onlyAdmin 
	{
		IERC20 ierc20Token = IERC20(tokenAddress);
		ierc20Token.safeTransfer(_msgSender(), amount);
	}
	function balanceOf(address addr)public view returns(uint256 balance)
	{
		balance = claimers[addr];
	}
        function TokenBalance() public view returns(uint256)
        {
                IERC20 ierc20Token = IERC20(TokenAddr);
                return ierc20Token.balanceOf(address(this));
        }

}