#!/bin/sh
apk add --no-cache cups-client ipptool ghostscript imagemagick
echo "Converting PDF to RGB image..."
gs -q -dNOPAUSE -dBATCH -sDEVICE=ppmraw -r300 -sOutputFile=/tmp/testpage.ppm /config/testpage.pdf
echo "Converting to PWG raster..."
convert /tmp/testpage.ppm /tmp/testpage.pwg
echo "Printing test page..."
ipptool -tv -f /tmp/testpage.pwg ipp://192.168.1.173/ipp/print /config/print-job.ipp
