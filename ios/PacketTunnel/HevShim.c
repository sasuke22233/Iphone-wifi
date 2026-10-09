#include <stdint.h>

// Прямые объявления ABI hev-socks5-tunnel (совместимы с 2.6.x).
extern int hev_socks5_tunnel_main(const char* config_path, int tun_fd);
extern int hev_socks5_tunnel_main_from_file(const char* config_path, int tun_fd);
extern int hev_socks5_tunnel_main_from_str(const unsigned char* config_str,
                                           unsigned int config_len, int tun_fd);
extern void hev_socks5_tunnel_quit(void);
extern void hev_socks5_tunnel_stats(void* tx_packets, void* tx_bytes,
                                    void* rx_packets, void* rx_bytes);

int aura_hev_run(const unsigned char* config_str, unsigned int config_len,
                 int tun_fd) {
  return hev_socks5_tunnel_main_from_str(config_str, config_len, tun_fd);
}

void aura_hev_quit(void) { hev_socks5_tunnel_quit(); }

void aura_hev_stats(uint64_t* tx_packets, uint64_t* tx_bytes,
                    uint64_t* rx_packets, uint64_t* rx_bytes) {
  unsigned long a = 0, b = 0, c = 0, d = 0;
  hev_socks5_tunnel_stats(&a, &b, &c, &d);
  *tx_packets = (uint64_t)a;
  *tx_bytes = (uint64_t)b;
  *rx_packets = (uint64_t)c;
  *rx_bytes = (uint64_t)d;
}
