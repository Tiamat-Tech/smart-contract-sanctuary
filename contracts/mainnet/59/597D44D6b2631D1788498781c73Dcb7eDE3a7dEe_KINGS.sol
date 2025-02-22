// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title: Sacramento Kings
/// @author: manifold.xyz

import "./ERC721Creator.sol";

/////////////////////////////////////////////////////////////////////////////
//                                                                         //
//                                                                         //
//                           ╦                                             //
//                         ╔╬╬                                             //
//                        ╔╬╣  ╔╗                   ╔╗  ╦╦╦    ╔╬╬╗        //
//                ╔╦╬   ╔╬╬╬╬  ╬╬         ╔╬╬╗   ╔╬╬╬╬╬╬╬╣   ╔╬╬╬╬╬        //
//            ╔╦╬╬╬╬╝  ╔╬╬╬╬╝       ╔╦╬╦╬╬╬╬╬╣  ╔╬╬╩  ╬╬╬╝ ╦╬╬╩ ╠╬╬╣       //
//           ╠╬╬╬╬╬╬  ╬╬╬╬╩   ╔╦╬   ╬╬╬╬╝ ╠╬╬  ╔╬╬╣  ╬╬╬╣╔╬╬╩   ╠╬╬╣       //
//           ╚╩╩╬╬╬╬╦╬╬╬╩     ╠╬╬  ╠╬╬╝   ╬╬╣ ╔╬╬╬╬╦╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬╬    //
//              ╬╬╬╬╬╬╝      ╠╬╬╝  ╬╬╣   ╠╬╬╬╬╩╩╬╬╬╩╬╬╬╬╩   ╚╩╩╩╩╩  ╬╬╬╬   //
//              ╬╬╬╬╬╣       ╠╬╬   ╬╬╣   ╚╬╩╩      ╬╬╬╬╗      ╔╦╦╦╬╬╬╝╙    //
//             ╬╬╬╣╬╬╬╬╦    ╔╦╬╬╦╦╦╬╬╝      ╔╦╦╬╬╬╬╬╬╩╩╩╩╩╩╩╩╩╩╩╩╩╩╩       //
//             ╠╬╬╝ ╬╬╬╬╬╦╦╬╬╩╬╬╬╩╩╩   ╔╦╬╬╩╩╬╬╬╬╝╠╬╬⌐                     //
//             ╬╬╬   ╙╬╬╬╬╬╬╝     ╔╦╦╬╬╬╩╝ ╔╬╬╬╩╝╔╬╬╝                      //
//            ╬╬╬╣           ╔╦╦╬╬╬╬╩╝    ╔╬╬╬╝ ╔╬╬╩                       //
//      ╬    ╬╬╬╬╝        ╔╦╬╬╬╬╬╬╩      ╔╬╬╬╬╦╦╬╬╩                        //
//      ╬╦╦╦╬╬╬╬╝     ╔╦╬╬╬╬╬╬╬╩╩        ╬╬╬╬╬╬╬╬╝                         //
//      ╚╬╬╬╬╬╬╩    ╔╬╬╬╬╬╬╬╬╩            ╚╩╩╩╝                            //
//       ╚╩╩╩╩╝   ╔╦╬╬╬╬╬╬╬╝                                               //
//             ╔╬╬╬╬╬╬╬╬╬╬╩                                                //
//           ╔╬╬╬╬╬╬╬╬╩╩╩╝                                                 //
//         ╔╬╬╬╬╬╩╩╝                                                       //
//       ╔╬╬╬╩╩                                                            //
//      ╬╬╩╝                                                               //
//    ╩╩╝                                                                  //
//                                                                         //
//                                                                         //
/////////////////////////////////////////////////////////////////////////////


contract KINGS is ERC721Creator {
    constructor() ERC721Creator("Sacramento Kings", "KINGS") {}
}