@echo off
title He Thong Quan Ly Kho Giay Dep
cd /d "%~dp0"

echo Dang khoi dong Database Server...
start /b venv\Scripts\python.exe -m uvicorn main:app --host 127.0.0.1 --port 8000

echo Dang mo Giao Dien...
venv\Scripts\python.exe gui.py

echo Dang tat server...
taskkill /f /im python.exe