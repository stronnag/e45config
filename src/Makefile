VALAC=valac

APP=e45config

all: $(APP)

e45.resources.c: e45.resources.xml e45ui.ui
	glib-compile-resources --generate-source  e45.resources.xml

e45config: e45config.vala e45.resources.c cserial.c
	$(VALAC) --pkg gtk+-3.0 --pkg posix -o $@  $^
