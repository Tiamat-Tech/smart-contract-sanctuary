// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title: Nate Mohler
/// @author: manifold.xyz

import "@manifoldxyz/creator-core-solidity/contracts/ERC721Creator.sol";

//////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                          //
//                                                                                                          //
//    <-. (`-')_ (`-')  _ (`-')      (`-')  _<-. (`-')              (`-').->          (`-')  _   (`-')      //
//       \( OO) )(OO ).-/ ( OO).->   ( OO).-/   \(OO )_      .->    (OO )__    <-.    ( OO).-/<-.(OO )      //
//    ,--./ ,--/ / ,---.  /    '._  (,------.,--./  ,-.)(`-')----. ,--. ,'-' ,--. )  (,------.,------,)     //
//    |   \ |  | | \ /`.\ |'--...__) |  .---'|   `.'   |( OO).-.  '|  | |  | |  (`-') |  .---'|   /`. '     //
//    |  . '|  |)'-'|_.' |`--.  .--'(|  '--. |  |'.'|  |( _) | |  ||  `-'  | |  |OO )(|  '--. |  |_.' |     //
//    |  |\    |(|  .-.  |   |  |    |  .--' |  |   |  | \|  |)|  ||  .-.  |(|  '__ | |  .--' |  .   .'     //
//    |  | \   | |  | |  |   |  |    |  `---.|  |   |  |  '  '-'  '|  | |  | |     |' |  `---.|  |\  \      //
//    `--'  `--' `--' `--'   `--'    `------'`--'   `--'   `-----' `--' `--' `-----'  `------'`--' '--'     //
//                                                                                                          //
//                                                                                                          //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////


contract DNMIV is ERC721Creator {
    constructor() ERC721Creator("Nate Mohler", "DNMIV") {}
}