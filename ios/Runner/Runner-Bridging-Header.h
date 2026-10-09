#ifndef Aura_Bridging_Header_h
#define Aura_Bridging_Header_h

#include <stddef.h>

// Генерируется Flutter-инструментом при сборке.
#if __has_include("GeneratedPluginRegistrant.h")
#import "GeneratedPluginRegistrant.h"
#endif

// ---- libXray (XTLS/libXray, cgo-сборка: python3 build/main.py apple cgo) ----
// Реальный заголовок копируется в Frameworks/include/libXray.h скриптом
// scripts/build_core.sh. Если его нет — используем совместимые объявления.
#if __has_include(<libXray.h>)
#include <libXray.h>
#elif __has_include("libXray.h")
#include "libXray.h"
#else
#ifdef __cplusplus
extern "C" {
#endif
char* CGoInvoke(char* requestJSON);
void CGoFree(char* value);
#ifdef __cplusplus
}
#endif
#endif

#endif /* Aura_Bridging_Header_h */
