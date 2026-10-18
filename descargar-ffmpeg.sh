#!/usr/bin/env bash
# ========================================================
#  MPV Portable - Verificador / Instalador de FFmpeg
# ========================================================

echo "Comprobando disponibilidad de FFmpeg..."
if command -v ffmpeg >/dev/null 2>&1; then
    echo "[OK] FFmpeg ya está instalado en el sistema ($(ffmpeg -version | head -n 1))."
    exit 0
fi

echo "FFmpeg no se encontró en el PATH del sistema."
echo "Instálelo usando el gestor de paquetes de su distribución:"
echo "  - Ubuntu / Debian: sudo apt install ffmpeg"
echo "  - Arch Linux:      sudo pacman -S ffmpeg"
echo "  - Fedora:          sudo dnf install ffmpeg"
echo "  - macOS (Homebrew): brew install ffmpeg"
