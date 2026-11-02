//
//  LXCryptoUtil.h
//  AES / RSA / SHA1 的共用实现。
//
//  被两处复用：
//   1. LxCryptoModule  —— 供 src/utils/nativeModules/crypto.ts 调用
//   2. LxUserApiModule —— 供自定义源脚本的 __lx_native_call__utils_* 调用
//
//  语义与 Android 的 crypto/AES.java、crypto/RSA.java 严格对齐。
//

#import <Foundation/Foundation.h>
#import <Security/Security.h>

NS_ASSUME_NONNULL_BEGIN

/// AES 加解密。text/key/iv 均为 base64；iv 为空则 ECB。
/// 失败返回空字符串（与 Java 侧 catch 后返回 "" 的行为一致）。
NSString *LXAES(NSString *text, NSString *key, NSString *_Nullable iv, NSString *mode, BOOL encrypt);

/// RSA 加密。text 为 base64 明文，key 为去掉 PEM 头的 base64 公钥（X.509 SPKI）。
NSString *LXRSAPublicEncrypt(NSString *text, NSString *key, NSString *padding);

/// RSA 解密。key 为 base64 私钥（PKCS#8）。
NSString *LXRSAPrivateDecrypt(NSString *text, NSString *key, NSString *padding);

/// SHA1，返回小写十六进制。
NSString *LXSha1Hex(NSString *input);

/// 生成 2048 位 RSA 密钥对，返回与 Java 侧同格式的 base64（SPKI / PKCS#8）。
NSDictionary *_Nullable LXGenerateRSAKeyPair(NSString *_Nullable *_Nullable errorMessage);

NS_ASSUME_NONNULL_END
