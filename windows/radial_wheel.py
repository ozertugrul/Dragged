import math
import os
from pathlib import Path
from PyQt6.QtCore import Qt, QPoint, QRectF, QTimer, pyqtSignal
from PyQt6.QtGui import (
    QPainter, QColor, QBrush, QPen, QPainterPath, QLinearGradient,
    QFont, QIcon, QPixmap
)
from PyQt6.QtWidgets import QWidget, QApplication
from converter import ConversionEngine

try:
    from win10toast import ToastNotifier
    toaster = ToastNotifier()
except Exception:
    toaster = None

CATEGORIES = [
    {
        "title": "IMAGE FORMATS",
        "petals": [
            {"name": "PNG", "id": "png", "hint": "Lossless · transparency"},
            {"name": "WEBP", "id": "webp", "hint": "Smallest for web"},
            {"name": "HEIC", "id": "heic", "hint": "iPhone format"},
            {"name": "GIF", "id": "gif", "hint": "Animated · web"},
            {"name": "AVIF", "id": "avif", "hint": "Next-gen, tiny"},
            {"name": "BMP", "id": "bmp", "hint": "Uncompressed"},
            {"name": "PDF", "id": "pdf", "hint": "Document pages"},
            {"name": "DOCX", "id": "docx", "hint": "Editable Word"},
        ],
        "center": {"name": "TIFF", "id": "tiff", "hint": "Print · archival"}
    },
    {
        "title": "TOOLS & EDIT",
        "petals": [
            {"name": "COMPRESS", "id": "compress_image", "hint": "Shrink file size"},
            {"name": "METADATA", "id": "metadata", "hint": "Strip GPS & EXIF"},
            {"name": "EDIT", "id": "edit", "hint": "Light · colour · rotate"},
            {"name": "ANNOTATE", "id": "annotate", "hint": "Arrows · text · steps"},
            {"name": "REMOVE BG", "id": "remove_bg", "hint": "Cut out subject"},
            {"name": "PREVIEW", "id": "preview", "hint": "Quick look"},
            {"name": "CROP", "id": "crop", "hint": "Trim to ratio"},
            {"name": "REDACT", "id": "redact", "hint": "Hide sensitive info"},
        ],
        "center": {"name": "ADD BG", "id": "add_bg", "hint": "Solid or gradient"}
    },
    {
        "title": "VIDEO & AUDIO",
        "petals": [
            {"name": "MP4", "id": "to_mp4", "hint": "Universal video"},
            {"name": "GIF", "id": "video_to_gif", "hint": "Clip to GIF"},
            {"name": "MP3", "id": "extract_audio", "hint": "Extract sound"},
            {"name": "WAV", "id": "to_wav", "hint": "Lossless audio"},
            {"name": "MOV", "id": "to_mov", "hint": "QuickTime video"},
            {"name": "WEBM", "id": "to_webm", "hint": "HTML5 video"},
            {"name": "M4A", "id": "to_m4a", "hint": "Apple audio"},
            {"name": "COMPRESS", "id": "compress_video", "hint": "Reduce bitrate"},
        ],
        "center": {"name": "MUTE", "id": "mute_video", "hint": "Strip audio track"}
    },
    {
        "title": "PDF & DOCUMENTS",
        "petals": [
            {"name": "TO PDF", "id": "to_pdf", "hint": "Export to PDF"},
            {"name": "COMPRESS", "id": "compress_pdf", "hint": "Shrink PDF size"},
            {"name": "SPLIT", "id": "split_pdf", "hint": "Separate pages"},
            {"name": "MERGE", "id": "merge_pdf", "hint": "Combine into one"},
            {"name": "OCR TEXT", "id": "ocr_pdf", "hint": "Recognize text"},
            {"name": "TO IMAGES", "id": "pdf_to_images", "hint": "Page by page images"},
            {"name": "TO WORD", "id": "pdf_to_docx", "hint": "Convert to DOCX"},
            {"name": "PRINT", "id": "print_doc", "hint": "Send to printer"},
        ],
        "center": {"name": "PREVIEW", "id": "preview", "hint": "View document"}
    }
]

class RadialWheelWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowFlags(
            Qt.WindowType.FramelessWindowHint |
            Qt.WindowType.WindowStaysOnTopHint |
            Qt.WindowType.Tool
        )
        self.setAttribute(Qt.WidgetAttribute.WA_TranslucentBackground)
        self.setAcceptDrops(True)
        self.setMouseTracking(True)

        self.size_val = 440
        self.setFixedSize(self.size_val, self.size_val)

        self.inner_r = 68
        self.outer_r = 162
        self.category_idx = 0
        self.hovered_idx = None  # 0..7 or 999 for center
        self.current_files = []
        self.thumbnail_pixmap = None

    def show_at_cursor(self, files=None):
        self.current_files = files or []
        if self.current_files:
            # Auto select category based on file
            ext = Path(self.current_files[0]).suffix.lower().lstrip(".")
            if ext in ["mp4", "mov", "avi", "mkv", "mp3", "wav"]:
                self.category_idx = 2
            elif ext in ["pdf", "docx", "txt"]:
                self.category_idx = 3
            else:
                self.category_idx = 0
        
        pos = QApplication.primaryScreen().cursor().pos()
        self.move(int(pos.x() - self.size_val / 2), int(pos.y() - self.size_val / 2))
        self.show()
        self.raise_()
        self.activateWindow()

    def keyPressEvent(self, event):
        if event.key() == Qt.Key.Key_Escape:
            self.hide()
        elif event.key() in (Qt.Key.Key_Tab, Qt.Key.Key_Shift):
            self.category_idx = (self.category_idx + 1) % len(CATEGORIES)
            self.hovered_idx = None
            self.update()

    def wheelEvent(self, event):
        # Rotate category on scroll
        delta = event.angleDelta().y()
        if delta < 0:
            self.category_idx = (self.category_idx + 1) % len(CATEGORIES)
        elif delta > 0:
            self.category_idx = (self.category_idx - 1 + len(CATEGORIES)) % len(CATEGORIES)
        self.hovered_idx = None
        self.update()

    def mouseMoveEvent(self, event):
        self.update_hover(event.position().x(), event.position().y())

    def update_hover(self, px, py):
        cx, cy = self.size_val / 2, self.size_val / 2
        dx = px - cx
        dy = py - cy
        dist = math.hypot(dx, dy)

        # Center pill
        if abs(dx) < 50 and abs(dy) < 24:
            if self.hovered_idx != 999:
                self.hovered_idx = 999
                self.update()
            return

        if dist < self.inner_r - 4 or dist > self.outer_r + 30:
            if self.hovered_idx is not None:
                self.hovered_idx = None
                self.update()
            return

        angle_deg = math.degrees(math.atan2(dy, dx))
        slice_deg = 45.0
        normalized = (angle_deg + 112.5) % 360.0
        idx = int(normalized / slice_deg) % 8

        if self.hovered_idx != idx:
            self.hovered_idx = idx
            self.update()

    def mousePressEvent(self, event):
        if event.button() == Qt.MouseButton.LeftButton:
            self.trigger_action()

    def trigger_action(self):
        idx = self.hovered_idx
        self.hide()
        if idx is None or not self.current_files:
            return

        cat = CATEGORIES[self.category_idx]
        item = cat["center"] if idx == 999 else cat["petals"][idx]

        for file_path in self.current_files:
            try:
                if self.category_idx == 0 and idx != 999:
                    dest = ConversionEngine.convert_image(file_path, item["id"])
                elif self.category_idx == 0 and idx == 999:
                    dest = ConversionEngine.convert_image(file_path, "tiff")
                else:
                    dest = ConversionEngine.execute_tool(file_path, item["id"])

                # Notify via Windows Toast
                if toaster:
                    toaster.show_toast(
                        "Dragged",
                        f"Saved: {Path(dest).name}",
                        duration=3,
                        threaded=True
                    )
            except Exception as e:
                print(f"Conversion error: {e}")

    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls():
            event.acceptProposedAction()
            self.current_files = [u.toLocalFile() for u in event.mimeData().urls()]

    def dragMoveEvent(self, event):
        self.update_hover(event.position().x(), event.position().y())
        event.acceptProposedAction()

    def dropEvent(self, event):
        event.acceptProposedAction()
        self.trigger_action()

    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        cx, cy = self.size_val / 2, self.size_val / 2

        # 1. Outer Frosted Glass Ring
        painter.setPen(QPen(QColor(255, 140, 20, 100), 2))
        painter.setBrush(QBrush(QColor(245, 230, 210, 215)))
        painter.drawEllipse(int(cx - self.outer_r - 9), int(cy - self.outer_r - 9), int((self.outer_r + 9) * 2), int((self.outer_r + 9) * 2))

        # 2. Inner Ring Boundary
        painter.setPen(QPen(QColor(255, 140, 20, 90), 1))
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawEllipse(int(cx - self.inner_r), int(cy - self.inner_r), int(self.inner_r * 2), int(self.inner_r * 2))

        # 3. 8 Petals
        cat = CATEGORIES[self.category_idx]
        slice_deg = 45.0
        gap_deg = 3.2

        for i, petal in enumerate(cat["petals"]):
            is_hovered = (self.hovered_idx == i)
            start_deg = i * slice_deg - 90.0 - (slice_deg / 2.0) + gap_deg
            end_deg = start_deg + slice_deg - (2 * gap_deg)

            path = QPainterPath()
            steps = 20
            # Outer arc
            r_out = self.outer_r + 6 if is_hovered else self.outer_r
            for s in range(steps + 1):
                deg = start_deg + (end_deg - start_deg) * (s / steps)
                rad = math.radians(deg)
                x = cx + r_out * math.cos(rad)
                y = cy + r_out * math.sin(rad)
                if s == 0:
                    path.moveTo(x, y)
                else:
                    path.lineTo(x, y)
            # Inner arc
            for s in range(steps, -1, -1):
                deg = start_deg + (end_deg - start_deg) * (s / steps)
                rad = math.radians(deg)
                x = cx + (self.inner_r + 4) * math.cos(rad)
                y = cy + (self.inner_r + 4) * math.sin(rad)
                path.lineTo(x, y)
            path.closeSubpath()

            if is_hovered:
                grad = QLinearGradient(0, 0, self.size_val, self.size_val)
                grad.setColorAt(0, QColor(250, 108, 30))
                grad.setColorAt(1, QColor(225, 65, 10))
                painter.setBrush(QBrush(grad))
                painter.setPen(QPen(QColor(255, 255, 255, 220), 2))
            else:
                painter.setBrush(QBrush(QColor(255, 245, 230, 240)))
                painter.setPen(QPen(QColor(255, 255, 255, 180), 1))

            painter.drawPath(path)

            # Draw Label
            mid_rad = math.radians(i * slice_deg - 90.0)
            dist = (self.inner_r + self.outer_r) / 2 + 2
            tx = cx + dist * math.cos(mid_rad)
            ty = cy + dist * math.sin(mid_rad)

            painter.setPen(QColor(255, 255, 255) if is_hovered else QColor(35, 35, 35))
            font = QFont("Segoe UI", 9 if is_hovered else 8, QFont.Weight.Bold)
            painter.setFont(font)
            text_rect = QRectF(tx - 40, ty - 12, 80, 24)
            painter.drawText(text_rect, Qt.AlignmentFlag.AlignCenter, petal["name"])

        # 4. Center Pill with Dynamic Hint
        is_center_hovered = (self.hovered_idx == 999)
        center_item = cat["center"]
        pill_rect = QRectF(cx - 52, cy - 24, 104, 48)

        # Determine what title and hint to show in the center
        if 0 <= (self.hovered_idx or -1) < 8:
            hov = cat["petals"][self.hovered_idx]
            display_title = hov["name"]
            display_hint = hov.get("hint", "")
            is_active_hub = True
        elif is_center_hovered:
            display_title = center_item["name"]
            display_hint = center_item.get("hint", "")
            is_active_hub = True
        else:
            display_title = center_item["name"]
            display_hint = "⇧ TAB / SCROLL"
            is_active_hub = False

        if is_active_hub:
            grad = QLinearGradient(0, 0, self.size_val, self.size_val)
            grad.setColorAt(0, QColor(250, 108, 30))
            grad.setColorAt(1, QColor(225, 65, 10))
            painter.setBrush(QBrush(grad))
            painter.setPen(QPen(QColor(255, 255, 255, 220), 2))
        else:
            painter.setBrush(QBrush(QColor(255, 245, 230, 245)))
            painter.setPen(QPen(QColor(255, 140, 20, 180), 1))

        painter.drawRoundedRect(pill_rect, 24, 24)
        
        # Title text
        painter.setPen(QColor(255, 255, 255) if is_active_hub else QColor(35, 35, 35))
        painter.setFont(QFont("Segoe UI", 8, QFont.Weight.Black))
        painter.drawText(QRectF(cx - 50, cy - 20, 100, 18), Qt.AlignmentFlag.AlignCenter, display_title)

        # Hint subtext
        painter.setPen(QColor(255, 255, 255, 210) if is_active_hub else QColor(110, 100, 90))
        painter.setFont(QFont("Segoe UI", 6, QFont.Weight.DemiBold))
        painter.drawText(QRectF(cx - 50, cy + 1, 100, 16), Qt.AlignmentFlag.AlignCenter, display_hint)

        # 5. Top Category Header & Page Dots
        header_y = cy - self.outer_r - 38
        header_rect = QRectF(cx - 85, header_y, 170, 24)
        painter.setBrush(QBrush(QColor(255, 250, 242, 235)))
        painter.setPen(QPen(QColor(255, 150, 40, 120), 1))
        painter.drawRoundedRect(header_rect, 12, 12)

        painter.setPen(QColor(40, 25, 10))
        painter.setFont(QFont("Segoe UI", 7, QFont.Weight.Black))
        painter.drawText(QRectF(cx - 80, header_y, 110, 24), Qt.AlignmentFlag.AlignCenter, cat["title"])

        # 4 Page Dots
        for d in range(4):
            dot_x = cx + 38 + (d * 7)
            dot_y = header_y + 12
            is_active = (d == self.category_idx)
            painter.setBrush(QBrush(QColor(250, 108, 30) if is_active else QColor(0, 0, 0, 50)))
            painter.setPen(Qt.PenStyle.NoPen)
            r = 3 if is_active else 2
            painter.drawEllipse(QPoint(int(dot_x), int(dot_y)), r, r)
