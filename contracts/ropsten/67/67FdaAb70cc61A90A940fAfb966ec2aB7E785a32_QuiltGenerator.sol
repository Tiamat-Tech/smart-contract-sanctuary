//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";

library QuiltGenerator {
    struct QuiltStruct {
        uint256 quiltX;
        uint256 quiltY;
        uint256 quiltW;
        uint256 quiltH;
        uint256 xOff;
        uint256 yOff;
        uint256 themeIndex;
        uint256 backgroundIndex;
        uint256 patchXCount;
        uint256 patchYCount;
        bool hovers;
    }

    function getQuiltForSeed(string memory seed)
        external
        pure
        returns (QuiltStruct memory)
    {
        QuiltStruct memory quilt;

        uint256 xRand = random(seed, "X") % 100;
        uint256 yRand = random(seed, "Y") % 100;
        quilt.patchXCount = 3;
        quilt.patchYCount = 3;

        if (xRand < 5) {
            quilt.patchXCount = 2;
        } else if (xRand > 60) {
            quilt.patchXCount = 4;
        } else if (xRand > 80) {
            quilt.patchXCount = 5;
        }

        if (yRand < 5) {
            quilt.patchYCount = 2;
        } else if (yRand > 60) {
            quilt.patchYCount = 4;
        } else if (yRand > 80) {
            quilt.patchYCount = 5;
        }

        uint256 maxX = 64 * quilt.patchXCount + (quilt.patchXCount - 1) * 6;
        uint256 maxY = 64 * quilt.patchYCount + (quilt.patchYCount - 1) * 6;
        quilt.xOff = (500 - maxX) / 2;
        quilt.yOff = (500 - maxY) / 2;
        quilt.quiltW = maxX + 32;
        quilt.quiltH = maxY + 32;
        quilt.quiltX = quilt.xOff + 0 - 16;
        quilt.quiltY = quilt.yOff + 0 - 16;
        quilt.themeIndex = random(seed, "T") % 8;
        quilt.hovers = random(seed, "H") % 100 > 90;

        quilt.backgroundIndex = 0;
        uint256 bgRand = random(seed, "BG") % 100;
        if (bgRand > 70) {
            quilt.backgroundIndex = 1;
        } else if (bgRand > 90) {
            quilt.backgroundIndex = 2;
        }

        return quilt;
    }

    function getQuiltSVG(string memory seed, QuiltStruct memory quilt)
        external
        pure
        returns (string memory)
    {
        string[40] memory colors = [
            "#5c457b",
            "#ff8fa4",
            "#f9bdbd",
            "#fbced6",
            "#006d77",
            "#ffafcc",
            "#FFE5EF",
            "#bde0fe",
            "#3d405b",
            "#f2cc8f",
            "#e07a5f",
            "#f4f1de",
            "#333d29",
            "#656d4a",
            "#dda15e",
            "#fefae0",
            "#6d2e46",
            "#d5b9b2",
            "#a26769",
            "#ece2d0",
            "#006d77",
            "#83c5be",
            "#ffddd2",
            "#edf6f9",
            "#0d1b2a",
            "#2F4865",
            "#7B88A7",
            "#B4C0D0",
            "#472e2a",
            "#e78a46",
            "#fac459",
            "#fde3ae",
            "#a71e34",
            "#ffa69e",
            "#ff686b",
            "#bfd7ea",
            "#222222",
            "#eeeeee",
            "#bbbbbb",
            "#bbbbbb"
        ];

        string[15] memory patches = [
            '<path fill="url(#c3)" d="M0 0h64v64H0z"/><path fill="url(#c1)" d="M0 0h64v32H0z"/><path fill="url(#c2)" d="M0 32 16 0v32H0Zm16 0L32 0v32H16Zm16 0L48 0v32H32Zm16 0L64 0v32H48Z"/><circle cx="16" cy="48" r="4" fill="url(#c1)"/><circle cx="48" cy="48" r="4" fill="url(#c1)"/>',
            '<path fill="url(#c2)" d="M0 0h64v64H0z"/><path fill="url(#c1)" d="M32 0h32v64H32z"/><path fill="url(#c3)" d="M0 64 64 0v64H0Z"/><circle cx="46" cy="46" r="10" fill="url(#c2)"/>',
            '<path fill="url(#c2)" d="M0 0h64v64H0z"/><path fill="url(#c1)" d="m52 16 8-16h16l-8 16v16l8 16v16H60V48l-8-16V16Zm-64 0 8-16h16L4 16v16l8 16v16H-4V48l-8-16V16Z"/><path fill="url(#c3)" d="m4 16 8-16h16l-8 16v16l8 16v16H12V48L4 32V16Zm32 0 8-16h16l-8 16v16l8 16v16H44V48l-8-16V16Z"/>',
            '<path fill="url(#c1)" d="M0 0h64v64H0z"/><path fill="url(#c3)" d="M0 60h64v8H0zm0-16h64v8H0zm0-16h64v8H0zm0-16h64v8H0zM0-4h64v8H0z"/>',
            '<path fill="url(#c1)" d="M0 0h64v64H0z"/><path fill="url(#c3)" d="M16 0H8L0 8v8L16 0Zm16 0h-8L0 24v8L32 0Zm16 0h-8L0 40v8L48 0Zm16 0h-8L0 56v8L64 0Zm0 16V8L8 64h8l48-48Zm0 16v-8L24 64h8l32-32Zm0 16v-8L40 64h8l16-16Zm0 16v-8l-8 8h8Z"/>',
            '<path fill="url(#c3)" d="M0 0h64v64H0z"/><path fill="url(#c1)" d="M0 64 32 0v64H0Zm32 0L64 0v64H32Z"/>',
            '<path fill="url(#c1)" d="M0 0h64v64H0z"/><path fill="url(#c3)" d="M0 64 64 0v64H0Z"/>',
            '<path fill="url(#c3)" d="M0 0h64v64H0z"/><path fill="url(#c1)" d="M0 16V0h64L48 16V0L32 16V0L16 16V0L0 16Z"/><path fill="url(#c2)" d="M0 48V32h64L48 48V32L32 48V32L16 48V32L0 48Z"/>',
            '<path fill="url(#c3)" d="M0 0h64v64H0z"/><path fill="url(#c1)" d="M0 0h48v48H0z"/><path fill="url(#c2)" d="M0 48 48 0v48H0Z"/><circle cx="23" cy="25" r="8" fill="url(#c3)"/>',
            '<path fill="url(#c3)" d="M0 0h64v64H0z"/><path fill="url(#c1)" d="M0 0h32v32H0zm32 32h32v32H32z"/>',
            '<path fill="url(#c1)" d="M0 0h64v64H0z"/><path fill="url(#c3)" d="M16 0 0 16v16l16-16 16 16 16-16 16 16V16L48 0 32 16 16 0Zm0 32L0 48v16l16-16 16 16 16-16 16 16V48L48 32 32 48 16 32Z"/>',
            '<path fill="url(#c3)" d="M0 0h64v64H0z"/><path fill="url(#c1)" d="M8 8h40v8H8z"/><path fill="url(#c2)" d="M24 32h8v8h-8zm8-8h8v8h-8z"/><path fill="url(#c1)" d="M24 24h8v8h-8zm8 8h8v8h-8zM16 48h40v8H16z"/><path fill="url(#c2)" d="M8 16h8v40H8zm40-8h8v40h-8z"/>',
            '<path fill="url(#c3)" d="M0 0h64v64H0z"/><path fill="url(#c1)" d="m24 4 8 8-8 8V4Zm0 40 8 8-8 8V44Zm-4-20-8 8-8-8h16Zm40 0-8 8-8-8h16ZM40 4l-8 8 8 8V4Zm0 40-8 8 8 8V44Zm-20-4-8-8-8 8h16Zm40 0-8-8-8 8h16Z"/><path fill="url(#c2)" d="M24 24h16v16H24z"/>',
            '<path fill="url(#c1)" d="M0 0h64v64H0z"/><path fill="url(#c2)" d="m32 0 16 16-16 16V0Zm0 64L16 48l16-16v32ZM48 0l16 16-16 16V0ZM16 64 .0000014 48 16 32v32Z"/><path fill="url(#c3)" d="M0 16 16 2e-7 32 16H0Zm64 32L48 64 32 48h32ZM32 32 16 16 0 32h32Zm0 0 16 16 16-16H32Z"/>',
            '<path fill="url(#c2)" d="M0 0h64v64H0z"/><path fill="url(#c3)" d="M0 0h64v64H0z"/><path fill="url(#c2)" d="M32 32-.0000014.0000019 32 5e-7V32Zm0 0 32 32H32V32Z"/><path fill="url(#c1)" d="M32 32-.00000381 64l.0000028-32H32Zm0 0L64 0v32H32Z"/>'
        ];

        string[6] memory backgrounds = [
            '<filter id="bf"><feTurbulence baseFrequency=".3" seed="',
            '" /><feColorMatrix values="0 0 0 10 -4 0 0 0 10 -4 0 0 0 10 -4 0 0 0 0 1"/><feColorMatrix values="-1 0 0 0 1 0 -1 0 0 1 0 0 -1 0 1 0 0 0 1 0"/></filter><rect width="100%" height="100%" filter="url(#bf)" fill="url(#c1)" style="mix-blend-mode:color-burn" opacity=".2" />',
            '<pattern id="bp" width="128" height="128" patternUnits="userSpaceOnUse"><path d="m64 16 32 32H64V16ZM128 16l32 32h-32V16ZM0 16l32 32H0V16ZM128 76l-32 32h32V76ZM64 76l-32 32h32V76Z" fill="url(#c1)"/></pattern><filter id="bf"><feTurbulence type="fractalNoise" baseFrequency="0.002" numOctaves="1" seed="',
            '"/><feDisplacementMap in="SourceGraphic" xChannelSelector="R" scale="100"/></filter><rect x="-50%" y="-50%" width="200%" height="200%" filter="url(#bf)" fill="url(#bp)" style="mix-blend-mode:overlay" opacity=".6" />',
            '<pattern id="bp" width="80" height="40" patternUnits="userSpaceOnUse"><path d="M0 20a20 20 0 1 1 0 1M40 0a20 20 0 1 0 40 0m0 40a20 20 0 1 0 -40 0" fill="url(#c2)" opacity=".2"/></pattern><filter id="bf"><feTurbulence type="fractalNoise" baseFrequency="0.02" numOctaves="1" seed="',
            '"/><feDisplacementMap in="SourceGraphic" xChannelSelector="R" scale="200"/></filter><rect x="-50%" y="-50%" width="200%" height="200%" filter="url(#bf)" fill="url(#bp)" />'
        ];

        string[7] memory parts;

        for (uint256 col = 0; col < quilt.patchXCount; col++) {
            for (uint256 row = 0; row < quilt.patchYCount; row++) {
                uint256 x = quilt.xOff + 70 * col;
                uint256 y = quilt.yOff + 70 * row;
                uint256 patchIndex = random(
                    seed,
                    string(abi.encodePacked(col, row))
                ) % 14;
                parts[0] = string(
                    abi.encodePacked(
                        parts[0],
                        '<mask id="s',
                        Strings.toString(col + 1),
                        Strings.toString(row + 1),
                        '"><rect rx="8" x="',
                        Strings.toString(x),
                        '" y="',
                        Strings.toString(y),
                        '" width="64" height="64" fill="white"/></mask>'
                    )
                );
                parts[6] = string(
                    abi.encodePacked(
                        parts[6],
                        '<g mask="url(#s',
                        Strings.toString(col + 1),
                        Strings.toString(row + 1),
                        ')"><g transform="translate(',
                        Strings.toString(x),
                        " ",
                        Strings.toString(y),
                        ')">',
                        patches[patchIndex],
                        "</g></g>"
                    )
                );
                parts[5] = string(
                    abi.encodePacked(
                        parts[5],
                        '<rect rx="8" stroke-width="2" stroke-linecap="round" stroke="url(#c1)" stroke-dasharray="4 4" x="',
                        Strings.toString(x),
                        '" y="',
                        Strings.toString(y),
                        '" width="64" height="64" fill="transparent"/>'
                    )
                );
            }
        }

        parts[1] = string(
            abi.encodePacked(
                '<linearGradient id="c1"><stop stop-color="',
                colors[quilt.themeIndex * 4],
                '"/></linearGradient><linearGradient id="c2"><stop stop-color="',
                colors[(quilt.themeIndex * 4) + 1],
                '"/></linearGradient><linearGradient id="c3"><stop stop-color="',
                colors[(quilt.themeIndex * 4) + 2],
                '"/></linearGradient><linearGradient id="c4"><stop stop-color="',
                colors[(quilt.themeIndex * 4) + 3],
                '"/></linearGradient>'
            )
        );

        parts[2] = string(
            abi.encodePacked(
                backgrounds[quilt.backgroundIndex * 2],
                seed,
                backgrounds[(quilt.backgroundIndex * 2) + 1]
            )
        );

        parts[3] = string(
            abi.encodePacked(
                '<rect transform="translate(',
                Strings.toString(quilt.quiltX + 8),
                " ",
                Strings.toString(quilt.quiltY + 8),
                ')" x="0" y="0" width="',
                Strings.toString(quilt.quiltW),
                '" height="',
                Strings.toString(quilt.quiltH),
                '" rx="16" fill="url(#c1)" />'
            )
        );

        parts[4] = string(
            abi.encodePacked(
                '<rect x="',
                Strings.toString(quilt.quiltX),
                '" y="',
                Strings.toString(quilt.quiltY),
                '" width="',
                Strings.toString(quilt.quiltW),
                '" height="',
                Strings.toString(quilt.quiltH),
                '" rx="17" fill="url(#c2)" stroke="url(#c1)" stroke-width="2"/>'
            )
        );

        string memory svg = string(
            abi.encodePacked(
                '<svg width="500" height="500" viewBox="0 0 500 500" xmlns="http://www.w3.org/2000/svg"><defs>',
                parts[0],
                parts[1],
                '</defs><rect width="500" height="500" fill="url(#c3)" />',
                parts[2],
                '<filter id="f" x="-50%" y="-50%" width="200%" height="200%"><feTurbulence baseFrequency="0.003" seed="',
                seed,
                '"/><feDisplacementMap in="SourceGraphic" scale="10"/></filter><g><g filter="url(#f)">',
                parts[3]
            )
        );

        svg = string(
            abi.encodePacked(
                svg,
                quilt.hovers
                    ? '<animateTransform attributeName="transform" type="scale" additive="sum" dur="4s" values="1 1; 1.005 1.02; 1 1;" calcMode="spline" keySplines="0.45, 0, 0.55, 1; 0.45, 0, 0.55, 1;" repeatCount="indefinite"/>'
                    : "",
                '</g><g filter="url(#f)">',
                parts[4],
                parts[5],
                parts[6],
                quilt.hovers
                    ? '<animateTransform attributeName="transform" type="translate" dur="4s" values="0,0; -4,-16; 0,0;" calcMode="spline" keySplines="0.45, 0, 0.55, 1; 0.45, 0, 0.55, 1;" repeatCount="indefinite"/>'
                    : "",
                "</g></g></svg>"
            )
        );

        return svg;
    }

    function random(string memory seed, string memory key)
        internal
        pure
        returns (uint256)
    {
        return uint256(keccak256(abi.encodePacked(key, seed)));
    }
}