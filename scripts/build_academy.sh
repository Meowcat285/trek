#! /bin/bash

# Delete any old academy files and recompile
rm views/academy/*

md5 training/* \
| sed -n 's/MD5 (training\/\([^)]*\).html) = \(.*\)$/cp training\/\1.html views\/academy\/\1_\2.html/p' \
| bash
