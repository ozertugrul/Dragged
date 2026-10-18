import os
import sys
import shutil
import subprocess
from pathlib import Path
from PIL import Image

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
        target_ext = target_ext.lower()
        dest_path = ConversionEngine.resolve_destination(src_path, ext=target_ext)
        
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
            else:
                img.save(dest_path)
        return dest_path

    @staticmethod
    def execute_tool(src_path: str, tool_id: str) -> str:
        p = Path(src_path)
        
        if tool_id == "compress_image":
            dest = ConversionEngine.resolve_destination(src_path, suffix="_compressed")
            with Image.open(src_path) as img:
                if img.format in ["JPEG", "JPG"]:
                    img.save(dest, quality=65, optimize=True)
                elif img.format == "PNG":
                    img.save(dest, optimize=True)
                else:
                    img.save(dest, quality=75)
            return dest

        elif tool_id == "metadata":
            # Strip EXIF / metadata
            dest = ConversionEngine.resolve_destination(src_path, suffix="_clean")
            with Image.open(src_path) as img:
                data = list(img.getdata())
                image_without_exif = Image.new(img.mode, img.size)
                image_without_exif.putdata(data)
                image_without_exif.save(dest)
            return dest

        elif tool_id in ["edit", "annotate", "crop", "redact"]:
            # Open in Windows default photo editor / MS Paint
            os.startfile(src_path)
            return src_path

        elif tool_id == "preview":
            os.startfile(src_path)
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
                img.convert("RGBA").save(dest)
            return dest

        # Video & Audio Tools (FFmpeg)
        elif tool_id == "to_mp4":
            dest = ConversionEngine.resolve_destination(src_path, ext="mp4")
            subprocess.run(["ffmpeg", "-y", "-i", src_path, "-c:v", "libx264", "-c:a", "aac", dest], check=True)
            return dest

        elif tool_id == "video_to_gif":
            dest = ConversionEngine.resolve_destination(src_path, ext="gif")
            subprocess.run(["ffmpeg", "-y", "-i", src_path, "-vf", "fps=12,scale=480:-1:flags=lanczos", dest], check=True)
            return dest

        elif tool_id == "extract_audio":
            dest = ConversionEngine.resolve_destination(src_path, ext="mp3")
            subprocess.run(["ffmpeg", "-y", "-i", src_path, "-vn", "-c:a", "libmp3lame", dest], check=True)
            return dest

        elif tool_id == "mute_video":
            dest = ConversionEngine.resolve_destination(src_path, suffix="_muted", ext=p.suffix.lstrip("."))
            subprocess.run(["ffmpeg", "-y", "-i", src_path, "-c:v", "copy", "-an", dest], check=True)
            return dest

        # PDF Tools
        elif tool_id == "pdf_to_images":
            import fitz
            doc = fitz.open(src_path)
            dest = ConversionEngine.resolve_destination(src_path, suffix="_page1", ext="png")
            page = doc.load_page(0)
            pix = page.get_pixmap()
            pix.save(dest)
            return dest

        elif tool_id == "ocr_pdf":
            import fitz
            doc = fitz.open(src_path)
            dest = ConversionEngine.resolve_destination(src_path, suffix="_text", ext="txt")
            text = "\n\n".join([page.get_text() for page in doc])
            with open(dest, "w", encoding="utf-8") as f:
                f.write(text)
            return dest

        raise ValueError(f"Unknown tool or format: {tool_id}")
