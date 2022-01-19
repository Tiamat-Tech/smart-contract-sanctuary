// SPDX-License-Identifier: MIT
/* ======================================================== DEFI HUNTERS DAO ==========================================================================
                                                       https://defihuntersdao.club/
------------------------------------------------------------ January 2021 -----------------------------------------------------------------------------
#######       #######          ####         #####             ####      ###   #######     #######       #######        #####      #######   
##########    ##########      ######      #########          ######     ###   #########   ##########    #########    #########    ######### 
###########   ###########     ######     ###########         ######     ###   ##########  ###########   ##########  ###########   ##########
###    ####   ###    ####     ######    ####     ####        ######     ###   ###   ####  ###    ####   ###   #### ####     ####  ###   #### 
###     ####  ###     ####   ########   ####     ####       ########    ###   ###   ####  ###     ####  ###   #### ####     ####  ###   ####
###     ####  ###     ####   ###  ###   ###       ###       ###  ###    ###   #########   ###     ####  #########  ###       ###  ######### 
###     ####  ###     ####  ##########  ###       ###      ##########   ###   ########    ###     ####  ########   ###       ###  ########  
###     ####  ###     ####  ##########  ####     ####      ##########   ###   ###  ####   ###     ####  ###  ####  ####     ####  #####      
###    ####   ###    ####  ############ #####   #####     ############  ###   ###   ####  ###    ####   ###   #### #####   #####  ###        
##########    ##########   ####    ####  ###########      ####    ####  ###   ###   ####  ##########    ###   ####  ###########   ###        
#########     #########    ###     ####   #########       ###     ####  ###   ###   ####  #########     ###   ####   #########    ###        
==================================================================================================================================================== */
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DDAOclaim is AccessControl
{
	using SafeMath for uint256;
	using SafeERC20 for IERC20;
	IERC20 public token;

	address public owner = _msgSender();
	mapping (address => uint256) claimers;
	mapping (address => uint256) public Sended;

	// testnet
	address public TokenAddr = 0xcf17001DcFE45Ac926B886C76D8b937c852c8B23;
	// mainnet
	//address public TokenAddr = 0xca1931c970ca8c225a3401bb472b52c46bba8382;

	uint8 public ClaimCount;
	uint256 public ClaimedAmount;

	event textLog(address,uint256,uint256);

	constructor() 
	{
	_setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
                claimers[0xf18210B928bc3CD75966329429131a7fD6D1b667] = 50 * 10**18; // 1
                claimers[0x611b3f03fc28Eb165279eADeaB258388D125e8BC] = 50 * 10**18; // 2
                claimers[0x0130F60bFe7EA24027eBa9894Dd4dAb331885209] = 50 * 10**18; // 3
                claimers[0xFD9346bB6be8088a16632BE05c21536e697Cd514] = 50 * 10**18; // 4
                claimers[0x852dBe4212563946dfb82788fC0Ab1649b719EA7] = 50 * 10**18; // 5
                claimers[0xecCE210948363F54034b53FCEeA8BeE420b2Dad6] = 50 * 10**18; // 6
                claimers[0x46728c3ed31C5588D5a5989Ad7f3143eB37F90D1] = 50 * 10**18; // 7
                claimers[0x23D623D3C6F334f55EF0DDF14FF0e05f1c88A76F] = 50 * 10**18; // 8
                claimers[0x9b2D76f2E5E92b2C78C6e2ce07c6f86B95091964] = 50 * 10**18; // 9
                claimers[0xdCCd89bC40cD81A2a2c8631907174CA8aac6Bb6F] = 50 * 10**18; // 10
                claimers[0x7F052861bf21f5208e7C0e30C9056a79E8314bA9] = 50 * 10**18; // 11
                claimers[0xDcEEF35A4c1221C4F39f9eaA270e3C46f64701c8] = 50 * 10**18; // 12
                claimers[0x68D546Bc9ea85dA2027B318c8dC045b05547B60B] = 50 * 10**18; // 13
                claimers[0xb6B05931FA328D0622Ddfcca882f9366A0072372] = 50 * 10**18; // 14
                claimers[0xbb8b593aE36FaDFE56c20A054Bc095DFCcd000Ec] = 50 * 10**18; // 15
                claimers[0xd2C8CC3DcB9C79A4F85Bcad9EF4e0ccf4619d690] = 50 * 10**18; // 16
                claimers[0xBB5913bb6FA84f02ce78fFEEb9e7D43e3D075b16] = 50 * 10**18; // 17
                claimers[0x50648FB34E1A5B9b9D11F0E5B3b268f1Eacaa7bB] = 50 * 10**18; // 18
                claimers[0x5bb3e01c8dDCE82AF3f6e76f46d8965176A2daEe] = 50 * 10**18; // 19
                claimers[0xf8a5Ef9803787cAdE641D6F8767e660dC1951319] = 50 * 10**18; // 20
                claimers[0x3f6e6029E95cE74E0c286B7da173EBE7ebA72caf] = 50 * 10**18; // 21
                claimers[0x4Ae6155789d8D8CDA7bFaC23d9D5AdD2253d3171] = 50 * 10**18; // 22
                claimers[0x2aE024C5EE8dA720b9A51F50D53a291aca37dEb1] = 50 * 10**18; // 23
                claimers[0x73073A915f8a582B061091368486fECA640552BA] = 50 * 10**18; // 24
                claimers[0x8B9d3F19DF766D39Ac1C781509D18411EF8dB493] = 50 * 10**18; // 25
                claimers[0xd1cBd75d6217637655fc16c6321C967Db5AeDa4e] = 50 * 10**18; // 26
                claimers[0x44e02B37c29d3689d95Df1C87e6153CC7e2609AA] = 50 * 10**18; // 27
                claimers[0x266EEC4B2968fd655C362B1D1c5a9269caD4aA42] = 50 * 10**18; // 28
                claimers[0x61889b6da417A0467206756c7a980B3d0568DC3a] = 50 * 10**18; // 29
                claimers[0x43E70CB1B70d06439b8FBaD9f2de91508D73105d] = 50 * 10**18; // 30
                claimers[0x687922176D1BbcBcdC295E121BcCaA45A1f40fCd] = 50 * 10**18; // 31
                claimers[0xcCf70d7637AEbF9D0fa22e542Ac4082569f4ED5A] = 50 * 10**18; // 32
                claimers[0xDA9b467C311047f2Cc22e7e62120C2c513dB1794] = 50 * 10**18; // 33
                claimers[0x86649d0a9cAf37b51E33b04d89d4BF63dd696fE6] = 50 * 10**18; // 34
                claimers[0xAD5D752f2138a207E3BcD6685470759Fe2f463CD] = 50 * 10**18; // 35
                claimers[0x55d51687E9dE6a670301747A0e1194e46A385d44] = 50 * 10**18; // 36
                claimers[0x0E9F6CdcafA80aF5c97fe6c0e6C750860eb48AE7] = 50 * 10**18; // 37
                claimers[0xDf5B7bE800A5A7A67e887C2f677Cd29a7a05b6E1] = 50 * 10**18; // 38
                claimers[0xbC78fFa671925Fc5c86cA6362B19D47617af9168] = 50 * 10**18; // 39
                claimers[0xd85bCc93d3A3E89303AAaF43c58E624D24160455] = 50 * 10**18; // 40
                claimers[0xF2CA16da81687313AE2d8d3DD122ABEF11e1f68f] = 50 * 10**18; // 41
                claimers[0xD0A5ce6b581AFF1813f4376eF50A155e952218D8] = 50 * 10**18; // 42
                claimers[0xc3297c34F0d82E4C78B62455573A06AFa5F5F48D] = 50 * 10**18; // 43
                claimers[0x3034024f8CE00e21e33A618B301A9A2E7F65aF65] = 50 * 10**18; // 44
                claimers[0x826121D2a47c9D6e71Fd4FED082CECCc8A5381b1] = 50 * 10**18; // 45
                claimers[0x686241b898D7616FF78e22cc45fb07e92A74B7B5] = 50 * 10**18; // 46
                claimers[0xE770748e5781f171a0364fbd013188Bc0b33E72f] = 50 * 10**18; // 47
                claimers[0x6A2e363b31D5fd9556765C8f37C1ddd2Cd480fA3] = 50 * 10**18; // 48
                claimers[0xf10367decc6F0e6A12Aa14E7512AF94a4C791Fd7] = 50 * 10**18; // 49
                claimers[0xb5C2Bc605CfE15d31554C6aD0B6e0844132BE3cb] = 50 * 10**18; // 50
                claimers[0xB6a95916221Abef28339594161cd154Bc650c515] = 50 * 10**18; // 51
                claimers[0x1eC98f3101f5c8e51EE469905348A28d6f3886d1] = 50 * 10**18; // 52
                claimers[0x36bD9BA8C1AAdC49bc4e983C2ACCf0DA90C04019] = 50 * 10**18; // 53
                claimers[0xCE06EDfa8503147888728B2eE92f961B09B7bFfB] = 50 * 10**18; // 54
                claimers[0xe2D18861c892f4eFbaB6b2749e2eDe16aF458A94] = 50 * 10**18; // 55
                claimers[0x07F3813CB3A7302eF49903f112e9543D44170a50] = 50 * 10**18; // 56
                claimers[0x5973FFe2B9608e66A328c87c534e4Bb758618e73] = 50 * 10**18; // 57
                claimers[0xE088efbff6aA52f679F76F33924C61F2D79FF8E2] = 50 * 10**18; // 58
                claimers[0x024713784f675dd28b5CE07dB91a4d47213c2394] = 50 * 10**18; // 59
                claimers[0x94d3B13745c23fB57a9634Db0b6e4f0d8b5a1053] = 50 * 10**18; // 60
                claimers[0xB248B3309e31Ca924449fd2dbe21862E9f1accf5] = 50 * 10**18; // 61
                claimers[0xC5E57C099Ed08c882ea1ddF42AFf653e31Ac40df] = 50 * 10**18; // 62
                claimers[0x6B745dEfEE931Ee790DFe5333446eF454c45D8Cf] = 50 * 10**18; // 63
                claimers[0x125EaE40D9898610C926bb5fcEE9529D9ac885aF] = 50 * 10**18; // 64
                claimers[0xb827857235d4eACc540A79e9813c80E351F0dC06] = 50 * 10**18; // 65
                claimers[0xB67c99dfb3422b61f9E38070f021eaB7B42e9CAF] = 50 * 10**18; // 66
                claimers[0xb20Ce1911054DE1D77E1a66ec402fcB3d06c06c2] = 50 * 10**18; // 67
                claimers[0x572f60c0b887203324149D9C308574BcF2dfaD82] = 50 * 10**18; // 68
                claimers[0x7988E3ae0d19Eff3c8bC567CA0438F6Df3cB2813] = 50 * 10**18; // 69
                claimers[0xe20193B98487c9922C8059F2270682C0BAC9C561] = 50 * 10**18; // 70
                claimers[0xee86f2BAFC7e33EFDD5cf3970e33C361Cb7aDeD9] = 50 * 10**18; // 71
                claimers[0x7Ca612a4D526eB1C5583598fEdA57E938424f0CE] = 50 * 10**18; // 72
                claimers[0x712b4FA81f72532575599bC325bAE39F73AFC0D3] = 50 * 10**18; // 73
                claimers[0xd63613F91a6EFF9f479e052dF2c610108FE48048] = 50 * 10**18; // 74
                claimers[0xB61921297de2b18De6375Ba6fcA640a8dc6e2BDB] = 50 * 10**18; // 75
                claimers[0x37cec7bBFeCbB924Bb54e138312eB82Fee07b05d] = 50 * 10**18; // 76
                claimers[0x77167885E8393f1052A8cE8D5dfF2fF16c08f98d] = 50 * 10**18; // 77
                claimers[0x9E0e571F9EA6756A6910b25D747e46D12D4796e8] = 50 * 10**18; // 78
                claimers[0x0aa05378529F2D1707a0B196B846d7963d677d37] = 50 * 10**18; // 79
                claimers[0xb14ae50038abBd0F5B38b93F4384e4aFE83b9350] = 50 * 10**18; // 80
                claimers[0xbb6D29A522DDb640fc05862D8b129D991555cc4e] = 50 * 10**18; // 81
                claimers[0xB4264E181207E2e701f72331E0998c38e04c8512] = 50 * 10**18; // 82
                claimers[0xD1421ae08b24f5b24fa97980341DAbCADEeD3873] = 50 * 10**18; // 83
                claimers[0xfB89fBaFE753873386D6E46dB066c47d8Ef857Fa] = 50 * 10**18; // 84
                claimers[0x6e55632E9F6e245381e118bEAB75bF73C1D9be2e] = 50 * 10**18; // 85
                claimers[0x0eB4088C1c684Adf431747d4287bdBeAC67fAAbE] = 50 * 10**18; // 86
                claimers[0x1fCAb39c506517d0cc2a12D49eBe5B98f415ed92] = 50 * 10**18; // 87
                claimers[0xEA01E7DFc9B7e1341B02f0421fC61212290BE30E] = 50 * 10**18; // 88
                claimers[0x9E1fDAB0FE4141fe269060f098bc7076d248cE7B] = 50 * 10**18; // 89
                claimers[0x08Bd844e3c92d369eAF74Cc8E799493Fa9BC153c] = 50 * 10**18; // 90
                claimers[0x1326ad1DF89267f2C55Dc8a4cA01388d53763055] = 50 * 10**18; // 91
                claimers[0x8696da95087Cdc22cfea9fdbA3986F5c519571E4] = 50 * 10**18; // 92
                claimers[0x053AA35E51A8Ef8F43fd0d89dd24Ef40a8C91556] = 50 * 10**18; // 93
                claimers[0xF33782f1384a931A3e66650c3741FCC279a838fC] = 50 * 10**18; // 94
                claimers[0x93C927A836bF0CD6f92760ECB05E46A67D8A3FB3] = 50 * 10**18; // 95
                claimers[0xA0f31bF73eD86ab881d6E8f5Ae2E4Ec9E81f04Fc] = 50 * 10**18; // 96
                claimers[0xD54F610d744b64393386a354cf1ADD944cBD42c9] = 50 * 10**18; // 97
                claimers[0x5e0819Db5c0b3952149150310945752ae22745B0] = 50 * 10**18; // 98
                claimers[0x007D02E85c3486A6FDaed4dfCE9742BfDCD818D9] = 50 * 10**18; // 99
                claimers[0x14df5677aa90eC0D64c631621DaD80b44f9DeAFF] = 50 * 10**18; // 100
                claimers[0x15c5F3a14d4492b1a26f4c6557251a6F247a2Dd5] = 50 * 10**18; // 101
                claimers[0xaF792Fe5cC70CD7aDF8f6acBa7776d60bd07688f] = 50 * 10**18; // 102
                claimers[0xfA79F7c2601a4C2A40C80eC10cE0667988B0FC36] = 50 * 10**18; // 103
                claimers[0x61603cD19B067B417284cf9fC94B3ebF5703824a] = 50 * 10**18; // 104
                claimers[0x04b5b1906745FE9E501C10B3191118FA76CD76Ba] = 50 * 10**18; // 105
                claimers[0x58d2c45cEb3f33425D76cbe2f0F61529f1Df9BbF] = 50 * 10**18; // 106
                claimers[0xf295b48AB129A88a9b289C42f251A0EA75561D80] = 50 * 10**18; // 107
                claimers[0xb42FeE033AD3809cf9D1d6C1f922478F1C4A652c] = 50 * 10**18; // 108
                claimers[0xAA504202187c620EeB0B1434695b32a2eE24E043] = 50 * 10**18; // 109
                claimers[0x46f75A3e9702d89E3E269361D9c1e4D2A9779044] = 50 * 10**18; // 110
                claimers[0xE40Cc4De1a57e83AAc249Bb4EF833B766f26e2F2] = 50 * 10**18; // 111
                claimers[0x4D38C1D5f66EA0307be14017deC6A572017aCfE4] = 50 * 10**18; // 112
                claimers[0x4d35B59A3C1F59D5fF94dD7B2b3A1198378c4678] = 50 * 10**18; // 113
                claimers[0x7A4Ad79C4EACe6db85a86a9Fa71EEBD9bbA17Af2] = 50 * 10**18; // 114
                claimers[0x8F1B34eAF577413db89889beecdb61f4cc590aC2] = 50 * 10**18; // 115
                claimers[0x2F48e68D0e507AF5a278130d375AA39f4966E452] = 50 * 10**18; // 116
                claimers[0xC9D15F4E6f1b37CbF0E8068Ff84B5282edEF9707] = 50 * 10**18; // 117
                claimers[0x255F717704da11603063174e5Bc43D7881D28202] = 50 * 10**18; // 118
                claimers[0xC60Eec28b22F3b7A70fCAB10A5a45Bf051a83d2B] = 50 * 10**18; // 119
                claimers[0xae64d3d28b714982bFA990c2130afC92EA9e8bCC] = 50 * 10**18; // 120
                claimers[0xd79c0707083A92234F0ef5FD4Bfba3cd2b7bc81D] = 50 * 10**18; // 121
                claimers[0x2c064Aa8aBe232babf7a32932f7AB7c4E22b3885] = 50 * 10**18; // 122
                claimers[0xbD0Ad704f38AfebbCb4BA891389938D4177A8A92] = 50 * 10**18; // 123
                claimers[0xcB60257f43Db2AE8f743c863d561528EedeaA409] = 50 * 10**18; // 124
                claimers[0x5557A2dFafC875Af4dE5355b3bDd2c115ccc6911] = 50 * 10**18; // 125
                claimers[0x7E18B16467d3b7663fBA4f1F070f968c46d1BDCC] = 50 * 10**18; // 126
                claimers[0x65aeA388b214e9bE7d121B757EA0B2645a74026b] = 50 * 10**18; // 127
                claimers[0x4Dfd842a2C49Bd490a55585cAb0C441e948bD79a] = 50 * 10**18; // 128
                claimers[0x96C7fcC0d3426714Bf62c4B508A0fBADb7A9B692] = 50 * 10**18; // 129
                claimers[0x81cee999e0cf2DA5b420a5c02649C894F69C86bD] = 50 * 10**18; // 130
                claimers[0x87beC71BCE1F7E036eb1E5D969fD5C1887EF43A5] = 50 * 10**18; // 131
                claimers[0xeDf32B8F98D464b9Eb29C74202e6Baae28134fC7] = 50 * 10**18; // 132
                claimers[0xCDE3a031E5a8aC75954557D0DE3A7171A0408104] = 50 * 10**18; // 133
                claimers[0xf1180102846D1b587cD326358Bc1D54fC7441ec3] = 50 * 10**18; // 134
                claimers[0x7Ff698e124d1D14E6d836aF4dA0Ae448c8FfFa6F] = 50 * 10**18; // 135
                claimers[0x80057Cb5B18DEcACF366Ef43b5032440f5C97490] = 50 * 10**18; // 136
                claimers[0x6ACa5d4890CCc8A2d153bF16A9a5b0C5560A62ff] = 50 * 10**18; // 137
                claimers[0x328824B1468f47163787d0Fa40c44a04aaaF4fD9] = 50 * 10**18; // 138
                claimers[0x2F275B5bAb3C35F1070eDF2328CB02080Cd62D7D] = 50 * 10**18; // 139
                claimers[0x2E5F97Ce8b95Ffb5B007DA1dD8fE0399679a6F23] = 50 * 10**18; // 140
                claimers[0x0667b277d3CC7F8e0dc0c2106bD546214dB7B4B7] = 50 * 10**18; // 141
                claimers[0xB2CAE2cE07582FaDEf7B9c2751145Cc16B1206d2] = 50 * 10**18; // 142
                claimers[0x4F80d10339CdA1EDc936e15E7066C1DBbd8Eb01F] = 50 * 10**18; // 143
                claimers[0x3ef7Bf350074EFDE3FD107ce38e652a10a5750f5] = 50 * 10**18; // 144
                claimers[0x871cAEF9d39e05f76A3F6A3Bb7690168f0188925] = 50 * 10**18; // 145
                claimers[0x52539F834eD6801eDB460c31a19CFb33E2572B52] = 50 * 10**18; // 146
                claimers[0x637FB6aeC7933D91Deb2a0094D73D25100Dd5A1B] = 50 * 10**18; // 147
                claimers[0x86d94A6DC215991127c36f9420F30C44b5d8CbaD] = 50 * 10**18; // 148
                claimers[0x3A79caC51e770a84E8Cb5155AAafAA9CaC83F429] = 50 * 10**18; // 149
                claimers[0xD34CAdd64DBb8c4D0cA9cAfCe279E9895e890196] = 50 * 10**18; // 150
                claimers[0x7E004aeF8b4976f52f172e78c8240CFb3fc9d0ca] = 50 * 10**18; // 151
                claimers[0xF93b47482eCB4BB738A640eCbE0280549d83F562] = 50 * 10**18; // 152
                claimers[0xF7f341C7Cf5557536eBADDbe1A55dFf0a4981F51] = 50 * 10**18; // 153
                claimers[0x88D09b28739B6C301be94b76Aab0554bde287D50] = 50 * 10**18; // 154
                claimers[0xC4b1bb0c1c8c29E234F1884b7787c7e14E1bC0a1] = 50 * 10**18; // 155
                claimers[0x2c46bc2F0b73b75248567CA25db6CA83d56dEA65] = 50 * 10**18; // 156
                claimers[0x4460dD70a847481f63e015b689a9E226E8bD5b71] = 50 * 10**18; // 157
                claimers[0x99dcfb0E41BEF20Dc9661905D4ABBD92267095Ee] = 50 * 10**18; // 158
                claimers[0x2E72d671fa07be54ae9671f793895520268eF00E] = 50 * 10**18; // 159
                claimers[0x49e03A6C22602682B3Fbecc5B181F7649b1DB6Ad] = 50 * 10**18; // 160
                claimers[0x6Acb64A76e62D433a9bDCB4eeA8343Be8b3BeF48] = 50 * 10**18; // 161
                claimers[0x6D5888bCA7431F80A1659889658c4a2B1477Edd3] = 50 * 10**18; // 162
                claimers[0x64aF1b02c5C82738f5958c3BC8140BD9662674C6] = 50 * 10**18; // 163
                claimers[0x67C5A03d5769aDEe5fc232f2169aC5bf0bb7f18F] = 50 * 10**18; // 164
                claimers[0x68cf193fFE134aD92C1DB0267d2062D01FEFDD06] = 50 * 10**18; // 165
                claimers[0xD05Da93aEa709abCc31979A63eC50F93c29999C4] = 50 * 10**18; // 166
                claimers[0x2A77484F4cca78a5B3f71c22A50e3A1b8583072D] = 50 * 10**18; // 167
                claimers[0x04bfcB7b6bc81361F14c1E2C7592d712e3b9f456] = 50 * 10**18; // 168
                claimers[0xf93d494D5A3791e0Ceccf45DAECd4A5264667E98] = 50 * 10**18; // 169
                claimers[0x9edC40c89Ba7455148a2b85C3527ed2A4D241aA8] = 50 * 10**18; // 170
                claimers[0xDfB78f8181A5e82e8931b0FAEBe22cC4F94CD788] = 50 * 10**18; // 171
                claimers[0x58bb897f0612235FA7Ae324F9b9718a06A2f6df3] = 50 * 10**18; // 172
                claimers[0xe1C69F432f2Ba9eEb33ab4bDd23BD417cb89886a] = 100 * 10**18; // 173
                claimers[0x49A3f1200730D84551d13FcBC121A6405eDe4D56] = 100 * 10**18; // 174
                claimers[0x79440849d5BA6Df5fb1F45Ff36BE3979F4271fa4] = 100 * 10**18; // 175
                claimers[0xC8ab8461129fEaE84c4aB3929948235106514AdF] = 100 * 10**18; // 176
                claimers[0x28864AF76e73B38e2C9D4e856Ea97F66947961aB] = 100 * 10**18; // 177
                claimers[0xE513dE08500025E9a15E0cb54B232169e5c169BC] = 100 * 10**18; // 178
                claimers[0x1eAc5483377F43b34888CFa050222EF68eeAA52D] = 100 * 10**18; // 179
                claimers[0x7eE33a8939C6e08cfE207519e220456CB770b982] = 100 * 10**18; // 180
                claimers[0x764108BAcf10e30F6f249d17E7612fB9008923F0] = 100 * 10**18; // 181
                claimers[0x2220d8b0539CB4613A5112856a9B192b380be37f] = 100 * 10**18; // 182
                claimers[0xAeC39A38C839A9A3647f599Ba060D3B68C13D95E] = 100 * 10**18; // 183
                claimers[0x24f39151D6d8A9574D1DAC49a44F1263999D0dda] = 100 * 10**18; // 184
                claimers[0x00737ac98C3272Ee47014273431fE189047524e1] = 100 * 10**18; // 185
                claimers[0x237b3c12D93885b65227094092013b2a792e92dd] = 100 * 10**18; // 186
                claimers[0xfE61D830b99E40b3E905CD7EcF4a08DD06fa7F03] = 100 * 10**18; // 187
                claimers[0x7DcE9e613b3583C600255A230497DD77429b0e21] = 100 * 10**18; // 188
                claimers[0xeD08e8D72D35428b28390B7334ebe7F9f7a64822] = 100 * 10**18; // 189
                claimers[0xB83FC0c399e46b69e330f19baEB87B6832Ec890d] = 100 * 10**18; // 190
                claimers[0x3a026dCc53A4bc80b4EdcC155550d444c4e0eBF8] = 100 * 10**18; // 191
                claimers[0x184cfB6915daDb4536D397fEcfA4fD8A18823719] = 100 * 10**18; // 192
                claimers[0x0f5A11bEc9B124e73F51186042f4516F924353e0] = 100 * 10**18; // 193
                claimers[0xa6700EA3f19830e2e8b35363c2978cb9D5630303] = 100 * 10**18; // 194
                claimers[0x3A484fc4E7873Bd79D0B9B05ED6067A549eC9f49] = 100 * 10**18; // 195
                claimers[0x9e0eD477f110cb75453181Cd4261D40Fa7396056] = 100 * 10**18; // 196
                claimers[0xF962e687562999a127a5b5A2ECBE99d0601564Eb] = 100 * 10**18; // 197
                claimers[0x8ad686fB89b2944B083C900ec5dDCd2bB02af1D0] = 200 * 10**18; // 198
                claimers[0x712Ca047e7A31c7049DF72084906A48fEaD2D57A] = 200 * 10**18; // 199
                claimers[0x5f3E1bf780cA86a7fFA3428ce571d4a6D531575D] = 200 * 10**18; // 200
                claimers[0x35E3c412286d59Af71ba5836cE6017E416ACf8BC] = 200 * 10**18; // 201
                claimers[0x44956BBEA170eAf91B49b2DbD13f502c86E6753b] = 200 * 10**18; // 202
                claimers[0xc8e1020c45532FEEA0d65d7C202bc79609e21579] = 200 * 10**18; // 203
                claimers[0x38400B6bBd2B19d7B4a4C3559bcbB0fe1Ef45ec3] = 200 * 10**18; // 204
                claimers[0x5dfCDA39199c47a962e39975C92D91E76d16a335] = 200 * 10**18; // 205
                claimers[0xeBc4006EfD8fCCD9Aa144ee145AB453099266B92] = 200 * 10**18; // 206
                claimers[0x55E9762e2aa135584969DCd6A7d550A0FaadBcd6] = 200 * 10**18; // 207
                claimers[0x0118838575Be097D0e41E666924cd5E267ceF444] = 200 * 10**18; // 208
                claimers[0xEc8c50223E785C3Ff21fd9F9ABafAcfB1e2215FC] = 200 * 10**18; // 209
                claimers[0x0be82Fe1422d6D5cA74fd73A37a6C89636235B25] = 200 * 10**18; // 210
                claimers[0x77724E749eFB937CE0a78e16E1f1ec5979Cba55a] = 200 * 10**18; // 211
                claimers[0xE04DE279a00C1E17a54f7a743355125DDc31D185] = 200 * 10**18; // 212
                claimers[0x99CD484206f19A0341f06228BF501aBfee457b95] = 200 * 10**18; // 213
                claimers[0x76b2e65407e9f24cE944B62DB0c82e4b61850233] = 200 * 10**18; // 214
                claimers[0xc7B5D7057BB3A77d8FFD89D3065Ad14E1E9deD7c] = 200 * 10**18; // 215
		// testers
		claimers[0xF11Ffb4848e8a2E05eAb2cAfb02108277b56d0B7] = 1000000000000000000;
		claimers[0x97299ea1C42b3fA53b805e0E92b1e05500519762] = 1000000000000000000;
		claimers[0x9134408d47239DD81402723B8f0444cf66B82e5D] = 1000000000000000000;
		claimers[0x675162726340338856a8Ff4923930e3A4b1e3Daf] = 1000000000000000000;
		claimers[0xe44b45E38E5Fe6d39c0370E55eB2453E25F7c3C5] = 1000000000000000000;
		claimers[0xa5B32272f2FE16d402Fe6Da4EDfF84cD6f8e4AA0] = 1000000000000000000;
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