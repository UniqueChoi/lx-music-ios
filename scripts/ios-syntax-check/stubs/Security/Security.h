/*
 * Security.h —— 语法检查桩（只含本项目用到的 API）
 */
#ifndef LX_STUB_SECURITY_H
#define LX_STUB_SECURITY_H

#import <Foundation/Foundation.h>

typedef struct __SecKey *SecKeyRef;
typedef struct __SecTrust *SecTrustRef;
typedef CFStringRef SecKeyAlgorithm;

extern const CFStringRef kSecAttrKeyType;
extern const CFStringRef kSecAttrKeyClass;
extern const CFStringRef kSecAttrKeySizeInBits;
extern const CFStringRef kSecAttrKeyTypeRSA;
extern const CFStringRef kSecAttrKeyClassPublic;
extern const CFStringRef kSecAttrKeyClassPrivate;

extern const SecKeyAlgorithm kSecKeyAlgorithmRSAEncryptionRaw;
extern const SecKeyAlgorithm kSecKeyAlgorithmRSAEncryptionOAEPSHA1;

SecKeyRef SecKeyCreateWithData(CFDataRef keyData,
                               CFDictionaryRef attributes,
                               CFErrorRef *error);

SecKeyRef SecKeyCreateRandomKey(CFDictionaryRef parameters, CFErrorRef *error);

SecKeyRef SecKeyCopyPublicKey(SecKeyRef privateKey);

CFDataRef SecKeyCopyExternalRepresentation(SecKeyRef key, CFErrorRef *error);

CFDataRef SecKeyCreateEncryptedData(SecKeyRef key,
                                    SecKeyAlgorithm algorithm,
                                    CFDataRef plaintext,
                                    CFErrorRef *error);

CFDataRef SecKeyCreateDecryptedData(SecKeyRef key,
                                    SecKeyAlgorithm algorithm,
                                    CFDataRef ciphertext,
                                    CFErrorRef *error);

size_t SecKeyGetBlockSize(SecKeyRef key);

#endif /* LX_STUB_SECURITY_H */
