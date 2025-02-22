// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title: London Richards
/// @author: manifold.xyz

import "@manifoldxyz/creator-core-solidity/contracts/ERC721Creator.sol";

//////////////////////////////////////////////////////
//                                                  //
//                                                  //
//              _____            _____              //
//             /\    \          /\    \             //
//            /33\____\        /33\    \            //
//           /333/    /       /3333\    \           //
//          /333/    /       /333333\    \          //
//         /333/    /       /333/\333\    \         //
//        /333/    /       /333/__\333\    \        //
//       /333/    /       /3333\   \333\    \       //
//      /333/    /       /333333\   \333\    \      //
//     /333/    /       /333/\333\   \333\____\     //
//    /333/____/       /333/  \333\   \333|    |    //
//    \333\    \       \33/   |3333\  /333|____|    //
//     \333\    \       \/____|33333\/333/    /     //
//      \333\    \            |333333333/    /      //
//       \333\    \           |33|\3333/    /       //
//        \333\    \          |33| \33/____/        //
//         \333\    \         |33|   |              //
//          \333\    \        |33|   |              //
//           \333\____\       \33|   |              //
//            \33/    /        \3|   |              //
//             \/____/          \|___|              //
//                                                  //
//                                                  //
//                                                  //
//////////////////////////////////////////////////////


contract LR is ERC721Creator {
    constructor() ERC721Creator("London Richards", "LR") {}
}