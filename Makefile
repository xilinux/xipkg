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
	mkdir -p $(DESTDIR)/usr/bin
	cp default.conf $(DESTDIR)/etc/xipkg.d/
	cp xipkg.conf $(DESTDIR)/etc/xipkg.conf
	rm -f $(DESTDIR)/usr/bin/xi
	cp bin/xi $(DESTDIR)/usr/bin/xipkg
	ln -s /usr/bin/xipkg $(DESTDIR)/usr/bin/xi

clean:
	rm -rf bin
