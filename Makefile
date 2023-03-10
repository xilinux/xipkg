
PREFIX=/usr
CONFDIR=/etc

.DEFAULT_GOAL := build

build:
	@./build.shmk build

install-config:
	mkdir -p $(DESTDIR)${CONFDIR}/xipkg.d/
	cp default.conf $(DESTDIR)${CONFDIR}/xipkg.d/
	cp xipkg.conf $(DESTDIR)${CONFDIR}/xipkg.conf


install: build install-config
	@./build.shmk install
	ln -sf xi ${DESTDIR}${PREFIX}/bin/xipkg

clean:
	@./build.shmk clean
