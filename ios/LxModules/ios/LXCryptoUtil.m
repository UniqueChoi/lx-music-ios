//
//  LXCryptoUtil.m
//

#import "LXCryptoUtil.h"
#import "LXDER.h"

#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonDigest.h>
#import <string.h>

static NSString *const kAESModeECB = @"AES";

#pragma mark - 内部工具

static SecKeyRef LXCreateRSAKey(NSData *der, BOOL isPublic)
{
  if (der.length == 0) return NULL;

  NSDictionary *attrs = @{
    (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
    (__bridge id)kSecAttrKeyClass: isPublic ? (__bridge id)kSecAttrKeyClassPublic
                                            : (__bridge id)kSecAttrKeyClassPrivate,
  };

  NSData *pkcs1 = LXExtractPKCS1(der);
  CFErrorRef error = NULL;
  SecKeyRef key = SecKeyCreateWithData((__bridge CFDataRef)pkcs1,
                                       (__bridge CFDictionaryRef)attrs,
                                       &error);
  if (error) CFRelease(error);

  if (key == NULL && ![pkcs1 isEqualToData:der]) {
    error = NULL;
    key = SecKeyCreateWithData((__bridge CFDataRef)der,
                               (__bridge CFDictionaryRef)attrs,
                               &error);
    if (error) CFRelease(error);
  }
  return key;
}

static SecKeyAlgorithm LXAlgorithmForPadding(NSString *padding)
{
  if (padding != nil && [padding containsString:@"OAEP"]) {
    return kSecKeyAlgorithmRSAEncryptionOAEPSHA1;
  }
  return kSecKeyAlgorithmRSAEncryptionRaw;
}

#pragma mark - 公开实现

NSString *LXAES(NSString *text, NSString *key, NSString *ivString, NSString *mode, BOOL encrypt)
{
  NSData *data = LXBase64Decode(text);
  NSData *keyData = LXBase64Decode(key);

  size_t keyLength = keyData.length;
  if (keyLength != kCCKeySizeAES128 && keyLength != kCCKeySizeAES192 && keyLength != kCCKeySizeAES256) {
    return @"";
  }

  BOOL useECB = (ivString == nil || ivString.length == 0 || [mode isEqualToString:kAESModeECB]);

  uint8_t ivBuffer[kCCBlockSizeAES128];
  memset(ivBuffer, 0, sizeof(ivBuffer));
  if (!useECB) {
    NSData *ivData = LXBase64Decode(ivString);
    size_t ivLen = ivData.length < kCCBlockSizeAES128 ? ivData.length : kCCBlockSizeAES128;
    if (ivLen > 0) memcpy(ivBuffer, ivData.bytes, ivLen);
  }

  // 注意：AES_MODE.ECB_128_NoPadding 的字符串值是 "AES"，
  // 而 Java 的 Cipher.getInstance("AES") 实际是 AES/ECB/PKCS5Padding（带填充）。
  // 这里必须与之保持一致，否则与 Android 产物不兼容。
  CCOptions options = kCCOptionPKCS7Padding;
  if (useECB) options |= kCCOptionECBMode;

  size_t bufferSize = data.length + kCCBlockSizeAES128;
  void *buffer = malloc(bufferSize);
  if (buffer == NULL) return @"";

  size_t moved = 0;
  CCCryptorStatus status = CCCrypt(encrypt ? kCCEncrypt : kCCDecrypt,
                                   kCCAlgorithmAES,
                                   options,
                                   keyData.bytes,
                                   keyLength,
                                   useECB ? NULL : ivBuffer,
                                   data.bytes,
                                   data.length,
                                   buffer,
                                   bufferSize,
                                   &moved);

  if (status != kCCSuccess) {
    free(buffer);
    return @"";
  }

  NSData *output = [NSData dataWithBytesNoCopy:buffer length:moved freeWhenDone:YES];
  if (encrypt) return LXBase64Encode(output);

  NSString *result = [[NSString alloc] initWithData:output encoding:NSUTF8StringEncoding];
  return result ?: @"";
}

NSString *LXRSAPublicEncrypt(NSString *text, NSString *key, NSString *padding)
{
  NSData *keyData = LXBase64Decode(key);
  SecKeyRef secKey = LXCreateRSAKey(keyData, YES);
  if (secKey == NULL) return @"";

  NSData *plain = LXBase64Decode(text);
  CFErrorRef error = NULL;
  NSData *cipher = CFBridgingRelease(SecKeyCreateEncryptedData(secKey,
                                                               LXAlgorithmForPadding(padding),
                                                               (__bridge CFDataRef)plain,
                                                               &error));
  CFRelease(secKey);
  if (error) {
    CFRelease(error);
    return @"";
  }
  return LXBase64Encode(cipher);
}

NSString *LXRSAPrivateDecrypt(NSString *text, NSString *key, NSString *padding)
{
  NSData *keyData = LXBase64Decode(key);
  SecKeyRef secKey = LXCreateRSAKey(keyData, NO);
  if (secKey == NULL) return @"";

  NSData *cipher = LXBase64Decode(text);
  CFErrorRef error = NULL;
  NSData *plain = CFBridgingRelease(SecKeyCreateDecryptedData(secKey,
                                                              LXAlgorithmForPadding(padding),
                                                              (__bridge CFDataRef)cipher,
                                                              &error));
  CFRelease(secKey);
  if (error) {
    CFRelease(error);
    return @"";
  }
  if (plain == nil) return @"";
  NSString *result = [[NSString alloc] initWithData:plain encoding:NSUTF8StringEncoding];
  return result ?: @"";
}

NSString *LXSha1Hex(NSString *input)
{
  NSData *data = [input dataUsingEncoding:NSUTF8StringEncoding];
  uint8_t digest[CC_SHA1_DIGEST_LENGTH];
  CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
  return LXHexString([NSData dataWithBytes:digest length:CC_SHA1_DIGEST_LENGTH]);
}

NSDictionary *LXGenerateRSAKeyPair(NSString **errorMessage)
{
  NSDictionary *attrs = @{
    (__bridge id)kSecAttrKeyType: (__bridge id)kSecAttrKeyTypeRSA,
    (__bridge id)kSecAttrKeySizeInBits: @2048,
  };

  CFErrorRef error = NULL;
  SecKeyRef privateKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attrs, &error);
  if (privateKey == NULL) {
    if (errorMessage) {
      *errorMessage = error ? CFBridgingRelease(CFErrorCopyDescription(error)) : @"key generation failed";
    }
    if (error) CFRelease(error);
    return nil;
  }

  SecKeyRef publicKey = SecKeyCopyPublicKey(privateKey);
  NSData *privatePKCS1 = CFBridgingRelease(SecKeyCopyExternalRepresentation(privateKey, &error));
  if (error) { CFRelease(error); error = NULL; }
  NSData *publicPKCS1 = publicKey
    ? CFBridgingRelease(SecKeyCopyExternalRepresentation(publicKey, &error))
    : nil;
  if (error) { CFRelease(error); error = NULL; }

  CFRelease(privateKey);
  if (publicKey) CFRelease(publicKey);

  if (publicPKCS1 == nil || privatePKCS1 == nil) {
    if (errorMessage) *errorMessage = @"export key failed";
    return nil;
  }

  return @{
    @"publicKey": LXBase64Encode(LXPKCS1ToSPKI(publicPKCS1)),
    @"privateKey": LXBase64Encode(LXPKCS1ToPKCS8(privatePKCS1)),
  };
}
