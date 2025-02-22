// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title: Kingdoms of Ethiopia
/// @author: manifold.xyz

import "@manifoldxyz/creator-core-solidity/contracts/ERC721Creator.sol";

/////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                         //
//                                                                                                         //
//    ╔╗╗╗╗   ╗╗╗╗╗     ╓╗╗╗     ╣╣╗╗╗╗╗╗╗╗╗╗   ╗╗╗╗╗╗╗╗╥      ╗╗╗╗╗╗╗╗╗╗   ╔╗╗╗╗╗╗╗╥          ╗╗╗         //
//      ╣╣╣   ╓╣╣─     ╒╣╣╣╣─      ─ ╙╣╣╝─ ╙╙    ╟╣╣└└╙╣╣╣      ╣╣╣ ─└╙╙╙    ╞╣╣╨└╙╙╣╣╣       ╟╣╣╣╣        //
//       ╣╣╗ ┌╣╣       ╣╣ ╟╣╣        ╘╣╣─        ╟╣╣   ╟╣╣─     ╣╣╣          ╞╣╣     ╣╣╬     ╒╣╬ ╣╣╦       //
//        ╫╣╗╣╬       ╫╣╣ ╓╣╣╬       ╘╣╣─        ╟╣╣╣╣╣╬╨       ╣╣╣╝╝╝╝╨     ╞╣╣     ╣╣╬     ╣╣╥ ╟╣╣╗      //
//         ╟╣╣       ╔╣╬╨╨╨╨╣╣╗      ╞╣╣─        ╟╣╣  ╙╣╣╗      ╣╣╣          ╞╣╣     ╣╣╝    ╫╣╝╨╨╨╫╣╣      //
//         ╟╣╣      ┌╣╣╕    ╟╣╣╗     ╞╣╣╗        ╟╣╣   ╙╣╣╗     ╣╣╣╓╓╓╓╥╦    ╞╣╣╦╓╓╗╣╣╨    ╔╣╣     ╣╣╣     //
//        ╙╙╙╙╙─    ╙╙╙╙    ╙╙╙╙─   ╙╙╙╙╙╙      ╙╙╙╙╙   ╙╙╨╨   ╙╙╙╙╙╙╙╙╙╙   ╙╙╙╙╙╙╙╙└     ╙╙╙╙╙   ╙╙╙╙╙    //
//                                                                                                         //
//                    ╓╓╥╥╥                                 ╓╓╥╓                                           //
//                   ╗╣╣╨╙╙╣╣╣      ╓╣╣╨╨╫╣╣╬╙╙╙╫╣╣╗         ╙╣╣╣            ╗╣╣╙╙╙╣╣╣                     //
//                  ╞╣╣╗   ╫╣╣     ╔╣╬    ╣╣╗    ╟╣╣         ╟╣╣─           ╘╣╣╗   ╫╣╣                     //
//                   ╫╣╣╗ ╗╣╝      ╣╣═    ╣╣╣╗╗  ╞╣╣        ╔╣╣╨             ╙╣╣╣╗╗╣╝                      //
//                    ╙╣╣╣╣       ╒╣╣       ╣╣╣  ╞╣╣╗      ╓╣╣╨                 ╙╫╣╣═                      //
//                      ╙╣╣╣       └        ╣╬╣   └       ╒╣╣╨              ╣╣╣╣╣╣╣╣╣╣╣╣╬                  //
//                        ╣╣╗               ╣╬╬           ╣╣╣     ╓╓╓╥╥     ╨╨╙      ╒╣╣─                  //
//                   ╓╥╦╗╣╣╩                ╣╣╣          ╘╣╣╣╦╗╗╣╣╣╨╙╟╣╣             ╣╣╣                   //
//                  ╔╣╣╝╙└                  ╙└└           └╙╙└  ╟╣╣╗╗╣╝─             ╙╙                    //
//                                                                                                         //
//                                                                                                         //
/////////////////////////////////////////////////////////////////////////////////////////////////////////////


contract TAITU is ERC721Creator {
    constructor() ERC721Creator("Kingdoms of Ethiopia", "TAITU") {}
}