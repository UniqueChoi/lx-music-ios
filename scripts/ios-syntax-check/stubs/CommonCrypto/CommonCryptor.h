/*
 * CommonCrypto 桩（CommonCryptor.h）
 */
#ifndef LX_STUB_COMMONCRYPTO_H
#define LX_STUB_COMMONCRYPTO_H

#include <stddef.h>
#include <stdint.h>

typedef uint32_t CCOperation;
typedef int32_t CCCryptorStatus;
typedef uint32_t CCOptions;
typedef uint32_t CCMode;
typedef uint32_t CCAlgorithm;
typedef uint32_t CCHmacAlgorithm;
typedef uint32_t CC_LONG;

enum {
  kCCSuccess = 0,
  kCCParamError = -4300,
  kCCBufferTooSmall = -4301,
  kCCMemoryFailure = -4302,
  kCCAlignmentError = -4303,
  kCCDecodeError = -4304,
  kCCUnimplemented = -4305
};

enum {
  kCCAlgorithmAES128 = 0,
  kCCAlgorithmAES = 0,
  kCCAlgorithmDES = 1,
  kCCAlgorithm3DES = 2
};

enum {
  kCCOptionPKCS7Padding = 0x0001,
  kCCOptionECBMode = 0x0002
};

enum {
  kCCEncrypt = 0,
  kCCDecrypt = 1
};

enum {
  kCCKeySizeAES128 = 16,
  kCCKeySizeAES192 = 24,
  kCCKeySizeAES256 = 32,
  kCCBlockSizeAES128 = 16
};

enum {
  CC_MD5_DIGEST_LENGTH = 16,
  CC_SHA1_DIGEST_LENGTH = 20,
  CC_SHA256_DIGEST_LENGTH = 32
};

CCCryptorStatus CCCrypt(CCOperation op,
                        CCAlgorithm alg,
                        CCOptions options,
                        const void *key,
                        size_t keyLength,
                        const void *iv,
                        const void *dataIn,
                        size_t dataInLength,
                        void *dataOut,
                        size_t dataOutAvailable,
                        size_t *dataOutMoved);

unsigned char *CC_MD5(const void *data, CC_LONG len, unsigned char *md);
unsigned char *CC_SHA1(const void *data, CC_LONG len, unsigned char *md);
unsigned char *CC_SHA256(const void *data, CC_LONG len, unsigned char *md);

#endif /* LX_STUB_COMMONCRYPTO_H */
