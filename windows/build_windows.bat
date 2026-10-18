@echo off
echo ==============================================
echo  Building Dragged for Windows (x64)
echo ==============================================

pip install -r requirements.txt
pyinstaller --noconsole --onefile --name "Dragged" main.py

echo.
echo Build finished! Binary is at: dist\Dragged.exe
echo To generate the installer, run Inno Setup Compiler on installer.iss.
pause
