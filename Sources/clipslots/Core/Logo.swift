import Foundation

/// Clipboard logo shown next to the fastfetch-style `status` output.
/// Uses single-width BMP box-drawing chars so `Style.visibleWidth` stays
/// accurate. Color is applied at render time by the caller.
let logoLines: [String] = [
    "        ╭───╮        ",
    "     ╭──┤ ○ ├──╮     ",
    "  ╭──┴──┴───┴──┴──╮  ",
    "  │ ╭───────────╮ │  ",
    "  │ │ CLIPSLOTS │ │  ",
    "  │ │           │ │  ",
    "  │ │ [1][2][3] │ │  ",
    "  │ │ [4][5][6] │ │  ",
    "  │ │ [7][8][9] │ │  ",
    "  │ ╰───────────╯ │  ",
    "  ╰───────────────╯  ",
]
