// Minimal libvosk check: load a model, transcribe a 16 kHz mono 16-bit WAV, print the JSON.
// Built for the iOS simulator and run there by ios/test/smoke_test.sh.
#include <stdio.h>
#include <string.h>
#include "vosk_api.h"

// Position the stream at the first sample: skip the RIFF header and every chunk before "data".
static int seek_to_wav_samples(FILE *wav) {
    char tag[4];
    unsigned int chunk_size;

    fseek(wav, 12, SEEK_SET);  // "RIFF" <size> "WAVE"
    while (fread(tag, 1, 4, wav) == 4 && fread(&chunk_size, 4, 1, wav) == 1) {
        if (memcmp(tag, "data", 4) == 0) {
            return 0;
        }
        fseek(wav, (long)chunk_size, SEEK_CUR);
    }
    return -1;
}

int main(int argc, char **argv) {
    if (argc != 3) {
        fprintf(stderr, "usage: %s <model_dir> <file.wav>\n", argv[0]);
        return 1;
    }
    vosk_set_log_level(-1);

    VoskModel *model = vosk_model_new(argv[1]);
    if (!model) {
        fprintf(stderr, "cannot load model %s\n", argv[1]);
        return 2;
    }
    VoskRecognizer *recognizer = vosk_recognizer_new(model, 16000.0f);
    FILE *wav = fopen(argv[2], "rb");
    if (!wav) {
        fprintf(stderr, "cannot open %s\n", argv[2]);
        return 3;
    }

    char buffer[4000];
    size_t size;
    if (seek_to_wav_samples(wav) != 0) {
        fprintf(stderr, "no data chunk in %s\n", argv[2]);
        return 4;
    }
    while ((size = fread(buffer, 1, sizeof buffer, wav)) > 0) {
        vosk_recognizer_accept_waveform(recognizer, buffer, (int)size);
    }
    printf("%s\n", vosk_recognizer_final_result(recognizer));

    fclose(wav);
    vosk_recognizer_free(recognizer);
    vosk_model_free(model);
    return 0;
}
