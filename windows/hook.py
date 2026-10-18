import threading
from pynput import mouse, keyboard
from PyQt6.QtCore import QObject, pyqtSignal

class GlobalDragHook(QObject):
    summon_wheel = pyqtSignal()
    dismiss_wheel = pyqtSignal()

    def __init__(self):
        super().__init__()
        self.is_shift_down = False
        self.is_mouse_down = False
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
        self.keyboard_listener.start()
        self.mouse_listener.start()

    def stop(self):
        if self.keyboard_listener:
            self.keyboard_listener.stop()
        if self.mouse_listener:
            self.mouse_listener.stop()

    def _on_key_press(self, key):
        if key in [keyboard.Key.shift, keyboard.Key.shift_l, keyboard.Key.shift_r]:
            self.is_shift_down = True
            if self.is_mouse_down:
                self.summon_wheel.emit()

    def _on_key_release(self, key):
        if key in [keyboard.Key.shift, keyboard.Key.shift_l, keyboard.Key.shift_r]:
            self.is_shift_down = False
            self.dismiss_wheel.emit()
        elif key == keyboard.Key.esc:
            self.dismiss_wheel.emit()

    def _on_click(self, x, y, button, pressed):
        if button == mouse.Button.left:
            self.is_mouse_down = pressed
            if not pressed:
                # Mouse released
                pass

    def _on_move(self, x, y):
        if self.is_shift_down and self.is_mouse_down:
            self.summon_wheel.emit()
