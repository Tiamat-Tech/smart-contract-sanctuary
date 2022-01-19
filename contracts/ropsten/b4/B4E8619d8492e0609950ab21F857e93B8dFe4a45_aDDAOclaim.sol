// SPDX-License-Identifier: MIT
/* ======================================================== DEFI HUNTERS DAO ==========================================================================
                                                       https://defihuntersdao.club/
------------------------------------------------------------ January 2021 -----------------------------------------------------------------------------
           #######       #######          ####         #####             ####      ###   #######     #######       #######        #####      #######   
           ##########    ##########      ######      #########          ######     ###   #########   ##########    #########    #########    ######### 
           ###########   ###########     ######     ###########         ######     ###   ##########  ###########   ##########  ###########   ##########
#######    ###    ####   ###    ####     ######    ####     ####        ######     ###   ###   ####  ###    ####   ###   #### ####     ####  ###   #### 
########   ###     ####  ###     ####   ########   ####     ####       ########    ###   ###   ####  ###     ####  ###   #### ####     ####  ###   ####
     ####  ###     ####  ###     ####   ###  ###   ###       ###       ###  ###    ###   #########   ###     ####  #########  ###       ###  ######### 
 ########  ###     ####  ###     ####  ##########  ###       ###      ##########   ###   ########    ###     ####  ########   ###       ###  ########  
#########  ###     ####  ###     ####  ##########  ####     ####      ##########   ###   ###  ####   ###     ####  ###  ####  ####     ####  #####      
###  ####  ###    ####   ###    ####  ############ #####   #####     ############  ###   ###   ####  ###    ####   ###   #### #####   #####  ###        
#########  ##########    ##########   ####    ####  ###########      ####    ####  ###   ###   ####  ##########    ###   ####  ###########   ###        
#########  #########     #########    ###     ####   #########       ###     ####  ###   ###   ####  #########     ###   ####   #########    ###        
==================================================================================================================================================== */
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract aDDAOclaim is AccessControl
{
	using SafeMath for uint256;
	using SafeERC20 for IERC20;
	IERC20 public token;

	address public Creator = _msgSender();
	mapping (address => uint256) claimers;
	mapping (address => uint256) public Sended;

	address public TokenAddr = 0xeFC996CE8341cd36c55412B51DF5BBCa429a7617;

	uint8 public ClaimCount;
	uint256 public ClaimedAmount;

	event textLog(address,uint256,uint256);

	constructor() 
	{
	_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
		claimers[0xECCFbC5B04Da35D611EF8b51099fA5Bc6639d73b] = 625000000000000000000000; // 1
		claimers[0x7777420DD0E5f0E13D51C831f77495a057aaBBBB] = 332500000000000000000000; // 2
		claimers[0xEB2d2F1b8c558a40207669291Fda468E50c8A0bB] = 312500000000000000000000; // 3
		claimers[0x8595f8141E90fcf6Ee17C85142Fd03d3138A6198] = 312500000000000000000000; // 4
		claimers[0xCf57A3b1C076838116731FDe404492D9d168747A] = 312500000000000000000000; // 5
		claimers[0x07587c046d4d4BD97C2d64EDBfAB1c1fE28A10E5] = 312500000000000000000000; // 6
		claimers[0x5555DADcb41fB48934b02A0DBF793b97541F7777] = 312500000000000000000000; // 7
		claimers[0x0026Ec57900Be57503Efda250328507156dAC982] = 93750000000000000000000; // 8
		claimers[0xd53b873683Df491553eea6a069770144Ad30F3A9] = 93750000000000000000000; // 9
		claimers[0x7701E5Bf2D8aE221f23F460FE73420eeE86d2872] = 78125000000000000000000; // 10
		claimers[0x1A72CCE42499361FFF103855F845B8cFc1c25b67] = 62500000000000000000000; // 11
		claimers[0x1b9E791f3259dcEF7D1e366b33F644841c2461a5] = 62500000000000000000000; // 12
		claimers[0x4E560A3ecfe9E5386E727c76f6e2690aE7a1Bc82] = 58437500000000000000000; // 13
		claimers[0xCeeA2d354c6357ed7e10e629bd2734119A5B3c21] = 48351171684062000000000; // 14
		claimers[0x98BCE99aa50CB33eca0dDcb2a04404B80dEd3F3E] = 46875000000000000000000; // 15
		claimers[0xeE74a1e81B6C55e3D02D05D7CaE9FD6BCee0E651] = 39062500000000000000000; // 16
		claimers[0x9f8eF2849133286860A8216cA11359381706Fa4a] = 39734042553191500000000; // 17
		claimers[0x8D88F01D183DDfD30782E565fdBcD85c14413cAF] = 34375000000000000000000; // 18
		claimers[0xB862D5e30DE97368801bDC24A53aD90F56a9C068] = 33021339193750000000000; // 19
		claimers[0x4F9ef189F387e0a91d46812cFB2ecE0d558a471C] = 31562500000000000000000; // 20
		claimers[0x79e5c907b9d4Af5840C687e6975a1C530895454a] = 31318750000000000000000; // 21
		claimers[0xFB81414570E338E28C98417c38A3A5c9C6503516] = 31253125000000000000000; // 22
		claimers[0x35e55F287EFA64dAb88A289a32F9e5942Ab28b18] = 31250000000000000000000; // 23
		claimers[0xda7B5C50874a82C0262b4eA6e6001E2b002829E9] = 31250000000000000000000; // 24
		claimers[0x7Ed273A361D6bb16833f0E563C313e205738112f] = 31250000000000000000000; // 25
		claimers[0x3cB704A5FB4428796b728DF7e4CbC67BCA1497Ae] = 31250000000000000000000; // 26
		claimers[0xEc8c50223E785C3Ff21fd9F9ABafAcfB1e2215FC] = 31250000000000000000000; // 27
		claimers[0x871cAEF9d39e05f76A3F6A3Bb7690168f0188925] = 31250000000000000000000; // 28
		claimers[0xbE20DFb456b7E81f691A8445d073e56602E3cefa] = 31250000000000000000000; // 29
		claimers[0x710A169B822Bf51b8F8E6538c63deD200932BB29] = 31250000000000000000000; // 30
		claimers[0x6Fa98A4254c7E9Ec681cCeb3Cb8D64a70Dbea256] = 31250000000000000000000; // 31
		claimers[0x524b7c9B4cA33ba72445DFd2d6404C81d8D1F2E3] = 31250000000000000000000; // 32
		claimers[0x92fc7C69AD976e188b004Cd60Cbd0C8448c770bA] = 31250000000000000000000; // 33
		claimers[0x32f8E5d3F4039d1DF89B6A1e544288289A500Fd1] = 31250000000000000000000; // 34
		claimers[0x256b09f7Ae7d5fec8C8ac77184CA09F867BbBf4c] = 31250000000000000000000; // 35
		claimers[0xC9D15F4E6f1b37CbF0E8068Ff84B5282edEF9707] = 31250000000000000000000; // 36
		claimers[0x8ad686fB89b2944B083C900ec5dDCd2bB02af1D0] = 31250000000000000000000; // 37
		claimers[0xe1C69F432f2Ba9eEb33ab4bDd23BD417cb89886a] = 31250000000000000000000; // 38
		claimers[0x355e03d40211cc6b6D18ce52278e91566fF29839] = 31250000000000000000000; // 39
		claimers[0x4F80d10339CdA1EDc936e15E7066C1DBbd8Eb01F] = 15782000000000000000000; // 40
		claimers[0x4959769500C751f32FEa39012b5244C722c643Dd] = 10667532039798000000000; // 41
		claimers[0x89BFc312583bE9a9E518928F24eBdc03270C7375] = 10648936170213000000000; // 42
		claimers[0x4d35B59A3C1F59D5fF94dD7B2b3A1198378c4678] = 10639598053191000000000; // 43
		claimers[0xa73eAf66656270Cc2b27304a170a3ACbd666B54B] = 10638297872340000000000; // 44
		claimers[0xb647f84d4DC1C9bD9Bf42BfFe0FEA69C9F2bb843] = 10638297872340000000000; // 45
		claimers[0x33Ad49856da25b8E2E2D762c411AEda0D1727918] = 10638297872340000000000; // 46
		claimers[0x420ACe7D85821A887891A43CC8a2aFE0D84433a9] = 10638297872340000000000; // 47
		claimers[0x3A484fc4E7873Bd79D0B9B05ED6067A549eC9f49] = 10638297872340000000000; // 48
		claimers[0x7AE29F334D7cb67b58df5aE2A19F360F1Fd3bE75] = 10638297872340000000000; // 49
		claimers[0xd09153823Cf2f29ed6B7E959739bca97C1D273B8] = 10638297872340000000000; // 50
		claimers[0xDE92728804683EC03EFAF6C293e428fc72C2ec95] = 10638297872340000000000; // 51
		claimers[0x3A79caC51e770a84E8Cb5155AAafAA9CaC83F429] = 10638297872340000000000; // 52
		claimers[0x5A20ab4F35Dba889D1f6244c0D53A153DCd28766] = 9444461942553200000000; // 53
		claimers[0x79440849d5BA6Df5fb1F45Ff36BE3979F4271fa4] = 7518148665957400000000; // 54
		claimers[0xbD0Ad704f38AfebbCb4BA891389938D4177A8A92] = 7446808510638300000000; // 55
		claimers[0x21130c9b9D00BcB6cDAF24d0E85809cf96251F35] = 6489361702127700000000; // 56
		claimers[0x42A6396437eBA7bFD6B5195B7134BE64443521ed] = 6412765957446800000000; // 57
		claimers[0xC3aB2C2Eb604F159C842D9cAdaBBa2d6254c43d5] = 6389361702127700000000; // 58
		claimers[0x5D10100d130467cf8DBE2B904100141F1a63318F] = 6382978723404300000000; // 59
		claimers[0x585a003aA0b446C0F9baD7b3b0BAc5A809988588] = 6382978723404300000000; // 60
		claimers[0x125EaE40D9898610C926bb5fcEE9529D9ac885aF] = 6382978723404300000000; // 61
		claimers[0x24f39151D6d8A9574D1DAC49a44F1263999D0dda] = 5319148936170200000000; // 62
		claimers[0xe6BB1bEBF6829ca5240A80F7076E4CFD6Ee540ae] = 5276595744680900000000; // 63
		claimers[0xf3143D244F33eb40252464d3b692FA519847B7a9] = 4851063829787200000000; // 64
		claimers[0x764108BAcf10e30F6f249d17E7612fB9008923F0] = 4851063829787200000000; // 65
		claimers[0xF6d670C5C0B206f44E93dE811054F8C0b6e15905] = 4289361702127700000000; // 66
		claimers[0x73073A915f8a582B061091368486fECA640552BA] = 4274680851063800000000; // 67
		claimers[0xa66a4b8461e4786C265B7AbD1F5dfdb6e487f809] = 4256595744680900000000; // 68
		claimers[0x07b449319D200b1189406c58967348c5bA0D4083] = 4256457456721200000000; // 69
		claimers[0x15c5F3a14d4492b1a26f4c6557251a6F247a2Dd5] = 4255319148936200000000; // 70
		claimers[0x7eE33a8939C6e08cfE207519e220456CB770b982] = 4255319148936200000000; // 71
		claimers[0x2aE024C5EE8dA720b9A51F50D53a291aca37dEb1] = 4255319148936200000000; // 72
		claimers[0x0f5A11bEc9B124e73F51186042f4516F924353e0] = 4255319148936200000000; // 73
		claimers[0x2230A3fa220B0234E468a52389272d239CEB809d] = 4255319148936200000000; // 74
		claimers[0x65028EEE0F81E76A8Ffc39721eD4c18643cB9A4C] = 4255319148936200000000; // 75
		claimers[0x931ddC55Ea7074a190ded7429E82dfAdFeDC0269] = 4255319148936200000000; // 76
		claimers[0xB6a95916221Abef28339594161cd154Bc650c515] = 3765957446808500000000; // 77
		claimers[0x093E088901909dEecC1b4a1479fBcCE1FBEd31E7] = 3617021276595700000000; // 78
		claimers[0xb521154e8f8978f64567FE0FA7359Ab47f7363fA] = 3287234042553200000000; // 79
		claimers[0x9867EBde73BD54d2D7e55E28057A5Fe3bd2027b6] = 3272787242553200000000; // 80
		claimers[0x4D3c3E7F5EBae3aCBac78EfF2457a842Ab86577e] = 3251063829787200000000; // 81
		claimers[0x522b76c8f7764009178B3Fd89bBB0134ADEC44a8] = 3202645110425500000000; // 82
		claimers[0x882bBB07991c5c2f65988fd077CdDF405FE5b56f] = 3192340425531900000000; // 83
		claimers[0x0c2262b636d91Ec5582f4F95b40988a56496B8f1] = 3191489361702100000000; // 84
		claimers[0x57dA448673AfB7a06150Ab7a92c7572e7c75D2E5] = 3191489361702100000000; // 85
		claimers[0x68cf193fFE134aD92C1DB0267d2062D01FEFDD06] = 3191489361702100000000; // 86
		claimers[0x35205135F0883e6a59aF9cb64310c53003433122] = 3191489361702100000000; // 87
		claimers[0xA368bae3df1107cF22Daf0a79761EF94656D789A] = 3159574468085100000000; // 88
		claimers[0xA31B0BE89D0bcDF35B39682b652bEb8390A8F2Dc] = 2913791265957400000000; // 89
		claimers[0x9F74e07D01c8eE7D1b4B0e9739c8c75E8c23Ef4b] = 2872340425531900000000; // 90
		claimers[0xA7a9544D86066BF583be602195536918497b1fFf] = 2765957446808500000000; // 91
		claimers[0x64F8eF34aC5Dc26410f2A1A0e2b4641189040231] = 2600000000000000000000; // 92
		claimers[0xE088efbff6aA52f679F76F33924C61F2D79FF8E2] = 2553191489361700000000; // 93
		claimers[0xD0929C7f44AB8cda86502baaf9961527fC856DDC] = 2515989780989700000000; // 94
		claimers[0x6592aB22faD2d91c01cCB4429F11022E2595C401] = 2511826170212800000000; // 95
		claimers[0x07E8cd40Be6DD430a8B70E990D6aF7Cd2c5fD52c] = 2476687060085100000000; // 96
		claimers[0x875Bf94C16000710f721Cf453B948f23B7394ec2] = 2345194139228500000000; // 97
		claimers[0x1bdaA24527F033ABBe9Bc51b63C0F2a3e913485b] = 2340425531914900000000; // 98
		claimers[0x687922176D1BbcBcdC295E121BcCaA45A1f40fCd] = 2340425531914900000000; // 99
		claimers[0x2CE83785eD44961959bf5251e85af897Ba9ddAC7] = 2319702504255300000000; // 100
		claimers[0xCDCaDF2195c1376f59808028eA21630B361Ba9b8] = 2310638297872300000000; // 101
		claimers[0x7Ff698e124d1D14E6d836aF4dA0Ae448c8FfFa6F] = 2302934836170200000000; // 102
		claimers[0x11f53fdAb3054a5cA63778659263aF0838b642b1] = 2234042553191500000000; // 103
		claimers[0x826121D2a47c9D6e71Fd4FED082CECCc8A5381b1] = 2202127659574500000000; // 104
		claimers[0x674901AdeB413C126a069402E751ba80F2e2152e] = 2201778444129100000000; // 105
		claimers[0x228Bb6C83e8d0767eD342dd333DDbD55Ad217a3D] = 2191489361702100000000; // 106
		claimers[0xB248B3309e31Ca924449fd2dbe21862E9f1accf5] = 2172669850608700000000; // 107
		claimers[0xb14ae50038abBd0F5B38b93F4384e4aFE83b9350] = 2170212765957400000000; // 108
		claimers[0x795e43E9e2423620dA9107F2a5088e039F9A0112] = 2167234042553200000000; // 109
		claimers[0x86649d0a9cAf37b51E33b04d89d4BF63dd696fE6] = 2159574468085100000000; // 110
		claimers[0x8a382bb6BF2008492268DEdC549B6Cf189a067B5] = 2143092963829800000000; // 111
		claimers[0x687cEE1e9B4E2a33A63C5319fe6D5DbBaa8d5E91] = 2142553191489400000000; // 112
		claimers[0x390b07DC402DcFD54D5113C8f85d90329A0141ef] = 2129787234042600000000; // 113
		claimers[0x0aa05378529F2D1707a0B196B846d7963d677d37] = 2129787234042600000000; // 114
		claimers[0x8c1203dfC78068b0Fa5d7a2dD2a2fF9cFA89fFcE] = 2127659574468100000000; // 115
		claimers[0xee86f2BAFC7e33EFDD5cf3970e33C361Cb7aDeD9] = 2127659574468100000000; // 116
		claimers[0x0be82Fe1422d6D5cA74fd73A37a6C89636235B25] = 2127659574468100000000; // 117
		claimers[0xF33782f1384a931A3e66650c3741FCC279a838fC] = 2127659574468100000000; // 118
		claimers[0xD878a0a545dCC7751Caf6d796c0267C202A957Db] = 2127659574468100000000; // 119
		claimers[0x7A4Ad79C4EACe6db85a86a9Fa71EEBD9bbA17Af2] = 2127659574468100000000; // 120
		claimers[0x32527CA6ec2B85AbaCA0fb2dd3878e5b7Bb5b370] = 2127659574468100000000; // 121
		claimers[0x35E3c412286d59Af71ba5836cE6017E416ACf8BC] = 2127659574468100000000; // 122
		claimers[0xDc6c3d081691f7ef4ae25f488098aD0350052D43] = 2127659574468100000000; // 123
		claimers[0xfA79F7c2601a4C2A40C80eC10cE0667988B0FC36] = 2127659574468100000000; // 124
		claimers[0xD24596a11337129A939ba11034912B7D55262b46] = 2127659574468100000000; // 125
		claimers[0x5748c8EE8F7Fe23D14096E51Ca0fb3Cb63223643] = 2127659574468100000000; // 126
		claimers[0xe2D18861c892f4eFbaB6b2749e2eDe16aF458A94] = 2127659574468100000000; // 127
		claimers[0x7F052861bf21f5208e7C0e30C9056a79E8314bA9] = 2127659574468100000000; // 128
		claimers[0xA9786dA5d3ABb6C404b79DF28b7f402E58eF7c5B] = 2127659574468100000000; // 129
		claimers[0xaF997affb94c5Ca556b28b024E162AA3164f4A43] = 2127659574468100000000; // 130
		claimers[0x55fb5D5ae4A4F8369209fEf691587d40227166F6] = 2127659574468100000000; // 131
		claimers[0xf98de1A22d715A88C2A33821917e8ce2e5583D5A] = 2127659574468100000000; // 132
		claimers[0x6F15FA9582FdCF84f9F12D32F1C850775fD033eE] = 2127659574468100000000; // 133
		claimers[0x6F255406306D6D78e97a29F7f249f6d2d85d9801] = 2127659574468100000000; // 134
		claimers[0x2fb0d4F09e5F7E399354D8DbF602c871b84c081F] = 2127659574468100000000; // 135
		claimers[0x6B745dEfEE931Ee790DFe5333446eF454c45D8Cf] = 2127659574468100000000; // 136
		claimers[0x94d3B13745c23fB57a9634Db0b6e4f0d8b5a1053] = 2127659574468100000000; // 137
		claimers[0x498E96c727700a6B7aC2c4EfBd3E9a5DA4F0d137] = 2127659574468100000000; // 138
		claimers[0xB7c3A0928c06A80DC4A4CDc9dC0aec33E047A4c8] = 1063829787234000000000; // 139
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
		balance = claimers[addr] + Sended[addr];
	}
        function TokenBalance() public view returns(uint256)
        {
                IERC20 ierc20Token = IERC20(TokenAddr);
                return ierc20Token.balanceOf(address(this));
        }

}