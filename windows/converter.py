import os
import sys
import shutil
import subprocess
from pathlib import Path
from PIL import Image

try:
    import pillow_heif
    pillow_heif.register_heif_opener()
    HAS_HEIF = True
except Exception:
    HAS_HEIF = False

try:
    from docx import Document
    from docx.shared import Inches
    HAS_DOCX = True
except Exception:
    HAS_DOCX = False

try:
    import fitz  # PyMuPDF
    HAS_FITZ = True
except Exception:
    HAS_FITZ = False

class ConversionEngine:
    @staticmethod
    def resolve_destination(src_path: str, suffix: str = "", ext: str = None) -> str:
        p = Path(src_path)
        ext = ext or p.suffix.lstrip(".")
        target_name = f"{p.stem}{suffix}.{ext}"
        target_path = p.parent / target_name
        counter = 1
        while target_path.exists():
            target_path = p.parent / f"{p.stem}{suffix}_{counter}.{ext}"
            counter += 1
        return str(target_path)

    @staticmethod
    def convert_image(src_path: str, target_ext: str) -> str:
        target_ext = target_ext.lower().lstrip(".")
        dest_path = ConversionEngine.resolve_destination(src_path, ext=target_ext)

        # Handle DOCX target by embedding image
        if target_ext == "docx":
            if HAS_DOCX:
                doc = Document()
                doc.add_picture(src_path, width=Inches(6.0))
                doc.save(dest_path)
                return dest_path
            else:
                raise RuntimeError("python-docx is required to export to DOCX")

        with Image.open(src_path) as img:
            # Handle RGBA conversion for JPEG/BMP
            if target_ext in ["jpg", "jpeg", "bmp"] and img.mode in ("RGBA", "LA", "P"):
                bg = Image.new("RGB", img.size, (255, 255, 255))
                if img.mode == "RGBA":
                    bg.paste(img, mask=img.split()[3])
                else:
                    bg.paste(img.convert("RGB"))
                bg.save(dest_path)
            elif target_ext == "pdf":
                if img.mode != "RGB":
                    img = img.convert("RGB")
                img.save(dest_path, "PDF", resolution=100.0)
            elif target_ext == "webp":
                img.save(dest_path, "WEBP", quality=85)
            elif target_ext in ["heic", "heif"]:
                if HAS_HEIF:
                    img.save(dest_path, format="HEIF")
                else:
                    raise RuntimeError("pillow-heif is required to export to HEIC")
            elif target_ext == "avif":
                if HAS_HEIF:
                    img.save(dest_path, format="AVIF")
                else:
                    raise RuntimeError("pillow-heif is required to export to AVIF")
            elif target_ext == "tiff":
                img.save(dest_path, "TIFF")
            elif target_ext == "gif":
                img.save(dest_path, "GIF")
            elif target_ext == "png":
                img.save(dest_path, "PNG")
            else:
                img.save(dest_path)
        return dest_path

    @staticmethod
    def execute_tool(src_path: str, tool_id: str) -> str:
        p = Path(src_path)
        ext = p.suffix.lower().lstrip(".")

        # ----------------- Image Tools -----------------
        if tool_id == "compress_image":
            dest = ConversionEngine.resolve_destination(src_path, suffix="_compressed")
            with Image.open(src_path) as img:
                fmt = (img.format or "PNG").upper()
                if fmt in ["JPEG", "JPG"]:
                    img.save(dest, "JPEG", quality=65, optimize=True)
                elif fmt == "PNG":
                    img.save(dest, "PNG", optimize=True)
                elif fmt == "WEBP":
                    img.save(dest, "WEBP", quality=60)
                else:
                    img.save(dest, quality=65)
            return dest

        elif tool_id == "metadata":
            # Strip EXIF / metadata
            dest = ConversionEngine.resolve_destination(src_path, suffix="_clean")
            with Image.open(src_path) as img:
                clean_img = Image.new(img.mode, img.size)
                clean_img.putdata(list(img.getdata()))
                clean_img.save(dest)
            return dest

        elif tool_id in ["edit", "annotate", "crop", "redact", "preview"]:
            # Open with Windows default application
            try:
                os.startfile(src_path)
            except Exception:
                subprocess.Popen(["cmd", "/c", "start", "", src_path], shell=True)
            return src_path

        elif tool_id == "add_bg":
            dest = ConversionEngine.resolve_destination(src_path, suffix="_bg", ext="png")
            with Image.open(src_path) as img:
                bg = Image.new("RGB", img.size, (255, 255, 255))
                if img.mode == "RGBA":
                    bg.paste(img, mask=img.split()[3])
                else:
                    bg.paste(img.convert("RGB"))
                bg.save(dest)
            return dest

        elif tool_id == "remove_bg":
            dest = ConversionEngine.resolve_destination(src_path, suffix="_nobg", ext="png")
            with Image.open(src_path) as img:
                rgba = img.convert("RGBA")
                # Flood/corner-based basic background transparency
                data = rgba.getdata()
                corner = data[0]
                new_data = []
                for item in data:
                    # If pixel color is very close to corner pixel, make transparent
                    diff = abs(item[0] - corner[0]) + abs(item[1] - corner[1]) + abs(item[2] - corner[2])
                    if diff < 30:
                        new_data.append((item[0], item[1], item[2], 0))
                    else:
                        new_data.append(item)
                rgba.putdata(new_data)
                rgba.save(dest)
            return dest

        # ----------------- Video & Audio Tools (FFmpeg) -----------------
        ffmpeg_bin = shutil.which("ffmpeg")

        video_audio_tools = [
            "to_mp4", "video_to_gif", "extract_audio", "to_wav",
            "to_mov", "to_webm", "to_m4a", "compress_video", "mute_video"
        ]

        if tool_id in video_audio_tools:
            if not ffmpeg_bin:
                raise RuntimeError("FFmpeg is required for video/audio conversions. Please install FFmpeg and add it to your Windows PATH.")

            if tool_id == "to_mp4":
                dest = ConversionEngine.resolve_destination(src_path, ext="mp4")
                subprocess.run([ffmpeg_bin, "-y", "-i", src_path, "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", dest], check=True, creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0)
                return dest

            elif tool_id == "video_to_gif":
                dest = ConversionEngine.resolve_destination(src_path, ext="gif")
                subprocess.run([ffmpeg_bin, "-y", "-i", src_path, "-vf", "fps=12,scale=480:-1:flags=lanczos", dest], check=True, creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0)
                return dest

            elif tool_id == "extract_audio":
                dest = ConversionEngine.resolve_destination(src_path, ext="mp3")
                subprocess.run([ffmpeg_bin, "-y", "-i", src_path, "-vn", "-c:a", "libmp3lame", dest], check=True, creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0)
                return dest

            elif tool_id == "to_wav":
                dest = ConversionEngine.resolve_destination(src_path, ext="wav")
                subprocess.run([ffmpeg_bin, "-y", "-i", src_path, "-vn", "-c:a", "pcm_s16le", dest], check=True, creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0)
                return dest

            elif tool_id == "to_mov":
                dest = ConversionEngine.resolve_destination(src_path, ext="mov")
                subprocess.run([ffmpeg_bin, "-y", "-i", src_path, "-c:v", "copy", "-c:a", "copy", dest], check=True, creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0)
                return dest

            elif tool_id == "to_webm":
                dest = ConversionEngine.resolve_destination(src_path, ext="webm")
                subprocess.run([ffmpeg_bin, "-y", "-i", src_path, "-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "30", dest], check=True, creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0)
                return dest

            elif tool_id == "to_m4a":
                dest = ConversionEngine.resolve_destination(src_path, ext="m4a")
                subprocess.run([ffmpeg_bin, "-y", "-i", src_path, "-vn", "-c:a", "aac", dest], check=True, creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0)
                return dest

            elif tool_id == "compress_video":
                dest = ConversionEngine.resolve_destination(src_path, suffix="_compressed", ext="mp4")
                subprocess.run([ffmpeg_bin, "-y", "-i", src_path, "-vcodec", "libx264", "-crf", "28", "-preset", "fast", "-c:a", "aac", dest], check=True, creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0)
                return dest

            elif tool_id == "mute_video":
                dest = ConversionEngine.resolve_destination(src_path, suffix="_muted", ext=ext)
                subprocess.run([ffmpeg_bin, "-y", "-i", src_path, "-c:v", "copy", "-an", dest], check=True, creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0)
                return dest

        # ----------------- PDF & Documents Tools -----------------
        if tool_id == "to_pdf":
            dest = ConversionEngine.resolve_destination(src_path, ext="pdf")
            if ext in ["jpg", "jpeg", "png", "bmp", "webp", "tiff"]:
                return ConversionEngine.convert_image(src_path, "pdf")
            elif ext in ["txt", "md", "csv", "json"]:
                if HAS_FITZ:
                    doc = fitz.open()
                    page = doc.new_page()
                    with open(src_path, "r", encoding="utf-8", errors="ignore") as f:
                        text = f.read()
                    page.insert_text((50, 72), text[:10000], fontsize=11)
                    doc.save(dest)
                    doc.close()
                    return dest
            elif ext == "pdf":
                shutil.copyfile(src_path, dest)
                return dest
            else:
                raise RuntimeError(f"Cannot convert .{ext} directly to PDF")

        elif tool_id == "compress_pdf":
            if not HAS_FITZ:
                raise RuntimeError("PyMuPDF (fitz) is required to compress PDF")
            dest = ConversionEngine.resolve_destination(src_path, suffix="_compressed", ext="pdf")
            doc = fitz.open(src_path)
            doc.save(dest, garbage=4, deflate=True, clean=True)
            doc.close()
            return dest

        elif tool_id == "split_pdf":
            if not HAS_FITZ:
                raise RuntimeError("PyMuPDF (fitz) is required to split PDF")
            dest = ConversionEngine.resolve_destination(src_path, suffix="_page1", ext="pdf")
            doc = fitz.open(src_path)
            new_doc = fitz.open()
            new_doc.insert_pdf(doc, from_page=0, to_page=0)
            new_doc.save(dest)
            new_doc.close()
            doc.close()
            return dest

        elif tool_id == "merge_pdf":
            if not HAS_FITZ:
                raise RuntimeError("PyMuPDF (fitz) is required to merge PDF")
            dest = ConversionEngine.resolve_destination(src_path, suffix="_merged", ext="pdf")
            doc = fitz.open(src_path)
            doc.save(dest)
            doc.close()
            return dest

        elif tool_id == "ocr_pdf":
            if not HAS_FITZ:
                raise RuntimeError("PyMuPDF (fitz) is required for text recognition")
            dest = ConversionEngine.resolve_destination(src_path, suffix="_text", ext="txt")
            doc = fitz.open(src_path)
            text = "\n\n".join([page.get_text() for page in doc])
            doc.close()
            with open(dest, "w", encoding="utf-8") as f:
                f.write(text)
            return dest

        elif tool_id == "pdf_to_images":
            if not HAS_FITZ:
                raise RuntimeError("PyMuPDF (fitz) is required to export PDF to images")
            dest = ConversionEngine.resolve_destination(src_path, suffix="_page1", ext="png")
            doc = fitz.open(src_path)
            page = doc.load_page(0)
            pix = page.get_pixmap(dpi=150)
            pix.save(dest)
            doc.close()
            return dest

        elif tool_id == "pdf_to_docx":
            if not HAS_FITZ:
                raise RuntimeError("PyMuPDF (fitz) is required to extract text from PDF")
            if not HAS_DOCX:
                raise RuntimeError("python-docx is required to export to DOCX")
            dest = ConversionEngine.resolve_destination(src_path, ext="docx")
            doc = fitz.open(src_path)
            text = "\n\n".join([page.get_text() for page in doc])
            doc.close()
            word_doc = Document()
            for para in text.split("\n\n"):
                if para.strip():
                    word_doc.add_paragraph(para.strip())
            word_doc.save(dest)
            return dest

        elif tool_id == "print_doc":
            try:
                os.startfile(src_path, "print")
            except Exception as e:
                raise RuntimeError(f"Failed to send to printer: {e}")
            return src_path

        raise ValueError(f"Unknown tool or format: {tool_id}")
