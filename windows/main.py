import sys
import traceback
from PyQt6.QtWidgets import (
    QApplication, QSystemTrayIcon, QMenu, QMessageBox
)
from PyQt6.QtGui import QIcon, QPixmap, QColor, QPainter, QAction
from PyQt6.QtCore import Qt, QTimer
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

    tray_icon = QSystemTrayIcon(create_tray_icon(), app)
    tray_icon.setToolTip("Dragged: Radial Gesture File Converter")

    def handle_notification(title, message, is_error):
        try:
            icon = QSystemTrayIcon.MessageIcon.Warning if is_error else QSystemTrayIcon.MessageIcon.Information
            tray_icon.showMessage(title, message, icon, 3500)
        except Exception as e:
            print(f"Error showing notification: {e}")

    wheel_window.notify.connect(handle_notification)

    dismiss_timer = QTimer()
    dismiss_timer.setSingleShot(True)

    def on_summon():
        try:
            dismiss_timer.stop()
            if not wheel_window.isVisible():
                wheel_window.show_at_cursor()
        except Exception as e:
            print(f"Error on summon: {e}")

    def on_dismiss():
        try:
            # Delay dismissal by 200ms to allow dropEvent / click processing to register
            if wheel_window.isVisible():
                dismiss_timer.start(200)
        except Exception as e:
            print(f"Error on dismiss: {e}")

    def do_delayed_dismiss():
        try:
            if wheel_window.isVisible():
                wheel_window.hide()
            hook.wheel_active = False
        except Exception as e:
            print(f"Error in do_delayed_dismiss: {e}")

    dismiss_timer.timeout.connect(do_delayed_dismiss)

    def on_action_done():
        dismiss_timer.stop()
        hook.wheel_active = False

    wheel_window.action_completed.connect(on_action_done)

    hook.summon_wheel.connect(on_summon)
    hook.dismiss_wheel.connect(on_dismiss)
    hook.start()

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

    # Friendly launch message
    tray_icon.showMessage(
        "Dragged is Running",
        "Hold Shift and drag any file to open the Radial Wheel!",
        QSystemTrayIcon.MessageIcon.Information,
        3000
    )

    print("🍊 Dragged for Windows started. Hold Shift and drag any file to open the Radial Wheel.")
    sys.exit(app.exec())

if __name__ == "__main__":
    main()
