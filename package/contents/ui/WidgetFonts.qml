import QtQuick

/**
 * Inter, the font of the widget unless another one is chosen, comes with it, so that it looks the
 * same on every desktop: the weights the text is drawn in. Made by tools/fonts/subset.py, named
 * "Solar Now Inter": a font loaded like this belongs to the whole Plasma process, and under the name
 * of Inter this cut would take the place of an Inter installed on the system. It shows up in the font
 * dialog of the settings too.
 */
QtObject {
    /** The family of the text; empty until it is loaded, and if it cannot be. */
    readonly property string text: regular.status === FontLoader.Ready ? regular.name : ""

    readonly property FontLoader regular: FontLoader {
        source: "../fonts/Inter-Regular.ttf"
    }
    readonly property FontLoader semiBold: FontLoader {
        source: "../fonts/Inter-SemiBold.ttf"
    }
    readonly property FontLoader bold: FontLoader {
        source: "../fonts/Inter-Bold.ttf"
    }
}
