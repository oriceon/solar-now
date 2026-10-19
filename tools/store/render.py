"""Renders a QML file to a PNG with a transparent background."""
import sys
from PySide6.QtCore import QTimer, QUrl, Qt
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView

app = QGuiApplication(sys.argv[:1])
view = QQuickView()
view.setColor(Qt.transparent)
view.setSource(QUrl.fromLocalFile(sys.argv[1]))
if view.status() != QQuickView.Ready:
    print([error.toString() for error in view.errors()])
    sys.exit(1)
view.show()

def save():
    image = view.grabWindow()
    print(sys.argv[2], image.width(), image.height(), image.save(sys.argv[2]))
    app.quit()

QTimer.singleShot(800, save)
app.exec()
