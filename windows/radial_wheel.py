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
            {"name": "PNG", "id": "png"},
            {"name": "WEBP", "id": "webp"},
            {"name": "HEIC", "id": "heic"},
            {"name": "GIF", "id": "gif"},
            {"name": "AVIF", "id": "avif"},
            {"name": "BMP", "id": "bmp"},
            {"name": "PDF", "id": "pdf"},
            {"name": "DOCX", "id": "docx"},
        ],
        "center": {"name": "TIFF", "id": "tiff"}
    },
    {
        "title": "TOOLS & EDIT",
        "petals": [
            {"name": "COMPRESS", "id": "compress_image"},
            {"name": "METADATA", "id": "metadata"},
            {"name": "EDIT", "id": "edit"},
            {"name": "ANNOTATE", "id": "annotate"},
            {"name": "REMOVE BG", "id": "remove_bg"},
            {"name": "PREVIEW", "id": "preview"},
            {"name": "CROP", "id": "crop"},
            {"name": "REDACT", "id": "redact"},
        ],
        "center": {"name": "ADD BG", "id": "add_bg"}
    },
    {
        "title": "VIDEO & AUDIO",
        "petals": [
            {"name": "MP4", "id": "to_mp4"},
            {"name": "GIF", "id": "video_to_gif"},
            {"name": "MP3", "id": "extract_audio"},
            {"name": "WAV", "id": "to_wav"},
            {"name": "MOV", "id": "to_mov"},
            {"name": "WEBM", "id": "to_webm"},
            {"name": "M4A", "id": "to_m4a"},
            {"name": "COMPRESS", "id": "compress_video"},
        ],
        "center": {"name": "MUTE", "id": "mute_video"}
    },
    {
        "title": "PDF & DOCUMENTS",
        "petals": [
            {"name": "TO PDF", "id": "to_pdf"},
            {"name": "COMPRESS", "id": "compress_pdf"},
            {"name": "SPLIT", "id": "split_pdf"},
            {"name": "MERGE", "id": "merge_pdf"},
            {"name": "OCR TEXT", "id": "ocr_pdf"},
            {"name": "TO IMAGES", "id": "pdf_to_images"},
            {"name": "TO WORD", "id": "pdf_to_docx"},
            {"name": "PRINT", "id": "print_doc"},
        ],
        "center": {"name": "PREVIEW", "id": "preview"}
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

        self.size_val = 390
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

        # 4. Center Pill
        is_center_hovered = (self.hovered_idx == 999)
        center_item = cat["center"]
        pill_rect = QRectF(cx - 49, cy - 23, 98, 46)

        if is_center_hovered:
            grad = QLinearGradient(0, 0, self.size_val, self.size_val)
            grad.setColorAt(0, QColor(250, 108, 30))
            grad.setColorAt(1, QColor(225, 65, 10))
            painter.setBrush(QBrush(grad))
            painter.setPen(QPen(QColor(255, 255, 255, 220), 2))
        else:
            painter.setBrush(QBrush(QColor(255, 245, 230, 245)))
            painter.setPen(QPen(QColor(255, 140, 20, 180), 1))

        painter.drawRoundedRect(pill_rect, 23, 23)
        painter.setPen(QColor(255, 255, 255) if is_center_hovered else QColor(35, 35, 35))
        painter.setFont(QFont("Segoe UI", 9, QFont.Weight.Black))
        painter.drawText(pill_rect, Qt.AlignmentFlag.AlignCenter, center_item["name"])

        # 5. Top Category Header & Page Dots
        header_rect = QRectF(cx - 85, 8, 170, 22)
        painter.setBrush(QBrush(QColor(255, 250, 242, 235)))
        painter.setPen(QPen(QColor(255, 150, 40, 120), 1))
        painter.drawRoundedRect(header_rect, 11, 11)

        painter.setPen(QColor(40, 25, 10))
        painter.setFont(QFont("Segoe UI", 7, QFont.Weight.Black))
        painter.drawText(QRectF(cx - 80, 8, 110, 22), Qt.AlignmentFlag.AlignCenter, cat["title"])

        # 4 Page Dots
        for d in range(4):
            dot_x = cx + 38 + (d * 7)
            dot_y = 19
            is_active = (d == self.category_idx)
            painter.setBrush(QBrush(QColor(250, 108, 30) if is_active else QColor(0, 0, 0, 50)))
            painter.setPen(Qt.PenStyle.NoPen)
            r = 3 if is_active else 2
            painter.drawEllipse(QPoint(int(dot_x), int(dot_y)), r, r)
