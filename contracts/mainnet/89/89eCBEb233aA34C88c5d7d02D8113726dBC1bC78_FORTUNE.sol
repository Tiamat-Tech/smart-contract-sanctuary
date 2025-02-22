// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title: Fortune Media
/// @author: manifold.xyz

import "./ERC721Creator.sol";

////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                        //
//                                                                                        //
//    &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&    //
//    &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&    //
//    &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&    //
//    &&&&&&@                                                                  ,&&&&&&    //
//    &&&&&&@                                                                  ,&&&&&&    //
//    &&&&&&@                 ,,,,,,,,,,,,,#@@@@@@@@@@@@@@@@@@@                ,&&&&&&    //
//    &&&&&&@                 ,,,,,,,,,,,,,###(%&&&&&&&&&&&&&&@                ,&&&&&&    //
//    &&&&&&@                 ,,,,,,,,,,,,,########%&&&&&&&&&&@                ,&&&&&&    //
//    &&&&&&@                 ,,,,,,,,,,,,,###########(&&&&&&&@                ,&&&&&&    //
//    &&&&&&@                 ,,,,,,,,,,,,,################&&&@                ,&&&&&&    //
//    &&&&&&@                 ////////////////////////////////#                ,&&&&&&    //
//    &&&&&&@                .&&&&&&&&&&&&@                                    ,&&&&&&    //
//    &&&&&&@                .&&&&&&&&&&&&@                                    ,&&&&&&    //
//    &&&&&&@                .&&&&&&&&&&&&&/////////////                       ,&&&&&&    //
//    &&&&&&@                .&&&&&&&&&&&&&&&%##########                       ,&&&&&&    //
//    &&&&&&@                .&&&&&&&&&&&&&&&&&&########                       ,&&&&&&    //
//    &&&&&&@                .&&&&&&&&&&&&&&&&&&&&&#####                       ,&&&&&&    //
//    &&&&&&@                .&&&&&&&&&&&&&&&&&&&&&&&###                       ,&&&&&&    //
//    &&&&&&@                .&&&&&&&&&&&&&@&&&&&&&&&&&&                       ,&&&&&&    //
//    &&&&&&@                .&&&&&&&&&&&&#                                    ,&&&&&&    //
//    &&&&&&@                .&&&&&&&&&&###                                    ,&&&&&&    //
//    &&&&&&@                .&&&&&&&&&####                                    ,&&&&&&    //
//    &&&&&&@                .&&&&&&&######                                    ,&&&&&&    //
//    &&&&&&@                .&&&&&&#######                                    ,&&&&&&    //
//    &&&&&&@                .&&&&#########                                    ,&&&&&&    //
//    &&&&&&@                .&&&##########                                    ,&&&&&&    //
//    &&&&&&@                .&############                                    ,&&&&&&    //
//    &&&&&&@                .////////////(                                    ,&&&&&&    //
//    &&&&&&@                                                                  ,&&&&&&    //
//    &&&&&&@                                                                  ,&&&&&&    //
//    &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&    //
//    &&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&    //
//                                                                                        //
//                                                                                        //
////////////////////////////////////////////////////////////////////////////////////////////


contract FORTUNE is ERC721Creator {
    constructor() ERC721Creator("Fortune Media", "FORTUNE") {}
}