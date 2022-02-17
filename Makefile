SOURCE=src

PREFIX=/usr
CONFDIR=/etc

install: install-config
	mkdir -p ${DESTDIR}${PREFIX}/{lib/xipkg,bin}
	install -m755 ${SOURCE}/*.sh ${DESTDIR}${PREFIX}/lib/xipkg/
	install -m755 ${SOURCE}/xi.sh ${DESTDIR}${PREFIX}/bin/xi


install-config: 
	mkdir -p $(DESTDIR)${CONFDIR}/xipkg.d/
	cp default.conf $(DESTDIR)${CONFDIR}/xipkg.d/
	cp xipkg.conf $(DESTDIR)${CONFDIR}/xipkg.conf
