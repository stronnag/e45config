VALAC=valac

GLIB_TARGET=2.46
OPTS += -X -O2 -X -s --thread --target-glib=$(GLIB_TARGET)
PKGS= --pkg gtk+-3.0 --pkg posix

APP=e45config

all: $(APP)

e45.resources.c: e45.resources.xml e45ui.ui
	glib-compile-resources --generate-source  e45.resources.xml

e45config: e45config.vala e45.resources.c cserial.c
	$(VALAC) $(OPTS) $(PKGS) -o $@  $^

clean:
	rm -f $(APP) *~ *.vala.c e45.resources.c
