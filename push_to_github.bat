@echo off
setlocal
title MAISON AL TEEB POS - GitHub Upload

echo.
echo ==========================================
echo   MAISON AL TEEB POS - GitHub Upload
echo ==========================================
echo.

where git >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Git is not installed.
  echo Install Git from: https://git-scm.com/download/win
  pause
  exit /b 1
)

cd /d "%~dp0"

if not exist ".git" (
  echo [1/5] Initializing Git...
  git init
)

echo [2/5] Setting Git identity...
git config user.name "Mounirettayea"
git config user.email "76437728+Mounirettayea@users.noreply.github.com"

echo [3/5] Setting GitHub remote...
git remote remove origin >nul 2>&1
git remote add origin https://github.com/Mounirettayea/pos.git

echo [4/5] Adding project files...
git add .

echo [5/5] Committing and pushing to main...
git commit -m "Upload MAISON AL TEEB POS V0.6"
git branch -M main
git push -u origin main

if errorlevel 1 (
  echo.
  echo [ERROR] Push failed.
  echo Make sure you are signed in to GitHub and have access to:
  echo https://github.com/Mounirettayea/pos
  echo.
  pause
  exit /b 1
)

echo.
echo ==========================================
echo   SUCCESS - Project uploaded to GitHub
echo ==========================================
echo.
echo Repository:
echo https://github.com/Mounirettayea/pos
echo.
pause
