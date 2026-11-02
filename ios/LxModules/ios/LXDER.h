//
//  LXDER.h
//  最小的 ASN.1 DER 读写工具。
//
//  用途：Security.framework 的 SecKeyCreateWithData / SecKeyCopyExternalRepresentation
//  只认 PKCS#1（RSAPublicKey / RSAPrivateKey），而 Android 侧 Java 产出的是
//  X.509 SubjectPublicKeyInfo 与 PKCS#8。这里做两种格式的互转，保证与 Android 行为一致。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// 解码 base64，忽略空白与换行（Android 的 Base64.DEFAULT 会插入换行）
NSData *_Nullable LXBase64Decode(NSString *_Nullable string);

/// 编码 base64，不换行（等价 Android 的 Base64.NO_WRAP）
NSString *LXBase64Encode(NSData *_Nullable data);

/// 小写十六进制（等价 Android 侧 SHA1 的输出格式）
NSString *LXHexString(NSData *data);

/// 从 X.509 SPKI 或 PKCS#8 中提取内部的 PKCS#1；如果本身就是 PKCS#1 则原样返回
NSData *LXExtractPKCS1(NSData *der);

/// PKCS#1 RSAPublicKey → X.509 SubjectPublicKeyInfo
NSData *LXPKCS1ToSPKI(NSData *pkcs1);

/// PKCS#1 RSAPrivateKey → PKCS#8 PrivateKeyInfo
NSData *LXPKCS1ToPKCS8(NSData *pkcs1);

NS_ASSUME_NONNULL_END
