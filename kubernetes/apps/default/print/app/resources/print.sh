#!/bin/sh
apk add --no-cache cups-client ipptool cups-filters
echo "Converting PDF to PWG raster..."
pdftoraster 1 1 1 1 1 /config/testpage.pdf > /tmp/testpage.pwg
echo "Printing test page..."
ipptool -tv -f /tmp/testpage.pwg ipp://192.168.1.173/ipp/print /config/print-job.ipp
