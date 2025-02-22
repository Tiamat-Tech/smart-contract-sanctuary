// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/// @title: CLASSIFIED
/// @author: manifold.xyz

import "@manifoldxyz/creator-core-solidity/contracts/ERC721Creator.sol";

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//                                                                                                                                //
//                                                                                                                                //
//    ╠╠╬╣╬╠╬╠╠▒▒▒╠╠╟╬╬╬▒░▒░░╠╠╠╬╬╬╬░░░"░░░░░░░░░∩-░░░░░░░░∩░;░[¡░░║╠▒░░░░...∩,[,∩. .╔                                            //
//        ╬╠╠╠╬╫╠╠╠╠╠▒▒░╚▒╠▒▒▒▒▒▒▒╬╬╬╬╩' '.' ¡░░░░░▒▒░;"░░░¡░░░:'~░░░░░░╬░░░░-   "Γ░╚;'░'╠.                                       //
//        φ▒║╣▓▓▓╣╩╠╫▒▒░░░╠╠░░╚╣╬╠╠╬╠╩╩▒▒░░.░░░╚▒φ░▒╟▒░φ;  '~"'''░ ' ':░╚░░''¡   å╩░░░░ .Γ                                        //
//        ▐╠╠╬▓▓▓▒░╣╬▒╠▒▒░╠╠▒░░╚╩╩▒░░φ╬▒▒▒=²\"░,▒╠█╬█▀#ƒ,▄░╓╓φ,╓φ▒~'''.\░░░¡¡"   ' !"└░.:░                                        //
//        ╠▒▒╟╬╬╩░╙╩╬╣╬╬▒▒╠▒╬▒▒░Γ░░▒╠╠▒▒▒▒░»φ╓,φ#╬╝╬▄░-`╚░╚  ╠╬╬▓▓▓▓╗ ,φφ░░░░¡¡∩ .. ░░░╔,                                         //
//        ╠╠╠╠╬▒╥░░░░╠╬╬▓▓▓█▓░╩░░░▒╩│φ░░░░░░░!░φ░.░░¡è⌐╔φ▒  ]╠╠╠╫╬╬╬╣╬╫▓▓███▌╦ε'  ''!░░░Γ                                         //
//        ╠╠╠╠╠╣▒░ ╙╝╣╬╬▓▓▓█▌▄▄╣▒▒░ :░Γ░░░░░∩~░╚▒φ░≥╠╩╓▒╙ ░,╠▒╠▒╬╬╬╠╟▓╬▓╟███╬╬╬ ,.   .-                                           //
//        ╠╠╠╠╬╠▒"░[φΓ░▓████▓██▓╩    ^░░░░░≥!░╚╬╣╩╠╬▒╟╬▒',"¡╙╬╬╬╚╬╬╬╣╬╣╬▓▓▓╙╙╚Σ▒φ'.                                               //
//        ╬▒╚░▒▒╠  "▀▒▒▓▓╬╫██▓▓╬      ░░░░░░∩"╓╙ @╬╬╣▓╬⌐    ╙╙╚""╚╚╩╚░╙░╬╙█▓▒╠╬█▓∩╗                                               //
//        ▒░▒░░▒╟╣▄▄▓▄████▓█╬╬╬╩     '.#▒▒░░ ╚╙² ╙ ╙╜╙' ,░░░░.      ╛'`j⌐,╙╬▓╣╬╣▀░p      .                                        //
//        ░░░░╠╬╬╣╬▓███████╬▒░└       ²░░ε,       .∩;.░;░░░░  ; '  .. .å╣▓▓╬╩╙╓░≤      ]░∩                                        //
//        ░░░░╠╬╬╬╣▓▓█████▓▒░░  `╓▄▄╗φ╗╥╖      ..""^ "φ╩░∩φ;░φ ''` , φ▓▓█╣▓"╠╚▒░       "∩                                         //
//        φ░░░≥╠╬╣║╣▓╣████╬╬▒░φ╠▒╠▓▓▓▓▓██▓╬▀▓▓▄╓    ─""/]░½▄▒--;░φ≈ ⌠▓▓▓▓▓▓ ░░▒⌐'      ;≈                                         //
//        ░░░░░╫╟▌╬▓▓▓▓▓█▓▓╬╠▄╣╬╣╬██▓╝███╬╫▓▒╬▒╩╩δ∩    ,#╬╫╫▓▓▒╠╣▓▓██████▓Γ ░░▒▒'      ^,                                         //
//        ..░Γ╚╬╠╣╬╣╬╚▓█▓▓▓▒'╙╚▓█╩░╙¡░╠▓╬▒▐╣╬╝▒░~     ▄▓█████▓▓╬▓╬██████▌`   '^     «    "                                        //
//        φφ▓▓▓╠╬╣╣╬▒ ╙╬▓▓▓░~  "└░░"░░║▒╠║╟█▀▓╬▒..   ╙▓███╩╟████▓██╬▒╣╬╬b     '~ ..░░  , ,                                        //
//        ╬╠█▓▓╬╬╠╠╠▒[.╙╣╬╠░`    '  `φ║█▓╩δ╠φ╙│╠╠▒⌐   ╙╩╙╟▒░╝█▓▒╟╬▀╨║╬╬╠▒       '!░░Γ."Γ''                                        //
//        ╙╟▓▓▓▓▀╙╬▒▄;∩'░╠▒░         !╚╙▒Γ╙░;ε ,;░  ░░░░░░╚░╠╠╬╙╠`.φ▓╣╬╠Γ       .'      ∩"                                        //
//        ╠╠╬╬╬╠▄▄ ▄▒▒░''░░'   '';\   │\└└ "░░░░░░∩¡░░░░░░░Γ░╙ ¡░,░╠▓╬▒"░     ;░≥⌐ , - ⌠.                                         //
//        ▒╠▒╠╠╠╢▀╚╬, ▒!.      ''\-    '''` !.''░  ]░░░╚╬╩░░.;;░░░▒╫╩' ¡,     ' '^   .░░░φ                                        //
//        ╠▒▒╠▒▒╬▒;╬▒≥▒░░∩ ....              .  ░ .╠░" .▒ ░░!░░░░╠▒▄▄  .░           '¡░░▒▒                                        //
//        ░Γ░φ╠╠╠▓▄╟▄╙░\░░∩' ⁿ'''' '       .   .░⌐ ╘░''    ''░░▒╙╫▓╠╬φ               !░░░░                                        //
//        ░░@╬▓▓▓▓███▓;∩'░░░. ~         '.φ╓▄▒╗φ░> ,░        ▒φ╩╬▓█▓▓╣¼▄▄ .           ░░▒Γ                                        //
//        ░░░╣╣▓▓█████▌`''░ '.┐ .~    . .-φ╔░╚▓▒▒╠▓╬╬⌐     .]⌐▒║╙╬▓███▌█▓ '          ;╔░▒░                                        //
//        ▒▒░▒░╠▓▓█▓█▓█▄¡.    ░ ¡░,.░░░φ▒╙│╩╚φ╬╣███▓▒░ ,..;╦╬▓╣▓╬╔▄╠▓╣╬▒╓,.          .¡░░░                                        //
//        ▒░░░╓╢╣╣██▓╙╠▓░  └ ; '░░░░░░,,░░,░φ`╙░╠╬╩░░▒░¡░░φ╬╣█▓╬▓▓╬;░╠╚▒░`░≥░----,,,;░░≤░░                                        //
//        ░░░░╠▓▓▓╬╬░▒▓╣ :'\;░.░φ░░╙╬▀╣╫╫╫╣╣▓▓▓╬▒▄▄φφ▒▒░░φ▒╙╣╣╣╣▓╬░`" φ▒Γ` ²"""╙╙░░░""ⁿΓ!░                                        //
//        ░░░'╙╣╬╬╬╠░▓╬▒" "φφ▒░φ▒▒ΓΣ╠▒▒░Γ≥▒⌠╠╠╬▒╚╬╟╬╩╠╟╠▒╬∩│ ╟╣╬▓╦ 'φ=  .  `ⁿ=≤φ░╚╩░Γ  '░'                                        //
//        ░╠▒▒╠▒╠╬╠╠░╣╬╬▓  ╠╫╬▒╠╢╬╬▒╬╬╬╬▒▒╠╠╬╣▓╬╣╫╣╩▒╣╣╬╩,▌▌ ╠╠▓╣▒≥  "░        '        ;░                                        //
//        "Γ░░░░░░░▒░║╠╫╬▒@░ ╙╝╬╣╬╬╠╬╬╬╬▒╠╠░░╙╙╙░╚╠╣▓▓█▄▓╙) ╠▒╣╬╟░   '.  .░`';.░░φφ░░=≈░░░                                        //
//        ,≥φ░░░░░░░░╣╣▓╣▒▒Γ¼   ╙╬╬╬╣╬╠╟╙╙╚▒▒▒φ▒╟▓▓██▓╬░≥▒Γ░║╬╠#╛    ¡   '!'''''  "''.░░░░                                        //
//        ░░φ╠▒▒░░░░░╫╣▓╬╬╬, ╠╖╠▒Γ╚╣╩╚╬╩░~...╚╠▓█▀╠╣▓╙░φφ▒▒ⁿ╚╠░╙░     ^⌐  ~       . .░░░░░                                        //
//        ░░░╚║▒▒░░░░░░▓╬╣▒░." ╚╔ ²╣▀╫Åφ╦,Γ"░╔╛╙▓╩╬╩░┘'╠╩╩Γ''╙ '      [¡░φ░░░ⁿ░░░'¡ ':"░░░                                        //
//        ░░░░░╙░░░░░▄▓▓▓╫▒░".░ⁿ²╙%▓╣╠╓--   ▐,4╣▒ ²^.. ≥░░     `      ..~"░░░░╚╚Γ░░!░¡░░░░                                        //
//        ░░░░░░░░φ▒╠╣╬▒█████µ ≈▒Å╩╩╙╙╙ "░░▌╣╣╬Γ╠  1░ '░░         `'└░;^░░░░░░░░░░- "'│░░░                                        //
//        ░░░░░░░^░░░µ╙╬▓▀╩╣▓▓╬╠╠▒φ;φ░░░░φφ▌║╩╔╓Γ .│' '░;∩\ .           φ╠░░░░░░░░⌐''.░░░░                                        //
//        ░░░░░░  "▄░░░,└└≈╣▓╩╠╙.╠░;▒╠▒░▒░░║╬╝╚╙   φ▄▒░\░░           .  ,,.░░;"░[   ''░░░φ                                        //
//        ░░░░░⌐ "░░╬╣▒ ▒╩φ╩░░░░░▒╠▒╬╬╩░╚░░░╠░░░░Å╩╙╬╣▒▒▒▒.        ''"Γ░╣██▒░░'░░; ' '!░░╙                                        //
//        ╠░░\='  ]╣╬▌╠╦▒Å░░░' ░░╚╚╚╠▒╠▒░░░░░░░░≥╠░▒"╠╩╣╙╙[      "">»░╙▒╫██▌╠░░░φ░."''.░░░                                        //
//        ▒▒░φφ░ .¡╠▓╬▒░░φ]░"  ░░░░░▒▒╠▒▒░φ▒╠░░.^▒░░░¼░⌐           ''░░ ╙╣▒j╚░░▒╚., .'  ('                                        //
//        ▒░╠╚▒⌐''' ░▒░░░╠╣▓▓╬╬░░▒▒▒░▒▒╙░░╩╠░░∩   :∩╙ΓΓ  .  '\.   `Q'░.'░╠╠╣▒░╠░░'░    ' ,                                        //
//        ╙└""      {";'░╬╬▓█▓▒╬▒╠╩╙╩▒╠φ░░░░░    '" '░░  ''        ╙░:.;░░╟▌▒Γ▒╩ ''  ¡»░░░                                        //
//        ≥░.      '│''.░▄╬╣█▓▓▒░╙Γ░φ░░└"│`" ' '  '░░]⌐ ''      ⌡'    .~░░░░░░░░».    ^ ¿▒                                        //
//        ▒░░φ. -░.░░≤φ▒╟█▀░▒░░░░░¡░░░░.."' *''    '∩;╓,,          ; .¡;░░░░░░░;,,     ░φ▒                                        //
//        ╠╠╠▒░¡¡░φ░╚╚╚░▒▒▒▒░░░░░░░░░░░░░¡~..\'   '  └╝╠▒. ' ;;≡#╦╠φ¡░░░░∩░░!' '└;░.  .¡░║                                        //
//        ╬╬╩░░'"░░░░░░░▒▒▒▒░░░░░░░░░░¡░░░.'': ';,         '≥≥░░,,│.'░░░░"    .;░░░░░ ~  ▐                                        //
//        │╠▒░⌐░=░░░░░░░░░░░░░░░░░¡.░.'░░░░░,,░░φ▒  '    ..░░░░░¡░.' '''     .;¡'░"░Γ'   ▐                                        //
//        ╬▒▒φ╩│,░░░░░░░░░░░░░░░░░'┌ ''.░░░░░░░░░░░░▒ ░  ..;░░░\\.~┌..       '¡'' .!» '- "                                        //
//                                                                                                                                //
//                .`└ ▀██▀     ╫█   ╓█▀▀█  █▀▀█▌ ▀▀██▀   ▄`    ▀▀█▀▀  ╙▀└╙▓▌   █Σ                                                 //
//              █j  ╙  ▐█     ]█╟▌  ╙██▄▄  ▀█▄▄▌   █▌    █▄██▀   █─   ▐█▓█▌▀  j█▄  █`                                             //
//              █J▄,▓  ╟█  █  ██▀█  █▄, █▌▓▌▄ ╟█╒  █▌   ²██▀╙    █═   ▐█▄▀▐█  ▐██ ▓█                                              //
//               ▀▀▀▌└█▀█▀▀▀ ▀▀▀²▀▀ ▀▀██▀`╙▀▀█▀▀ ████▀⌐╙██▀▀¬  ████▀¬▀█████▀ ²▀██▀▀^                                              //
//                                                                                                                                //
//                                                              ░░░░░░░░░░░░░░░░░░░░░░░░░░                                        //
//                                              ░░░░    ░░░░░░░░▒▒▒▒▒▒▒▒░░▒▒▒▒▒▒░░░░░░░░░░░░░░░░                                  //
//                                          ░░░░░░░░▒▒▓▓▒▒▓▓▓▓▓▓▓▓▒▒▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░                              //
//                                      ░░░░░░▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░                              //
//                              ░░░░░░░░░░▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░                            //
//                          ░░░░░░░░░░▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░                          //
//                        ░░░░░░▒▒░░▒▒▓▓▓▓██▓▓▓▓▓▓▒▒░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░                          //
//                      ░░░░░░░░▒▒▒▒▓▓▓▓██▓▓▒▒▒▒░░░░▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░                          //
//                      ░░░░▒▒▒▒▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▓▓▒▒▓▓▓▓▓▓▓▓▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░                        //
//                      ░░░░▒▒▓▓▓▓▓▓▒▒▒▒░░▒▒▒▒▒▒▒▒▒▒▓▓▓▓██▓▓▓▓▓▓▒▒▓▓▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░░░░░                          //
//                        ░░▒▒▒▒▒▒▒▒░░▒▒▒▒▒▒▒▒▒▒▓▓▓▓▓▓▒▒▒▒░░▒▒▒▒░░▒▒▓▓▒▒▓▓▓▓▓▓▓▓▒▒▒▒▒▒▒▒░░▒▒░░░░░░░░░░░░                          //
//                        ░░▒▒░░░░░░░░▒▒▒▒▒▒▓▓██▓▓▒▒▒▒▒▒▒▒▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▒▒▒▒▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒▒▒░░░░░░░░░░                        //
//                        ░░░░░░░░░░░░░░▒▒▓▓██▒▒▒▒░░▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓██▓▓▓▓▒▒▒▒▒▒▒▒░░░░░░░░░░                        //
//                        ░░░░░░░░░░░░▒▒▓▓▓▓▒▒▒▒▒▒▓▓▒▒▓▓██▓▓▒▒░░▒▒▒▒▓▓▓▓▒▒▒▒▓▓▓▓▓▓▓▓██▓▓▓▓▒▒▒▒░░░░░░░░░░░░                        //
//                        ░░░░░░░░░░░░▒▒▓▓▒▒░░▒▒▒▒░░░░██▓▓░░░░░░██░░▒▒▒▒▒▒░░░░▒▒▓▓▓▓▓▓▓▓▓▓▒▒░░░░░░░░░░░░                          //
//                        ░░░░░░░░░░░░▒▒▒▒▒▒▓▓▓▓░░░░  ▓▓▒▒▓▓▓▓████░░▒▒░░▒▒    ░░▒▒▒▒▓▓▒▒▒▒░░░░░░░░░░░░░░                          //
//                        ░░░░░░░░░░░░░░░░▒▒▒▒░░░░    ▒▒▒▒▒▒▒▒▓▓▓▓░░▒▒▒▒░░    ░░▒▒▒▒▒▒▒▒░░░░░░░░░░░░                              //
//                        ░░░░░░░░░░░░░░░░▒▒░░░░░░    ░░▒▒░░░░░░░░░░▒▒▓▓    ░░░░▒▒▒▒▒▒░░░░░░░░░░░░░░                              //
//                          ░░░░░░░░░░░░▒▒░░▒▒░░░░░░  ░░▒▒▒▒░░▒▒░░▒▒▓▓░░  ░░░░▒▒▒▒▒▒░░░░░░░░░░  ░░                                //
//                          ░░░░░░░░░░░░▒▒░░▒▒░░░░░░░░░░  ▒▒▒▒▒▒▒▒▒▒░░░░░░░░▒▒░░░░░░░░░░░░░░░░                                    //
//                            ░░░░░░░░░░░░░░░░▒▒▒▒░░░░░░░░░░░░░░░░░░░░░░▒▒▒▒░░░░░░░░░░░░░░░░                                      //
//                              ░░░░░░░░░░░░▒▒▒▒▒▒▒▒▒▒▓▓▒▒▒▒░░░░▒▒▒▒▒▒▒▒░░░░░░░░░░░░░░░░                                          //
//                              ░░░░░░░░░░░░▒▒░░░░▒▒░░░░▒▒░░░░░░░░░░░░░░  ░░░░░░░░░░░░                                            //
//                                ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ░░                                                    //
//                                  ░░░░░░      ░░░░░░░░░░░░░░░░░░░░                                                              //
//                                    ░░░░          ░░░░░░░░░░░░                                                                  //
//                                                            ░░                                                                  //
//                                                                                                                                //
//                                                                                                                                //
//                            .▄▄   .▄▄    ▄──▄    ╓▄    .╓▄   ╓▄,  .▄                                                            //
//                             ██    █▌  █▌    ██  ▐█     ██    ▀█µ Æ                                                             //
//                             ██""" █▌ j█▌    ▐█⌐ ╟█     ██     ╙█▌                                                              //
//                             ██,   █▌, ╙▀▄, ▄▀└  ╟█µ,,- ██,,,- ▐█▌                                                              //
//                                                                                                                                //
//                                                                                                                                //
//                ▓█    ██  `█▌`"  `█▌²▓▄   ▐██,   ▐   ██ 7▀▄    ▄▀`'▀▓▄  ▐██    ▀                                                //
//                ╫█,,,,██   █▌.,   █▌ ██   j ╙██  ▐   █▌   ╟█⌐ ██    ▐█▌ ▐ ╙██  ▐                                                //
//                ╫█    ██   █▌     █▌ ██µ  j─  ╙██▐   █▌   ▐█  ██    ▐█▀ ▐   ╙██▐                                                //
//                ▀▀¬   ▀▀¬  ▀▀¬¬` "▀▀  └▀▀ ¬"    ╙▀   ▀▀¬¬"╙    └╙¬¬"╙   ╙"    ▀▀                                                //
//                                                                                                                                //
//                                                                                                                                //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


contract CLSFD is ERC721Creator {
    constructor() ERC721Creator("CLASSIFIED", "CLSFD") {}
}