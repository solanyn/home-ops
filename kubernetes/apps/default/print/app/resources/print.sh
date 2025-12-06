#!/bin/sh
apk add --no-cache cups-client ipptool ghostscript
echo "Converting PDF to PWG raster..."
gs -q -dNOPAUSE -dBATCH -sDEVICE=pwgraster -r300 -sColorConversionStrategy=RGB -sOutputFile=/tmp/testpage.pwg /config/testpage.pdf
echo "Printing test page..."
ipptool -tv -f /tmp/testpage.pwg ipp://192.168.1.173/ipp/print /config/print-job.ipp
