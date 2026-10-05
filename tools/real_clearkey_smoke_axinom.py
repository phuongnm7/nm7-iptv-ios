#!/usr/bin/env python3
import base64
import re
import struct
import sys
import urllib.request
import xml.etree.ElementTree as ET
from urllib.parse import urljoin

MPD_URL = "https://media.axprod.net/TestVectors/v7-MultiDRM-SingleKey/Manifest_1080p_ClearKey.mpd"
KID_B64 = "nrQFDeRLSAKTLifXUIPiZg"
KEY_B64 = "FmY0xnWCPCNaSpRG-tUuTQ"
UA = "NM7-IPTV-iOS/1.0.71-DRM-SMOKE"

def get(url, headers=None):
    req = urllib.request.Request(url, method="GET", headers=headers or {"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read(), dict(r.headers), r.geturl(), getattr(r, "status", 200)

def local(tag):
    return tag.rsplit("}", 1)[-1]

def child(node, name):
    for x in list(node or []):
        if local(x.tag) == name:
            return x
    return None

def children(node, name):
    return [x for x in list(node or []) if local(x.tag) == name]

def find_video_adaptation(period):
    for adaptation in children(period, "AdaptationSet"):
        mime = (adaptation.attrib.get("mimeType") or "").lower()
        ctype = (adaptation.attrib.get("contentType") or "").lower()
        if ctype == "video" or mime.startswith("video/"):
            return adaptation
        if any((r.attrib.get("mimeType") or "").lower().startswith("video/") for r in children(adaptation, "Representation")):
            return adaptation
    return None

def substitute(template, number, time_value, rep_id, bandwidth):
    values = {
        "Number": str(number),
        "Time": str(time_value),
        "RepresentationID": rep_id,
        "Bandwidth": str(bandwidth),
    }
    def repl(m):
        key, width = m.group(1), m.group(2)
        v = values[key]
        return v.zfill(int(width)) if width and v.isdigit() else v
    return re.sub(r"\\$(Number|Time|RepresentationID|Bandwidth)(?:%0(\\d+)d)?\\$", repl, template)

def boxes(data, start=0, end=None):
    end = len(data) if end is None else min(end, len(data))
    p = start
    while p + 8 <= end:
        size32 = struct.unpack_from(">I", data, p)[0]
        typ = data[p+4:p+8].decode("ascii", "replace")
        hdr = 8
        if size32 == 1:
            if p + 16 > end:
                return
            size = struct.unpack_from(">Q", data, p+8)[0]
            hdr = 16
        elif size32 == 0:
            size = end - p
        else:
            size = size32
        if size < hdr or p + size > end:
            return
        yield p, int(size), typ, hdr
        p += int(size)

def find_nested(data, wanted, start=0, end=None):
    out = []
    for p, size, typ, hdr in boxes(data, start, end):
        if typ == wanted:
            out.append((p, size, typ, hdr))
        if typ in {"moov","trak","mdia","minf","stbl","stsd","mvex","moof","traf","schi","sinf"}:
            out.extend(find_nested(data, wanted, p+hdr, p+size))
    return out

def u32(data, off):
    return struct.unpack_from(">I", data, off)[0]

def i32(data, off):
    return struct.unpack_from(">i", data, off)[0]

def tenc_info(init):
    for p, size, typ, hdr in find_nested(init, "tenc"):
        base = p + hdr
        if base + 20 > p + size:
            continue
        version = init[base]
        pattern = init[base+1]
        protected = init[base+2]
        iv_size = init[base+3]
        kid = init[base+4:base+20]
        crypt = ((pattern >> 4) & 0xF) if version >= 1 else 0
        skip = (pattern & 0xF) if version >= 1 else 0
        return version, protected, iv_size, kid, crypt, skip
    raise RuntimeError("init không có tenc")

def scheme_info(init):
    for p, size, typ, hdr in find_nested(init, "schm"):
        base = p + hdr
        if base + 8 <= p + size:
            return init[base+4:base+8].decode("ascii", "replace").lower()
    return "cenc"

def trex_defaults(init):
    result = {}
    for p, size, typ, hdr in find_nested(init, "trex"):
        base = p + hdr
        if base + 20 <= p + size:
            track_id = u32(init, base+4)
            default_size = u32(init, base+16)
            result[track_id] = default_size
    return result

def parse_senc(fragment, senc, default_iv_size):
    p, size, _, hdr = senc
    flags = int.from_bytes(fragment[p+hdr+1:p+hdr+4], "big")
    cur = p + hdr + 4
    count = u32(fragment, cur)
    cur += 4
    iv_size = default_iv_size
    if flags & 0x1:
        if cur + 20 > p + size:
            raise RuntimeError("senc override fields truncated")
        cur += 3
        iv_size = fragment[cur]
        cur += 1
        cur += 16
    entries = []
    for _ in range(count):
        if iv_size:
            if cur + iv_size > p + size:
                raise RuntimeError("senc IV truncated")
            iv = fragment[cur:cur+iv_size]
            cur += iv_size
        else:
            raise RuntimeError("constant-IV senc sample path requires tenc constant IV")
        subs = None
        if flags & 0x2:
            if cur + 2 > p + size:
                raise RuntimeError("senc subsample count truncated")
            n = int.from_bytes(fragment[cur:cur+2], "big")
            cur += 2
            subs = []
            for _ in range(n):
                if cur + 6 > p + size:
                    raise RuntimeError("senc subsample truncated")
                clear = int.from_bytes(fragment[cur:cur+2], "big")
                encrypted = u32(fragment, cur+2)
                cur += 6
                subs.append((clear, encrypted))
        entries.append((iv, subs))
    return entries

def parse_tfhd(data, box):
    p, size, _, hdr = box
    flags = int.from_bytes(data[p+hdr+1:p+hdr+4], "big")
    cur = p + hdr + 4
    track_id = u32(data, cur)
    cur += 4
    base = None
    if flags & 0x1:
        base = struct.unpack_from(">Q", data, cur)[0]
        cur += 8
    if flags & 0x2:
        cur += 4
    default_size = None
    if flags & 0x8:
        cur += 4
    if flags & 0x10:
        default_size = u32(data, cur)
        cur += 4
    return flags, track_id, base, default_size

def parse_trun(data, box, base, fallback, default_size):
    p, size, _, hdr = box
    flags = int.from_bytes(data[p+hdr+1:p+hdr+4], "big")
    cur = p + hdr + 4
    count = u32(data, cur)
    cur += 4
    data_offset = fallback
    if flags & 0x1:
        data_offset = base + i32(data, cur)
        cur += 4
    if flags & 0x4:
        cur += 4
    sizes = []
    for _ in range(count):
        if flags & 0x100:
            cur += 4
        size_value = default_size
        if flags & 0x200:
            size_value = u32(data, cur)
            cur += 4
        if flags & 0x400:
            cur += 4
        if flags & 0x800:
            cur += 4
        if size_value is None:
            raise RuntimeError("sample size is absent from trun/tfhd/trex")
        sizes.append(int(size_value))
    return data_offset, sizes

def decrypt_sample(sample, key, iv, subs, scheme, crypt_block, skip_block):
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    if scheme in ("cenc", "cbc1"):
        counter = iv + (b"\\0" * 8) if len(iv) == 8 else iv
        if len(counter) != 16:
            raise RuntimeError("invalid CTR IV length")
        cryptor = Cipher(algorithms.AES(key), modes.CTR(counter)).encryptor()
        out = bytearray(sample)
        if subs is None:
            out[:] = cryptor.update(bytes(out))
        else:
            pos = 0
            for clear, encrypted in subs:
                pos += clear
                end = pos + encrypted
                out[pos:end] = cryptor.update(bytes(out[pos:end]))
                pos = end
        cryptor.finalize()
        return bytes(out)
    if scheme == "cbcs":
        out = bytearray(sample)
        cryptor = None
        pos = 0
        block = 16
        pattern = crypt_block + skip_block
        while pos + block <= len(out):
            slot = (pos // block) % max(1, pattern)
            if cryptor is None and slot < crypt_block:
                cryptor = Cipher(algorithms.AES(key), modes.CBC(iv)).decryptor()
            if slot < crypt_block:
                out[pos:pos+block] = cryptor.update(bytes(out[pos:pos+block]))
            pos += block
        if cryptor is not None:
            cryptor.finalize()
        return bytes(out)
    raise RuntimeError(f"unsupported scheme {scheme}")

def main():
    kid = b64url_decode = base64.urlsafe_b64decode(KID_B64 + "=" * ((4 - len(KID_B64) % 4) % 4))
    key = base64.urlsafe_b64decode(KEY_B64 + "=" * ((4 - len(KEY_B64) % 4) % 4))
    mpd_bytes, _, mpd_final, _ = get(MPD_URL)
    print(f"REAL MPD: {mpd_final} bytes={len(mpd_bytes)}")
    root = ET.fromstring(mpd_bytes)
    period = children(root, "Period")[0]
    adaptation = find_video_adaptation(period)
    if adaptation is None:
        raise RuntimeError("no video AdaptationSet")
    reps = children(adaptation, "Representation")
    if not reps:
        raise RuntimeError("no video Representation")
    rep = reps[0]
    rep_id = rep.attrib.get("id", "")
    bandwidth = int(rep.attrib.get("bandwidth", "0"))

    base_url = mpd_final
    for node in (root, period, adaptation, rep):
        b = child(node, "BaseURL")
        if b is not None and b.text:
            base_url = urljoin(base_url, b.text.strip())

    template = child(rep, "SegmentTemplate") or child(adaptation, "SegmentTemplate")
    if template is None:
        raise RuntimeError("real sample has no SegmentTemplate")
    start_number = int(template.attrib.get("startNumber", "1"))
    timeline = child(template, "SegmentTimeline")
    first_s = child(timeline, "S")
    time_value = int(first_s.attrib.get("t", "0")) if first_s is not None else 0
    init_ref = substitute(template.attrib.get("initialization", ""), start_number, time_value, rep_id, bandwidth)
    media_ref = substitute(template.attrib.get("media", ""), start_number, time_value, rep_id, bandwidth)
    if not init_ref or not media_ref:
        raise RuntimeError("SegmentTemplate is missing initialization/media")
    init_url = urljoin(base_url, init_ref)
    media_url = urljoin(base_url, media_ref)

    init, _, init_final, _ = get(init_url)
    media, _, media_final, _ = get(media_url)
    print(f"REAL SEGMENTS: init={init_final} bytes={len(init)} media={media_final} bytes={len(media)}")

    version, protected, iv_size, tenc_kid, crypt, skip = tenc_info(init)
    scheme = scheme_info(init)
    if protected != 1:
        raise RuntimeError("tenc isProtected != 1")
    if tenc_kid != kid:
        raise RuntimeError(f"KID mismatch expected={kid.hex()} actual={tenc_kid.hex()}")
    print(f"DRM: scheme={scheme} tencVersion={version} ivSize={iv_size} crypt={crypt} skip={skip} KID={tenc_kid.hex()}")

    moof = next((x for x in boxes(media) if x[2] == "moof"), None)
    if not moof:
        raise RuntimeError("media has no moof")
    mp, ms, _, mh = moof
    traf = next((x for x in boxes(media, mp+mh, mp+ms) if x[2] == "traf"), None)
    if not traf:
        raise RuntimeError("media moof has no traf")
    tp, ts, _, th = traf
    traf_children = list(boxes(media, tp+th, tp+ts))
    tfhd = next((x for x in traf_children if x[2] == "tfhd"), None)
    trun = next((x for x in traf_children if x[2] == "trun"), None)
    senc = next((x for x in traf_children if x[2] == "senc"), None)
    if not tfhd or not trun:
        raise RuntimeError("media traf missing tfhd/trun")
    if not senc:
        raise RuntimeError("media traf missing senc; CI smoke intentionally requires explicit senc")
    flags, track_id, tfhd_base, tfhd_size = parse_tfhd(media, tfhd)
    base = tfhd_base if tfhd_base is not None else mp
    fallback = mp + ms
    trex = trex_defaults(init)
    default_size = tfhd_size if tfhd_size is not None else trex.get(track_id)
    data_offset, sizes = parse_trun(media, trun, base, fallback, default_size)
    entries = parse_senc(media, senc, iv_size)
    if len(entries) != len(sizes):
        raise RuntimeError(f"senc/trun sample count mismatch {len(entries)} != {len(sizes)}")
    local_offset = data_offset
    if local_offset < 0 or local_offset >= len(media):
        raise RuntimeError(f"data offset outside media: {local_offset}")
    if len(sizes) != 1:
        print(f"INFO: decrypting first of {len(sizes)} samples")
    size = sizes[0]
    if local_offset + size > len(media):
        raise RuntimeError(f"sample range invalid offset={local_offset} size={size} bytes={len(media)}")
    iv, subs = entries[0]
    decrypted = decrypt_sample(media[local_offset:local_offset+size], key, iv, subs, scheme, crypt, skip)
    if not decrypted:
        raise RuntimeError("decrypted sample empty")
    nal_len = int.from_bytes(decrypted[:4], "big") if len(decrypted) >= 4 else 0
    nal_type = decrypted[4] & 0x1F if len(decrypted) >= 5 else 0
    if not (0 < nal_len <= len(decrypted) - 4 and 1 <= nal_type <= 31):
        raise RuntimeError(f"decrypted bytes do not look like AVC NAL: {decrypted[:16].hex()}")
    print(
        f"REAL-CLEARKEY-SMOKE PASS: track={track_id} scheme={scheme} "
        f"sampleSize={size} IV={iv.hex()} decryptedHead={decrypted[:16].hex()}"
    )

if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"REAL-CLEARKEY-SMOKE FAIL: {exc}", file=sys.stderr)
        raise
