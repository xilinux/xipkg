XI_BINARY=bin/xi
SOURCE=src


DESTDIR=

xi: src/xi.py
	mkdir -p bin
	cd src && zip -r xi.zip *
	echo '#!/usr/bin/env python' | cat - src/xi.zip > ${XI_BINARY}
	rm src/xi.zip
	chmod +x ${XI_BINARY}

install: clean xi xipkg.conf default.conf bin/xi
	mkdir -p $(DESTDIR)/etc/xipkg.d/
	cp default.conf $(DESTDIR)/etc/xipkg.d/
	cp xipkg.conf $(DESTDIR)/etc/xipkg.conf
	cp bin/xi $(DESTDIR)/usr/bin/xi

clean:
	rm -rf bin
