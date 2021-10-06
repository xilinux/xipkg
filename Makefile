XI_BINARY=bin/xi
SOURCE=src

xi: src/xi.py
	mkdir -p bin
	cd src && zip -r xi.zip *
	echo '#!/usr/bin/env python' | cat - src/xi.zip > ${XI_BINARY}
	rm src/xi.zip
	chmod +x ${XI_BINARY}
