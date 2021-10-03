// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title: COOPER RAY
/// @author: manifold.xyz

import "@manifoldxyz/creator-core-solidity/contracts/ERC721Creator.sol";

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                                                                                          //
//                                                                                                                                                                          //
//                                                                                                                                                                          //
//                                                                                                                                                                          //
//                                                                                                               .                                                          //
//                                                                                                               |                                                          //
//                                                                                                               |                                                          //
//                                                                                                               '                                                          //
//                                                                                                               "                                                          //
//                                                                                                               }         '                                                //
//          `                                                                                                   <v>        '                                                //
//          `'                                                              .                                 .^c*r^.      ^`                                               //
//           '.                                                             {                .               .z*#N#*z.    /|?                                               //
//          `CR                                                            .|^               .               .*$NYC$*.    `cc'                                              //
//           ),\                                                          `WGMi      .       .               .#MMCM#*.   'u**r                                              //
//           `w..`.                                                       "&%8(      `      '_'               #MMNMM#.   '*##*                                              //
//            !GM%i                                                       l%%%z'    .`.     [#v.      '       #MWMWM#.   |#GMi.                                             //
//            <BBBM,                                          '''.        f%B%&"   z8}[!   '#W#.      .`      #MWNWM#.   tMWM#"                                             //
//             *BB%%\,                                       ^%Up!   ,   f%DAO%8,  #&&&n   ,#A#\     .t*^     MWWWWWM.   tW&WM,                                             //
//            "%@BBB%j                                 :NYC  "$GMI   :   t%[email protected]%:  W8%8Wf. lWGWx     '#M<     MWW&&&M.   t&&WM,                                             //
//            "BBBB%W-                                 :@@/  ,@@B;   !   #[email protected]%~  8%%%8&. !&M&n     'MW<     WW&&&&W.   #W&&M:                                             //
//            'BBBBBl                                  [email protected]@B. ,@@B:  /%}  #[email protected]@@BB  BBB%88, ;&I&t     'M&'.   +&&8888&l,  #&8&W;                                             //
//             MBBBB_                 '^^`'      ;gm.  [email protected]@[email protected]@@@@@, `%B/  #[email protected]@@[email protected]@  @BBB%8: :888\     'W8^&  &888888888&z |&88WI                                             //
//             [email protected][                 sETH~      ;@@t  *[email protected]@" [email protected]@/  #@@@@@@@  [email protected]%; :8%8|     `&8v8  %888888%%88# %&88W!    `~~                                      //
//             ]BBB%_                 *BBBi      [email protected]@\  [email protected]" [email protected]@8n [email protected][email protected][email protected]@@@@[email protected]%:.1%%%u`   @88%%%8 %%8%8%8%%%8W`j888&>    :M&                                      //
//           :_%@@@Bz,                &@@B;      [email protected]@(  &[email protected]: [email protected][email protected] [email protected][email protected]@@@@@@@@@BB:"%BBB%? ser8%BBBB %%%%%%%%%%%%8%8%&&~    :W&.    ''                               //
//          ^[email protected]@@@@BB%"            '1)[email protected]@Bi      *[email protected] [email protected]@/ !$$$$ [email protected][email protected][email protected]@@@@@BB;^%%@BB{&BBBBBBBBB %%%%B%%%%%%%%%%%%8+    ,&8.   n8&^.888888&_                     //
//        'u%@@[email protected]@B*(.         ,[email protected]@@@$B^..,ll%$${  @$$8888$$$n [email protected]$$$ [email protected][email protected]@@@@@@@@[email protected]@BBBBBBBBBBBBBBBB%%BBB%%%%%%%%%8-  .'>88^'''v%%^;%BBBBB%{                     //
//         "[email protected]@@[email protected]@%`         '[email protected]@@@@@@@@@$$$$$$[  $$$8888$$j l$$$$$ [email protected][email protected][email protected]@@@@@@@@@@@@[email protected]%B%8?%  ;88%%%%%%B%";%[email protected]@[email protected]@f....      ^gm'        //
//         <@@@BB%BB%%%"         <[email protected]@@@[email protected]@@@@@$$$$$$\`^$$$$$$$$$$*l\[email protected]@@[email protected]@@@[email protected]@@BBBBBBBB35MMBB%BBBBBBB%B%%%88]  j%B%BBBBBBB,:[email protected]@@@@@BBB%      "@@^        //
//         ([email protected]@@@@@@@B%,       [email protected]@@@@[email protected]@@@[email protected][email protected][email protected]@@@@@@@@@@@@@BBBBBBBBBBBBBB8BTOADZB%B%%8%B**B%[email protected]@@@@[email protected]@B     #^@$,       //
//    I/[email protected]@@[email protected][email protected]@@@@@#xr/{``^[email protected]@@@@[email protected]@@@[email protected]@[email protected]@@@@@[email protected]@@[email protected]@BBBBBBBBBBBBBB%BBBBB%%%B%/''*%[email protected]@@@@@@@@@[email protected]@-_+++_|$$j^.       //
//    [email protected]@[email protected][email protected]@@[email protected]@@[email protected]@@@@@@@[email protected]@@@@[email protected]@@[email protected]@@@@@@BBBBBBBB%%%%BBBBB%B%BBBB%%%%%%%8%8888%%%%BBBBBB%%[email protected]@@@@[email protected][email protected]      //
//    [email protected][email protected][email protected]@@@@@@@@@@[email protected]@@@BB1."[email protected][email protected]@B.^..`""":z];`%Wl`[B"..{v..'M$$$<I`[email protected]"..?|;;I;;:icBB\"'.."\u..;8]`(%B%B%*<:;;;:-..^;;,..';;?;",%BBz'.'*[email protected]@@@@@@$$$$$$$$$$$$$$      //
//    [email protected]@[email protected]@@@@@@[email protected]@@B?   "xBB% `  :_-__?$$;;$$M'"  ,#. [email protected]$~"@@!  "` ,[email protected]`~)       !  ``!8BBB%%/. z%%%%8  `8%u  "8%B%8`>%W'  [email protected]@@@@@$$$$NO$BRAKES$$$      //
//    M%@[email protected]@@@@@@@@@@@[email protected]@@@B+':   ^jW `  f$$$$$$$B`\$$;  'M'  |@$$$$$$B`<1  `?  ,@@@@@BM " ,zB8\'"   j%BBBBB8'  c%%B%8  `8%c  ^%%%%&#'(^  +%[email protected]@@@@@@@@[email protected]      //
//    *8%[email protected]@[email protected]%BBB%B%BBB%>^%z:   ` `  [email protected]@@@@@@@u.z/   z:  [email protected]@[email protected]@[email protected]@@W'..'Wj  :[email protected] !  ]BB%v*  .'rB%%%8&,  r88888  '&&c  ^888888n.  ^8%[email protected]@@@@@@@@@@@      //
//    .........................;+....:nzv}zz`''''.....^x*#|}gM#:...........IBB^..`(|,``">{: <z*',vn''zz>.~~'.....,fi^``",tc1...##~.......-zz..........................      //
//                             `^     .:;"!!!!i!"      ,ii..lI,            '^^.    .`"^`.   `;;. .,^.;;`  ':'      .`"^`.":^   ,,`       `,,.                               //
//                                                                                                                                                                          //
//                                                                                                                                                                          //
//                                                                                                                                                                          //
//        ,o888888o.        ,o888888o.         ,o888888o.     8 888888888o   8 8888888888   8 888888888o.             8 888888888o.            .8.   `8.`8888.      ,8'     //
//       8888     `88.   . 8888     `88.    . 8888     `88.   8 8888    `88. 8 8888         8 8888    `88.            8 8888    `88.          .888.   `8.`8888.    ,8'      //
//    ,8 8888       `8. ,8 8888       `8b  ,8 8888       `8b  8 8888     `88 8 8888         8 8888     `88            8 8888     `88         :88888.   `8.`8888.  ,8'       //
//    88 8888           88 8888        `8b 88 8888        `8b 8 8888     ,88 8 8888         8 8888     ,88            8 8888     ,88        . `88888.   `8.`8888.,8'        //
//    88 8888           88 8888         88 88 8888         88 8 8888.   ,88' 8 888888888888 8 8888.   ,88'            8 8888.   ,88'       .8. `88888.   `8.`88888'         //
//    88 8888           88 8888         88 88 8888         88 8 888888888P'  8 8888         8 888888888P'             8 888888888P'       .8`8. `88888.   `8. 8888          //
//    88 8888           88 8888        ,8P 88 8888        ,8P 8 8888         8 8888         8 8888`8b                 8 8888`8b          .8' `8. `88888.   `8 8888          //
//    `8 8888       .8' `8 8888       ,8P  `8 8888       ,8P  8 8888         8 8888         8 8888 `8b.               8 8888 `8b.       .8'   `8. `88888.   8 8888          //
//       8888     ,88'   ` 8888     ,88'    ` 8888     ,88'   8 8888         8 8888         8 8888   `8b.             8 8888   `8b.    .888888888. `88888.  8 8888          //
//        `8888888P'        `8888888P'         `8888888P'     8 8888         8 888888888888 8 8888     `88.           8 8888     `88. .8'       `8. `88888. 8 8888          //
//                                                                                                                                                                          //
//                                                                                                                                                                          //
//                                                                                                                                                                          //
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


contract CR is ERC721Creator {
    constructor() ERC721Creator("COOPER RAY", "CR") {}
}