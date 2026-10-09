#ifndef PacketTunnel_Bridging_Header_h
#define PacketTunnel_Bridging_Header_h

#include <stdint.h>

// ---- libXray (XTLS/libXray, cgo-сборка) ----
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

// ---- hev-socks5-tunnel: стабильные shim-обёртки (HevShim.c) ----
#ifdef __cplusplus
extern "C" {
#endif
int aura_hev_run(const unsigned char* config_str, unsigned int config_len,
                 int tun_fd);
void aura_hev_quit(void);
void aura_hev_stats(uint64_t* tx_packets, uint64_t* tx_bytes,
                    uint64_t* rx_packets, uint64_t* rx_bytes);
#ifdef __cplusplus
}
#endif

#endif /* PacketTunnel_Bridging_Header_h */
