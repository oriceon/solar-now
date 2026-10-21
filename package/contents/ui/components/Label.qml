import QtQuick
import org.kde.plasma.components as PlasmaComponents

/**
 * A label in the font and the size chosen in the settings of the widget. Plain text unless it says
 * otherwise: the names of the station, the devices and the alerts come from Deye Cloud, and a label
 * that read markup in them drew it, and loaded any picture one named.
 */
PlasmaComponents.Label {
    /** `{ family, size }`, see `typography` in FullRepresentation. */
    required property var typography
    /** Size of the text relative to the base size of the widget. */
    property real relativeSize: 1

    font.family: typography.family
    font.pointSize: typography.size * relativeSize
    textFormat: Text.PlainText
}
