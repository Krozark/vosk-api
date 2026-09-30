# Overlay on vosk-api/src/Makefile: produce ONE static libvosk.a (vosk objects +
# every Kaldi/OpenFst archive) instead of the shared library the Makefile builds.
# iOS apps link statically. Usage: make -f libvosk_static.mk VOSK_SRC=<vosk-api/src> ... EXT=a
include $(VOSK_SRC)/Makefile

# Same prerequisites as the original rule; this later recipe replaces the --shared one.
$(OUTDIR)/libvosk.a: $(VOSK_SOURCES:%.cc=$(OUTDIR)/%.o) $(LIBS)
	libtool -static -o $@ $^
