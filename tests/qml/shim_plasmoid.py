"""Stand-in for the org.kde.plasma.plasmoid QML module: the `Plasmoid` attached object and `PlasmoidItem`."""

from PySide6.QtCore import Property, QObject, Signal, Slot
from PySide6.QtQml import ListProperty, QmlAnonymous, QmlAttached, QmlElement, QQmlComponent, QQmlPropertyMap
from PySide6.QtQuick import QQuickItem

QML_IMPORT_NAME = "org.kde.plasma.plasmoid"
QML_IMPORT_MAJOR_VERSION = 1

#: PlasmaCore.Types.FormFactor: where the widget is, a panel unless a run says otherwise.
FORM_FACTORS = {"planar": 0, "horizontal": 2, "vertical": 3}
form_factor = [FORM_FACTORS["horizontal"]]


def accessors(name, signal_name):
    """Getter and setter of a notifying property stored in `_<name>`."""

    def getter(self):
        return getattr(self, f"_{name}")

    def setter(self, value):
        if getattr(self, f"_{name}") != value:
            setattr(self, f"_{name}", value)
            getattr(self, signal_name).emit()

    return getter, setter


@QmlAnonymous
class InternalAction(QObject):
    """One of the actions Plasma itself gives a widget, such as opening its settings."""

    def __init__(self, name, parent=None):
        super().__init__(parent)
        self.name = name
        self.triggered = 0

    @Slot()
    def trigger(self):
        self.triggered += 1


@QmlAnonymous
class Applet(QObject):
    """What `Plasmoid.` resolves to anywhere inside the widget."""

    iconChanged = Signal()
    backgroundHintsChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._configuration = QQmlPropertyMap(self)
        self._icon = ""
        self._backgroundHints = 1
        self.actions = []
        self.internal_actions = {}

    @Property(QObject, constant=True)
    def configuration(self):
        return self._configuration

    @Property(int, constant=True)
    def formFactor(self):
        return form_factor[0]

    @Property(str, constant=True)
    def title(self):
        return "Solar Now"

    icon = Property(str, *accessors("icon", "iconChanged"), notify=iconChanged)
    backgroundHints = Property(int, *accessors("backgroundHints", "backgroundHintsChanged"), notify=backgroundHintsChanged)

    @Slot(str, result=QObject)
    def internalAction(self, name):
        if name not in self.internal_actions:
            self.internal_actions[name] = InternalAction(name, self)

        return self.internal_actions[name]

    def append_action(self, action):
        self.actions.append(action)

    contextualActions = ListProperty(QObject, append_action)


_applet = None


def applet():
    """The single applet every `Plasmoid` attachment shares; created on first use, after the application exists."""
    global _applet

    if _applet is None:
        _applet = Applet()

    return _applet


@QmlElement
@QmlAttached(Applet)
class Plasmoid(QObject):
    @staticmethod
    def qmlAttachedProperties(self, attachee):
        return applet()


@QmlElement
class PlasmoidItem(QQuickItem):
    compactRepresentationChanged = Signal()
    fullRepresentationChanged = Signal()
    preferredRepresentationChanged = Signal()
    switchWidthChanged = Signal()
    switchHeightChanged = Signal()
    toolTipMainTextChanged = Signal()
    toolTipSubTextChanged = Signal()
    expandedChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._compactRepresentation = None
        self._fullRepresentation = None
        self._preferredRepresentation = None
        self._switchWidth = 0.0
        self._switchHeight = 0.0
        self._toolTipMainText = ""
        self._toolTipSubText = ""
        self._expanded = False

    compactRepresentation = Property(QQmlComponent, *accessors("compactRepresentation", "compactRepresentationChanged"), notify=compactRepresentationChanged)
    fullRepresentation = Property(QQmlComponent, *accessors("fullRepresentation", "fullRepresentationChanged"), notify=fullRepresentationChanged)
    preferredRepresentation = Property(QQmlComponent, *accessors("preferredRepresentation", "preferredRepresentationChanged"), notify=preferredRepresentationChanged)
    switchWidth = Property(float, *accessors("switchWidth", "switchWidthChanged"), notify=switchWidthChanged)
    switchHeight = Property(float, *accessors("switchHeight", "switchHeightChanged"), notify=switchHeightChanged)
    toolTipMainText = Property(str, *accessors("toolTipMainText", "toolTipMainTextChanged"), notify=toolTipMainTextChanged)
    toolTipSubText = Property(str, *accessors("toolTipSubText", "toolTipSubTextChanged"), notify=toolTipSubTextChanged)
    expanded = Property(bool, *accessors("expanded", "expandedChanged"), notify=expandedChanged)
