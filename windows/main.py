import sys
import traceback
from PyQt6.QtWidgets import (
    QApplication, QSystemTrayIcon, QMenu, QMainWindow, QLabel,
    QVBoxLayout, QWidget, QPushButton, QMessageBox
)
from PyQt6.QtGui import QIcon, QPixmap, QColor, QPainter, QAction
from PyQt6.QtCore import Qt
from radial_wheel import RadialWheelWindow, THEMES
from hook import GlobalDragHook

def excepthook(exc_type, exc_value, exc_tb):
    error_msg = "".join(traceback.format_exception(exc_type, exc_value, exc_tb))
    print("FATAL ERROR:\n", error_msg, file=sys.stderr)
    try:
        QMessageBox.critical(None, "Dragged Error", error_msg)
    except Exception:
        pass
    sys.__excepthook__(exc_type, exc_value, exc_tb)

sys.excepthook = excepthook

def create_tray_icon():
    # Render custom radial wheel tray icon
    pixmap = QPixmap(32, 32)
    pixmap.fill(Qt.GlobalColor.transparent)
    painter = QPainter(pixmap)
    painter.setRenderHint(QPainter.RenderHint.Antialiasing)
    painter.setPen(QColor(255, 140, 20))
    painter.setBrush(QColor(255, 140, 20, 200))
    painter.drawEllipse(4, 4, 24, 24)
    painter.setBrush(QColor(255, 255, 255))
    painter.drawEllipse(12, 12, 8, 8)
    painter.end()
    return QIcon(pixmap)

def main():
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)

    wheel_window = RadialWheelWindow()
    hook = GlobalDragHook()

    def on_summon():
        try:
            if not wheel_window.isVisible():
                wheel_window.show_at_cursor()
        except Exception as e:
            print(f"Error on summon: {e}")

    def on_dismiss():
        try:
            if wheel_window.isVisible():
                wheel_window.hide()
        except Exception as e:
            print(f"Error on dismiss: {e}")

    hook.summon_wheel.connect(on_summon)
    hook.dismiss_wheel.connect(on_dismiss)
    hook.start()

    tray_icon = QSystemTrayIcon(create_tray_icon(), app)
    tray_icon.setToolTip("Dragged: Radial Gesture File Converter")

    menu = QMenu()
    title_action = QAction("Dragged (v1.2.0)", menu)
    title_action.setEnabled(False)
    menu.addAction(title_action)
    menu.addSeparator()

    trigger_action = QAction("Trigger Radial Wheel at Cursor", menu)
    trigger_action.triggered.connect(lambda: wheel_window.show_at_cursor())
    menu.addAction(trigger_action)

    # 🎨 Theme Submenu for Windows
    theme_menu = QMenu("Theme", menu)
    theme_actions = {}

    def update_theme_checks():
        for k, a in theme_actions.items():
            a.setChecked(wheel_window.theme_name == k)

    for key, th in THEMES.items():
        act = QAction(th["name"], theme_menu)
        act.setCheckable(True)
        act.setChecked(wheel_window.theme_name == key)
        def make_handler(k):
            return lambda: (wheel_window.set_theme(k), update_theme_checks())
        act.triggered.connect(make_handler(key))
        theme_menu.addAction(act)
        theme_actions[key] = act

    menu.addMenu(theme_menu)
    menu.addSeparator()

    quit_action = QAction("Quit Dragged", menu)
    quit_action.triggered.connect(app.quit)
    menu.addAction(quit_action)

    tray_icon.setContextMenu(menu)
    tray_icon.show()

    print("🍊 Dragged for Windows started. Hold Shift and drag any file to open the Radial Wheel.")
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
