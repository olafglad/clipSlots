import Foundation

/// ASCII art logo shown next to the fastfetch-style `status` output.
/// Pure ASCII (no emoji, no box-drawing) so `Style.visibleWidth` stays
/// accurate. Color is applied at render time by the caller.
let logoLines: [String] = [
    "   _________________  ",
    "  |  _____________  | ",
    "  | |             | | ",
    "  | |  CLIPSLOTS  | | ",
    "  | |             | | ",
    "  | |  [1] [2] [3]| | ",
    "  | |  [4] [5] [6]| | ",
    "  | |  [7] [8] [9]| | ",
    "  | |_____________| | ",
    "  |_________________| ",
    "    \\_______________/ ",
]
