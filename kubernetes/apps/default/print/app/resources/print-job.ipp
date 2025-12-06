{
  NAME "Print test page"
  OPERATION Print-Job
  GROUP operation-attributes-tag
  ATTR charset attributes-charset utf-8
  ATTR language attributes-natural-language en
  ATTR uri printer-uri ipp://192.168.1.173/ipp/print
  ATTR name requesting-user-name root
  ATTR mimeMediaType document-format image/pwg-raster
  GROUP job-attributes-tag
  ATTR keyword print-color-mode color
  FILE $filename
}
