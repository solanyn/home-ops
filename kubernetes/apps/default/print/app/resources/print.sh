#!/bin/sh
apk add --no-cache cups-client ipptool ghostscript cups-filters
echo "Converting PDF to PWG raster..."
gs -dNOPAUSE -dBATCH -sDEVICE=pwgraster -sOutputFile=/tmp/testpage.pwg -dProcessColorModel=/DeviceRGB /config/testpage.pdf
echo "Printing test page..."
ipptool -tv -f /tmp/testpage.pwg ipp://192.168.1.173/ipp/print /config/print-job.ipp
