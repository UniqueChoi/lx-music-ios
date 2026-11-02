//
//  LxCryptoModule.m
//
//  与 Android 实现的语义对齐要点（差一点就会导致签名错误，全部按 Java 侧核对过）：
//   - AES：入参 data / key / iv 均为 base64；输出 base64；解密输出 UTF-8 字符串
//          iv 为空字符串时走 ECB（Java 的 "AES" 默认是 AES/ECB/PKCS5Padding）
//          iv 不足 16 字节时补零，超出截断（同 AES.java 的 finalIvs 逻辑）
//   - RSA：公钥为 X.509 SPKI、私钥为 PKCS#8，两者都是「去掉 PEM 头尾后的 base64」
//          待加密的明文同样是 base64
//          padding 为 "RSA/ECB/OAEPWithSHA1AndMGF1Padding" 或 "RSA/ECB/NoPadding"
//   - SHA1：输出小写十六进制
//   - 任何异常都返回空字符串（Android 侧就是 catch 后返回 ""），不能抛给 JS
//
//  具体算法实现见 LXCryptoUtil（与自定义源脚本运行时共用）。
//

#import "LxCryptoModule.h"
#import "LXCryptoUtil.h"

@implementation LxCryptoModule

RCT_EXPORT_MODULE(CryptoModule)

+ (BOOL)requiresMainQueueSetup
{
  return NO;
}

#pragma mark - RSA

RCT_EXPORT_METHOD(generateRsaKey:(RCTPromiseResolveBlock)resolve
                        rejecter:(RCTPromiseRejectBlock)reject)
{
  NSString *errorMessage = nil;
  NSDictionary *keyPair = LXGenerateRSAKeyPair(&errorMessage);
  if (keyPair == nil) {
    reject(@"-1", errorMessage ?: @"key generation failed", nil);
    return;
  }
  resolve(keyPair);
}

RCT_EXPORT_METHOD(rsaEncrypt:(NSString *)text
                       key:(NSString *)key
                   padding:(NSString *)padding
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  resolve(LXRSAPublicEncrypt(text, key, padding));
}

RCT_EXPORT_METHOD(rsaDecrypt:(NSString *)text
                       key:(NSString *)key
                   padding:(NSString *)padding
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  resolve(LXRSAPrivateDecrypt(text, key, padding));
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(rsaEncryptSync:(NSString *)text
                                                  key:(NSString *)key
                                              padding:(NSString *)padding)
{
  return LXRSAPublicEncrypt(text, key, padding);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(rsaDecryptSync:(NSString *)text
                                                  key:(NSString *)key
                                              padding:(NSString *)padding)
{
  return LXRSAPrivateDecrypt(text, key, padding);
}

#pragma mark - AES

RCT_EXPORT_METHOD(aesEncrypt:(NSString *)text
                       key:(NSString *)key
                        iv:(NSString *)iv
                      mode:(NSString *)mode
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  resolve(LXAES(text, key, iv, mode, YES));
}

RCT_EXPORT_METHOD(aesDecrypt:(NSString *)text
                       key:(NSString *)key
                        iv:(NSString *)iv
                      mode:(NSString *)mode
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)
{
  resolve(LXAES(text, key, iv, mode, NO));
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(aesEncryptSync:(NSString *)text
                                                  key:(NSString *)key
                                                   iv:(NSString *)iv
                                                 mode:(NSString *)mode)
{
  return LXAES(text, key, iv, mode, YES);
}

RCT_EXPORT_BLOCKING_SYNCHRONOUS_METHOD(aesDecryptSync:(NSString *)text
                                                  key:(NSString *)key
                                                   iv:(NSString *)iv
                                                 mode:(NSString *)mode)
{
  return LXAES(text, key, iv, mode, NO);
}

#pragma mark - SHA1

RCT_EXPORT_METHOD(sha1:(NSString *)input
               resolver:(RCTPromiseResolveBlock)resolve
               rejecter:(RCTPromiseRejectBlock)reject)
{
  if (input == nil) {
    reject(@"SHA1_ERROR", @"input is nil", nil);
    return;
  }
  resolve(LXSha1Hex(input));
}

@end
