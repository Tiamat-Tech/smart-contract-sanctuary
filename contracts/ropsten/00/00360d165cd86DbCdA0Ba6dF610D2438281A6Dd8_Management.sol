pragma solidity ^0.8.0;

uint256 constant DECIMALS = 18;
uint256 constant SECONDS_IN_WEEKS = 1 weeks;
uint256 constant UNITS = 1_000_000_000_000_000_000;
uint256 constant MAX_UINT256 = 2**256 - 1;
uint256 constant PERCENTAGE_100  = 10000;
uint256 constant PERCENTAGE_1  = 100;

bytes4 constant InterfaceId_ERC721 = 0x80ac58cd;

string  constant ERROR_ACCESS_DENIED = "ERROR_ACCESS_DENIED";
string  constant ERROR_NO_CONTRACT = "ERROR_NO_CONTRACT";
string  constant ERROR_NOT_AVAILABLE = "ERROR_NOT_AVAILABLE";

//permisionss
//WHITELIST
uint256 constant ROLE_ADMIN = 1;
uint256 constant ROLE_REGULAR = 5;

uint256 constant CAN_SET_KYC_WHITELISTED = 10;
uint256 constant CAN_SET_PRIVATE_WHITELISTED = 11;



uint256 constant WHITELISTED_KYC = 20;
uint256 constant WHITELISTED_PRIVATE = 21;


uint256 constant CAN_TRANSFER_NFT = 30;

//CONTRACT_CODE
uint256 constant CONTRACT_MANAGEMENT = 0;
uint256 constant CONTRACT_KAISHI_TOKEN = 1;
uint256 constant CONTRACT_STAKE_FACTORY = 2;
uint256 constant CONTRACT_NFT_FACTORY = 3;
uint256 constant CONTRACT_TRESUARY = 4;
uint256 constant CONTRACT_LIQUIDITY_MINING_FACTORY = 5;