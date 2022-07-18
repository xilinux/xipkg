SOURCE=src

PREFIX=/usr
CONFDIR=/etc

#install: install-config
#	mkdir -p ${DESTDIR}${PREFIX}/bin
#	mkdir -p ${DESTDIR}${PREFIX}/lib/xipkg
#	install -m755 ${SOURCE}/*.sh ${DESTDIR}${PREFIX}/lib/xipkg/
#	install -m755 ${SOURCE}/xi.sh ${DESTDIR}${PREFIX}/bin/xipkg
#	git describe --always > ${DESTDIR}${PREFIX}/lib/xipkg/VERSION

install-config:
	mkdir -p $(DESTDIR)${CONFDIR}/xipkg.d/
	cp default.conf $(DESTDIR)${CONFDIR}/xipkg.d/
	cp xipkg.conf $(DESTDIR)${CONFDIR}/xipkg.conf


install: install-config
	./build.shmk
	ln -sf xipkg ${DESTDIR}${PREFIX}/bin/xi
