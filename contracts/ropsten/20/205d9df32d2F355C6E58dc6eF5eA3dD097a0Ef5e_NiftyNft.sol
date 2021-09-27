//Contract based on https://docs.openzeppelin.com/contracts/3.x/erc721
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @generator: TheNifty.com v0.0.1

import "./NiftyGenerator.sol";

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                                                                                            //
//                                                                                                                                                                            //
//    TTTTTTTTTTTTTTTTTTTTTTThhhhhhh                                      NNNNNNNN        NNNNNNNN  iiii     ffffffffffffffff           tttt                                  //
//    T:::::::::::::::::::::Th:::::h                                      N:::::::N       N::::::N i::::i   f::::::::::::::::f       ttt:::t                                  // 
//    T:::::::::::::::::::::Th:::::h                                      N::::::::N      N::::::N  iiii   f::::::::::::::::::f      t:::::t                                  // 
//    T:::::TT:::::::TT:::::Th:::::h                                      N:::::::::N     N::::::N         f::::::fffffff:::::f      t:::::t                                  //
//    TTTTTT  T:::::T  TTTTTT h::::h hhhhh           eeeeeeeeeeee         N::::::::::N    N::::::Niiiiiii  f:::::f       ffffffttttttt:::::tttttttyyyyyyy           yyyyyyy   //
//            T:::::T         h::::hh:::::hhh      ee::::::::::::ee       N:::::::::::N   N::::::Ni:::::i  f:::::f             t:::::::::::::::::t y:::::y         y:::::y    //
//            T:::::T         h::::::::::::::hh   e::::::eeeee:::::ee     N:::::::N::::N  N::::::N i::::i f:::::::ffffff       t:::::::::::::::::t  y:::::y       y:::::y     //
//            T:::::T         h:::::::hhh::::::h e::::::e     e:::::e     N::::::N N::::N N::::::N i::::i f::::::::::::f       tttttt:::::::tttttt   y:::::y     y:::::y      //
//            T:::::T         h::::::h   h::::::he:::::::eeeee::::::e     N::::::N  N::::N:::::::N i::::i f::::::::::::f             t:::::t          y:::::y   y:::::y       // 
//            T:::::T         h:::::h     h:::::he:::::::::::::::::e      N::::::N   N:::::::::::N i::::i f:::::::ffffff             t:::::t           y:::::y y:::::y        //
//            T:::::T         h:::::h     h:::::he::::::eeeeeeeeeee       N::::::N    N::::::::::N i::::i  f:::::f                   t:::::t            y:::::y:::::y         //
//            T:::::T         h:::::h     h:::::he:::::::e                N::::::N     N:::::::::N i::::i  f:::::f                   t:::::t    tttttt   y:::::::::y          //
//          TT:::::::TT       h:::::h     h:::::he::::::::e               N::::::N      N::::::::Ni::::::if:::::::f                  t::::::tttt:::::t    y:::::::y           //
//          T:::::::::T       h:::::h     h:::::h e::::::::eeeeeeee       N::::::N       N:::::::Ni::::::if:::::::f                  tt::::::::::::::t     y:::::y            //
//          T:::::::::T       h:::::h     h:::::h  ee:::::::::::::e       N::::::N        N::::::Ni::::::if:::::::f                    tt:::::::::::tt    y:::::y             //
//          TTTTTTTTTTT       hhhhhhh     hhhhhhh    eeeeeeeeeeeeee       NNNNNNNN         NNNNNNNiiiiiiiifffffffff                      ttttttttttt     y:::::y              //
//                                                                                                                                                      y:::::y               //
//                                                                                                                                                     y:::::y                //
//                                                                                                                                                    y:::::y                 //
//                                                                                                                                                   y:::::y                  //
//                                                                                                                                                  yyyyyyy                   //
//                                                                                                                                                                            //
//                                                                                                                                                                            //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

contract NiftyNft is NiftyGenerator {
  address[] public wallets = [0x602606740103614Fab9eC4baA0224f886afC36d0];
  uint256[] splits = [100];
  constructor() NiftyGenerator("NiftyNft", "NIFTY", 100, 0.005 ether) PaymentSplitter(wallets, splits) {}
}