# Overlay on src/Makefile: link libvosk as an iOS dynamic library (.dylib) from the
# vosk objects and the static Kaldi/OpenFst archives (the original recipe uses
# --shared, which is not the Darwin way).
# Usage: make -f libvosk_dylib.mk VOSK_SRC=<vosk-api/src> ... EXT=dylib all
include $(VOSK_SRC)/Makefile

# Same prerequisites as the original rule; this later recipe replaces the --shared one.
$(OUTDIR)/libvosk.dylib: $(VOSK_SOURCES:%.cc=$(OUTDIR)/%.o) $(LIBS)
	$(CXX) -dynamiclib -install_name @rpath/libvosk.dylib -o $@ $^ $(LDFLAGS) $(EXTRA_LDFLAGS)
