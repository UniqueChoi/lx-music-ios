/*
 * 网络相关系统头文件桩（ifaddrs / arpa/inet / net/if / sys/socket）
 * 真实环境下由 Darwin SDK 提供。
 */
#ifndef LX_STUB_NETWORKING_H
#define LX_STUB_NETWORKING_H

#include <stdint.h>
#include <stddef.h>

#define AF_INET 2
#define AF_INET6 30
#define INET_ADDRSTRLEN 16
#define INET6_ADDRSTRLEN 46

struct sockaddr {
  unsigned char sa_len;
  unsigned char sa_family;
  char sa_data[14];
};

struct in_addr {
  uint32_t s_addr;
};

struct sockaddr_in {
  unsigned char sin_len;
  unsigned char sin_family;
  uint16_t sin_port;
  struct in_addr sin_addr;
  char sin_zero[8];
};

struct ifaddrs {
  struct ifaddrs *ifa_next;
  char *ifa_name;
  unsigned int ifa_flags;
  struct sockaddr *ifa_addr;
  struct sockaddr *ifa_netmask;
  struct sockaddr *ifa_dstaddr;
  void *ifa_data;
};

int getifaddrs(struct ifaddrs **ifap);
void freeifaddrs(struct ifaddrs *ifa);

const char *inet_ntop(int af, const void *src, char *dst, size_t size);

#endif /* LX_STUB_NETWORKING_H */
