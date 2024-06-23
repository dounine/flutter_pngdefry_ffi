#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#if _WIN32
#include <windows.h>
#else
#include <pthread.h>
#include <unistd.h>
#endif

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif
#ifdef __cplusplus
extern "C" {
#endif

    FFI_PLUGIN_EXPORT char* restore_png(
            const char *filePath,
            const char *outputPath
    );

    FFI_PLUGIN_EXPORT int is_iphone_png(const char *filePath);

#ifdef __cplusplus
}
#endif
