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
        // A notification deletes itself once it is closed.
        message.createObject(notifier, { title: title, text: text }).sendEvent();
    }
}
