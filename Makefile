SOURCE=src

PREFIX=/usr
CONFDIR=/etc

install: install-config
	install -m755 ${SOURCE}/xisync.sh ${DESTDIR}${PREFIX}/bin/xisync


install-config: 
	mkdir -p $(DESTDIR)${CONFDIR}/xipkg.d/
	cp default.conf $(DESTDIR)${CONFDIR}/xipkg.d/
	cp xipkg.conf $(DESTDIR)${CONFDIR}/xipkg.conf
