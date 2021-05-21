// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title: Slimesunday
/// @author: manifold.xyz

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                                            //
//    [email protected]@@@@@=  [email protected]@@@    [email protected]@@@[email protected]@@@@= [email protected]@@@[email protected]@@@@@@@- [email protected]@@@@@@-  @@@@@ [email protected]@@@[email protected]@@@  @@@@[email protected]@@@@@@=-   [email protected]@@@@@[email protected]@@@= [email protected]@@=   //
//    [email protected]@@@@@@@@= @@@@@    @@@@@[email protected]@@@@= @@@@@[email protected]@@@@@@@ [email protected]@@@@@@@@[email protected]@@@@ @@@@@[email protected]@@@@- @@@@[email protected]@@@@@@@@@-  @@@@@@@ @@@@= @@@@-  //
//    @@@@@[email protected]@@@@[email protected]@@@@   [email protected]@@@[email protected]@@@@[email protected]@@@@[email protected]@@@@@@@[email protected]@@@@[email protected]@@@[email protected]@@@[email protected]@@@@[email protected]@@@@[email protected]@@[email protected]@@@@@@@@@=  @@@@@@@ @@@@[email protected]@@=   //
//    @@@@@ @@@@[email protected]@@@=   [email protected]@@@[email protected]@@@@[email protected]@@@@@[email protected]@@@@-   [email protected]@@@[email protected]@@@[email protected]@@@[email protected]@@@[email protected]@@@@[email protected]@@[email protected]@@@[email protected]@@@= [email protected]@@@@@@ [email protected]@@@@@@@    //
//    @@@@@@-    [email protected]@@@-   @@@@@[email protected]@@@@@[email protected]@@@@@[email protected]@@@@    [email protected]@@@@=     @@@@@ [email protected]@@@[email protected]@@@@[email protected]@@@[email protected]@@@@ @@@@@- @@@@@@@@ [email protected]@@@@@@-    //
//    [email protected]@@@@@-   @@@@@    @@@@@[email protected]@@@@@@@@@@@[email protected]@@@@@@=  @@@@@@@   [email protected]@@@@ @@@@@[email protected]@@@@@@@@@@[email protected]@@@@ @@@@@ [email protected]@@@@@@@ [email protected]@@@@@=     //
//     [email protected]@@@@@=  @@@@@   [email protected]@@@[email protected]@@@@@@@@@@@[email protected]@@@@@@-   @@@@@@@- [email protected]@@@= @@@@@[email protected]@@@@@@@@@[email protected]@@@[email protected]@@@@ @@@@[email protected]@@@  @@@@@@      //
//      [email protected]@@@@@[email protected]@@@=   [email protected]@@@[email protected]@@@@@@@@@@@[email protected]@@@@@@@     [email protected]@@@@@ [email protected]@@@[email protected]@@@[email protected]@@@@@@@@@[email protected]@@@[email protected]@@@[email protected]@@[email protected]@@@  @@@@@=      //
//  [email protected]@@@@[email protected]@@@-   @@@@@[email protected]@@@[email protected]@@[email protected]@@@[email protected]@@@=    [email protected]@@@@[email protected]@@@@ [email protected]@@@[email protected]@@[email protected]@@@@[email protected]@@@@ @@@@@[email protected]@@@[email protected]@@@@  @@@@@       //
//  @@@@@ @@@@@[email protected]@@@@--- @@@@@[email protected]@@@[email protected]@@[email protected]@@@[email protected]@@@[email protected]@@@= @@@@@[email protected]@@@@[email protected]@@@@[email protected]@@@ [email protected]@@@@[email protected]@@@@ @@@@@[email protected]@@@@@@@@@  @@@@@       //
//  @@@@@@@@@@@[email protected]@@@@@@@[email protected]@@@[email protected]@@[email protected]@[email protected]@@[email protected]@@@@@@@[email protected]@@@@@@@@@@[email protected]@@@@@@@@@@[email protected]@@@ [email protected]@@@@[email protected]@@@@@@@@@[email protected]@@@@@@@@@ [email protected]@@@=       //
//  [email protected]@@@@@@@@[email protected]@@@@@@@[email protected]@@@[email protected]@@[email protected]@ @@@@[email protected]@@@@@@@@ @@@@@@@@@@  @@@@@@@@@@ [email protected]@@= [email protected]@@@[email protected]@@@@@@@@@[email protected]@@@[email protected]@@@@ [email protected]@@@-       //
//   [email protected]@@@@@=- [email protected]@@@@@@[email protected]@@@[email protected]@@ [email protected] @@@@[email protected]@@@@@@@=  [email protected]@@@@@=    [email protected]@@@@@=  [email protected]@@-  @@@@[email protected]@@@@@@@= [email protected]@@=  @@@@= [email protected]@@@        //
//                                                                                                                            //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

import "./ERC721Creator.sol";

contract SS is ERC721Creator {
    constructor() ERC721Creator("Slimesunday", "SLIME") {}
}