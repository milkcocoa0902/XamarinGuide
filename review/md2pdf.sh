#!/bin/bash
./md2review ../md/Xamarin.md > main.re
review-pdfmaker config.yml
