// SPDX-License-Identifier: MIT
/* ======================================================== DEFI HUNTERS DAO ====================================================================
                                                     https://defihuntersdao.club/
------------------------------------------------------------ January 2021 -----------------------------------------------------------------------
###     ###  ###    ###  ####    ### ########## ########  #######      #####          ####         #####      #####  ########    #####     ##### 
###    #### ####   ####  #####   ### ########## ########  #########  ########        #####       ########   ######## ########  ########  ########
###    #### ####   ####  #####   ### #########  ########  ###  ####  #######         ######    #########  #########  ########  #######   #######  
###    #### ####   ####  ######  ###    ###     ###       ###   ### ####             ######    ####       ####       ###      ####      ####     
########### ####   ####  ####### ###    ###     ########  #########  ######         ### ####  ####       ####        ########  ######    ###### 
########### ####   ####  ### #######    ###     ########  ########    #######       ###  ###  ####       ####        ########   #######   #######
###    #### ####   ####  ###  ######    ###     ###       ###  ####      ####      ########## ####       ####        ###           ####      ####
###    ####  ###   ####  ###   #####    ###     ###       ###  ####       ###      ##########  ####       ####       ###            ###       ### 
###    ####  #########   ###   #####    ###     ########  ###   ###  ########     ####    ###   ########   ########  ########  ########  ########
###    ####   #######    ###    ####    ###     ########  ###   ############      ####    ####   ########   ######## ######## ########  ########

                                         #########            ####                         
                                            ###      #######  #### ####  #######  ######## 
                                            ###     ######### ######### ######### #########
                                            ###    ####   ### #######   ###   ### ####  ###
                                            ###    ###    ### #######   ######### ####  ###
                                            ###    ####   ### ########  ###       ####  ###
                                            ###     ######### #### #### ######### ####  ###
                                            ###      #######  ####  #### ######## ####  ###
---------------------------------------------------------------------------------------------------------------------------------------------- */
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";

//import "@openzeppelin/contracts/token/ERC721/ERC721Full.sol";
//@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol
import "@openzeppelin/contracts/access/Ownable.sol";

contract HAT is ERC721, Ownable, Pausable
{
	address public PayToken;

	struct params 
	{
		uint8 num;
		bytes name;
		uint16 interval;
		uint256 cost;
	}
	mapping(uint8 => params) public Params;

	constructor() ERC721("Hunters Access Token", "HAT")
	{
		// USDC Polygon
		PayToken = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
	}

	function pause(bool val)public onlyOwner
	{
		require(val != paused(),'Contract already has you new status');

		if(val)_pause();
		else
		_unpause();
	}
	function PayTokenChange(address addr)public onlyOwner
	{
		PayToken = addr;
	}

	function ParamAdd(uint8 Number, bytes memory Name, uint16 TimeInterval, uint256 Cost)public onlyOwner
	{
		Params[Number] = params(Number,Name,TimeInterval,Cost);
	}
	function ParamView(uint8 Number)public view returns(params memory)
	{
		return Params[Number];
	}
}