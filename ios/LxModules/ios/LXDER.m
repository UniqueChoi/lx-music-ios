//
//  LXDER.m
//

#import "LXDER.h"

// rsaEncryption: OID 1.2.840.113549.1.1.1 + NULL
// AlgorithmIdentifier SEQUENCE = 30 0D 06 09 2A 86 48 86 F7 0D 01 01 01 05 00
static const uint8_t kLXRSAlgorithmID[] = {
  0x30, 0x0D,
  0x06, 0x09, 0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01,
  0x05, 0x00,
};

NSData *_Nullable LXBase64Decode(NSString *_Nullable string) {
  if (string == nil || string.length == 0) return [NSData data];
  // 去掉 PEM 头尾可能残留的空白字符，Android 的 Base64.decode 本身就是宽松的
  NSMutableString *cleaned = [string mutableCopy];
  [cleaned replaceOccurrencesOfString:@"\r" withString:@"" options:0 range:NSMakeRange(0, cleaned.length)];
  [cleaned replaceOccurrencesOfString:@"\n" withString:@"" options:0 range:NSMakeRange(0, cleaned.length)];
  [cleaned replaceOccurrencesOfString:@" " withString:@"" options:0 range:NSMakeRange(0, cleaned.length)];
  [cleaned replaceOccurrencesOfString:@"\t" withString:@"" options:0 range:NSMakeRange(0, cleaned.length)];
  return [[NSData alloc] initWithBase64EncodedString:cleaned
                                             options:NSDataBase64DecodingIgnoreUnknownCharacters];
}

NSString *LXBase64Encode(NSData *_Nullable data) {
  if (data == nil) return @"";
  return [data base64EncodedStringWithOptions:0];
}

NSString *LXHexString(NSData *data) {
  const uint8_t *bytes = (const uint8_t *)data.bytes;
  NSUInteger len = data.length;
  NSMutableString *hex = [NSMutableString stringWithCapacity:len * 2];
  for (NSUInteger i = 0; i < len; i++) {
    [hex appendFormat:@"%02x", bytes[i]];
  }
  return hex;
}

#pragma mark - DER 基础

static NSData *LXDEREncodeLength(NSUInteger len) {
  uint8_t buf[5];
  if (len < 0x80) {
    buf[0] = (uint8_t)len;
    return [NSData dataWithBytes:buf length:1];
  }
  uint8_t tmp[4];
  int n = 0;
  NSUInteger v = len;
  while (v > 0 && n < 4) {
    tmp[n++] = (uint8_t)(v & 0xFF);
    v >>= 8;
  }
  buf[0] = (uint8_t)(0x80 | n);
  for (int i = 0; i < n; i++) {
    buf[1 + i] = tmp[n - 1 - i];
  }
  return [NSData dataWithBytes:buf length:(NSUInteger)(1 + n)];
}

static NSData *LXDERWrap(uint8_t tag, NSData *content) {
  NSMutableData *out = [NSMutableData data];
  uint8_t t = tag;
  [out appendBytes:&t length:1];
  [out appendData:LXDEREncodeLength(content.length)];
  [out appendData:content];
  return out;
}

/// 读取一个 TLV，成功时返回 YES 并回填 tag / 内容起始偏移 / 内容长度
static BOOL LXDERReadTLV(const uint8_t *bytes,
                         NSUInteger total,
                         NSUInteger *offset,
                         uint8_t *outTag,
                         NSUInteger *outStart,
                         NSUInteger *outLen) {
  NSUInteger i = *offset;
  if (i + 2 > total) return NO;

  uint8_t tag = bytes[i++];
  uint8_t first = bytes[i++];
  NSUInteger len = 0;

  if (first & 0x80) {
    NSUInteger n = (NSUInteger)(first & 0x7F);
    if (n == 0 || n > 4 || i + n > total) return NO;
    for (NSUInteger k = 0; k < n; k++) {
      len = (len << 8) | bytes[i++];
    }
  } else {
    len = first;
  }

  if (i + len > total) return NO;

  if (outTag) *outTag = tag;
  if (outStart) *outStart = i;
  if (outLen) *outLen = len;
  *offset = i + len;
  return YES;
}

#pragma mark - 格式互转

NSData *LXExtractPKCS1(NSData *der) {
  if (der.length < 2) return der;

  const uint8_t *bytes = (const uint8_t *)der.bytes;
  NSUInteger total = der.length;
  NSUInteger offset = 0;
  uint8_t outerTag = 0;
  NSUInteger outerStart = 0;
  NSUInteger outerLen = 0;

  if (!LXDERReadTLV(bytes, total, &offset, &outerTag, &outerStart, &outerLen)) return der;
  if (outerTag != 0x30) return der;

  // 遍历顶层子元素，寻找 BIT STRING(SPKI) 或 OCTET STRING(PKCS#8)
  NSUInteger childOffset = outerStart;
  NSUInteger childEnd = outerStart + outerLen;
  while (childOffset < childEnd) {
    uint8_t childTag = 0;
    NSUInteger childStart = 0;
    NSUInteger childLen = 0;
    NSUInteger next = childOffset;
    if (!LXDERReadTLV(bytes, total, &next, &childTag, &childStart, &childLen)) return der;

    if (childTag == 0x03) {
      // BIT STRING：首字节为未使用位数，正常为 0x00
      if (childLen < 1) return der;
      NSUInteger innerStart = childStart + 1;
      NSUInteger innerLen = childLen - 1;
      if (innerStart + innerLen > total) return der;
      return [NSData dataWithBytes:(bytes + innerStart) length:innerLen];
    }
    if (childTag == 0x04) {
      // OCTET STRING：内容即 PKCS#1
      if (childStart + childLen > total) return der;
      return [NSData dataWithBytes:(bytes + childStart) length:childLen];
    }

    childOffset = next;
  }

  return der;
}

NSData *LXPKCS1ToSPKI(NSData *pkcs1) {
  if (pkcs1.length == 0) return pkcs1;

  // SPKI = SEQUENCE { AlgorithmIdentifier, BIT STRING { 0x00, PKCS#1 } }
  NSData *algorithm = [NSData dataWithBytes:kLXRSAlgorithmID length:sizeof(kLXRSAlgorithmID)];

  NSMutableData *bitStringContent = [NSMutableData dataWithCapacity:pkcs1.length + 1];
  uint8_t unusedBits = 0x00;
  [bitStringContent appendBytes:&unusedBits length:1];
  [bitStringContent appendData:pkcs1];
  NSData *bitString = LXDERWrap(0x03, bitStringContent);

  NSMutableData *body = [NSMutableData dataWithCapacity:algorithm.length + bitString.length];
  [body appendData:algorithm];
  [body appendData:bitString];

  return LXDERWrap(0x30, body);
}

NSData *LXPKCS1ToPKCS8(NSData *pkcs1) {
  if (pkcs1.length == 0) return pkcs1;

  // PKCS#8 = SEQUENCE { INTEGER 0, AlgorithmIdentifier, OCTET STRING { PKCS#1 } }
  NSData *algorithm = [NSData dataWithBytes:kLXRSAlgorithmID length:sizeof(kLXRSAlgorithmID)];

  uint8_t versionBytes[] = {0x02, 0x01, 0x00};
  NSData *version = [NSData dataWithBytes:versionBytes length:sizeof(versionBytes)];
  NSData *octetString = LXDERWrap(0x04, pkcs1);

  NSMutableData *body = [NSMutableData dataWithCapacity:version.length + algorithm.length + octetString.length];
  [body appendData:version];
  [body appendData:algorithm];
  [body appendData:octetString];

  return LXDERWrap(0x30, body);
}
