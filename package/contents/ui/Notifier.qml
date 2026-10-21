import QtQuick
import org.kde.notification

/**
 * Sends desktop notifications. It is loaded on its own, through a Loader, so that a system
 * without this module loses the notifications and nothing else.
 */
QtObject {
    id: notifier

    readonly property Component message: Component {
        Notification {
            // The events every Plasma session knows, whatever application sends them.
            componentName: "plasma_workspace"
            eventId: "notification"
            iconName: "battery-full-charging"
        }
    }

    function send(title: string, text: string): void {
        // A notification deletes itself once it is closed. Its text is read as markup, and the name of
        // an alert comes from Deye Cloud: "Grid voltage < 180 V" is to read as it is written.
        const plain = String(text).replace(/[&<>]/g, character => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;" })[character]);

        message.createObject(notifier, { title: title, text: plain }).sendEvent();
    }
}
