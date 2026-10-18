from pynput import mouse, keyboard
from PyQt6.QtCore import QObject, pyqtSignal

class GlobalDragHook(QObject):
    summon_wheel = pyqtSignal()
    dismiss_wheel = pyqtSignal()

    def __init__(self):
        super().__init__()
        self.is_shift_down = False
        self.is_mouse_down = False
        self.wheel_active = False
        self.mouse_listener = None
        self.keyboard_listener = None

    def start(self):
        self.keyboard_listener = keyboard.Listener(
            on_press=self._on_key_press,
            on_release=self._on_key_release
        )
        self.mouse_listener = mouse.Listener(
            on_click=self._on_click,
            on_move=self._on_move
        )
        self.keyboard_listener.daemon = True
        self.mouse_listener.daemon = True
        self.keyboard_listener.start()
        self.mouse_listener.start()

    def stop(self):
        try:
            if self.keyboard_listener:
                self.keyboard_listener.stop()
            if self.mouse_listener:
                self.mouse_listener.stop()
        except Exception:
            pass

    def _on_key_press(self, key):
        try:
            if key in (keyboard.Key.shift, keyboard.Key.shift_l, keyboard.Key.shift_r):
                self.is_shift_down = True
                if self.is_mouse_down and not self.wheel_active:
                    self.wheel_active = True
                    self.summon_wheel.emit()
        except Exception:
            pass

    def _on_key_release(self, key):
        try:
            if key in (keyboard.Key.shift, keyboard.Key.shift_l, keyboard.Key.shift_r):
                self.is_shift_down = False
                if self.wheel_active:
                    self.wheel_active = False
                    self.dismiss_wheel.emit()
            elif key == keyboard.Key.esc:
                if self.wheel_active:
                    self.wheel_active = False
                    self.dismiss_wheel.emit()
        except Exception:
            pass

    def _on_click(self, x, y, button, pressed):
        try:
            if button == mouse.Button.left:
                self.is_mouse_down = pressed
                if pressed:
                    if self.is_shift_down and not self.wheel_active:
                        self.wheel_active = True
                        self.summon_wheel.emit()
                else:
                    # Mouse released
                    if self.wheel_active:
                        self.wheel_active = False
                        self.dismiss_wheel.emit()
        except Exception:
            pass

    def _on_move(self, x, y):
        try:
            if self.is_shift_down and self.is_mouse_down:
                if not self.wheel_active:
                    self.wheel_active = True
                    self.summon_wheel.emit()
        except Exception:
            pass
