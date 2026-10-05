#!/usr/bin/env python3
import base64, re, struct, sys, urllib.request, xml.etree.ElementTree as ET
from urllib.parse import urljoin

UA = "NM7-IPTV-iOS/1.0.71-DRM-SMOKE"
CANDIDATES = [
    {
        "mpd": "https://yt-dash-mse-test.commondatastorage.googleapis.com/media/car_cenc-20120827-manifest.mpd",
        "kid": "60061e017e477e877e57d00d1ed00d1e",
        "key": "1a8a2095e4deb2d29ec816ac7bae2082",
        "name": "Car ClearKey SegmentBase",
    },
    {
        "mpd": "https://media.axprod.net/TestVectors/v7-MultiDRM-SingleKey/Manifest_1080p_ClearKey.mpd",
        "kid": "f3d73b3a9b89462ebf7911004ea3b3b9",
        "key": "2e547a81ff90aa02648cb9e3f79e7339",
        "name": "NM7 On Sports key material / Axinom fallback",
        "alternate_key": ("nrQFDeRLSAKTLifXUIPiZg", "FmY0xnWCPCNaSpRG-tUuTQ"),
    },
]

def get(url, headers=None, byte_range=None):
    h = {"User-Agent": UA}
    if headers: h.update(headers)
    req = urllib.request.Request(url, headers=h)
    if byte_range is not None:
        req.add_header("Range", f"bytes={byte_range[0]}-{byte_range[1]}")
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read(), dict(r.headers), r.geturl(), getattr(r, "status", 200)

def local(tag): return tag.rsplit("}", 1)[-1]
def child(node, name):
    for x in list(node) if node is not None else []:
        if local(x.tag) == name: return x
    return None
def children(node, name): return [x for x in (list(node) if node is not None else []) if local(x.tag) == name]

def boxes(data, start=0, end=None):
    end = len(data) if end is None else min(end, len(data))
    p = start
    while p + 8 <= end:
        size32 = struct.unpack_from(">I", data, p)[0]
        typ = data[p+4:p+8].decode("ascii", "replace")
        hdr = 8
        if size32 == 1:
            if p + 16 > end: return
            size = struct.unpack_from(">Q", data, p+8)[0]; hdr = 16
        elif size32 == 0:
            size = end - p
        else:
            size = size32
        if size < hdr or p + size > end: return
        yield p, int(size), typ, hdr
        p += int(size)

def nested(data, wanted, start=0, end=None):
    out = []
    for p, size, typ, hdr in boxes(data, start, end):
        if typ == wanted: out.append((p, size, typ, hdr))
        if typ in {"moov","trak","mdia","minf","stbl","stsd","mvex","moof","traf","sinf","schi","encv","enca","avc1","avc2","avc3","avc4","hvc1","hev1","hev2","hev3","hev4","av01","vp09","mp4a","ac-3","ec-3"}:
            out.extend(nested(data, wanted, p+hdr, p+size))
    return out

def u16(d,o): return struct.unpack_from(">H",d,o)[0]
def u32(d,o): return struct.unpack_from(">I",d,o)[0]
def i32(d,o): return struct.unpack_from(">i",d,o)[0]

def parse_tenc(init):
    # tenc lives inside the sample-entry protection hierarchy under stsd.
    # A generic top-level box walker cannot enter stsd because its payload
    # begins with a FullBox header + entry_count before the sample entry boxes.
    needle=b"tenc"
    pos=init.find(needle)
    while pos >= 4:
        box_start=pos-4
        if box_start+32 <= len(init):
            size=struct.unpack_from(">I",init,box_start)[0]
            if size >= 32 and box_start+size <= len(init):
                # FullBox header is 4 bytes. tenc body is:
                # reserved, pattern(v1+) or reserved(v0), isProtected,
                # per-sample-IV-size, default_KID[16].
                version=init[box_start+8]
                pattern=init[box_start+13]
                protected=init[box_start+14]
                iv_size=init[box_start+15]
                kid=init[box_start+16:box_start+32]
                crypt=((pattern>>4)&15) if version>=1 else 0
                skip=(pattern&15) if version>=1 else 0
                return version,protected,iv_size,kid,crypt,skip
        pos=init.find(needle,pos+4)
    raise RuntimeError("init không có tenc")

def parse_scheme(init):
    for p,size,_,hdr in nested(init,"schm"):
        b=p+hdr
        if b+8 <= p+size:
            return init[b+4:b+8].decode("ascii","replace").lower()
    return "cenc"

def parse_senc(media, box, iv_size):
    p,size,_,hdr=box
    flags=int.from_bytes(media[p+hdr+1:p+hdr+4],"big")
    cur=p+hdr+4
    if cur+4>p+size: raise RuntimeError("senc thiếu sample_count")
    count=u32(media,cur); cur+=4
    if flags&1:
        if cur+20>p+size: raise RuntimeError("senc override thiếu dữ liệu")
        cur+=20
    result=[]
    for _ in range(count):
        if iv_size<=0: raise RuntimeError("senc cần constant IV nhưng smoke chưa có")
        if cur+iv_size>p+size: raise RuntimeError("senc thiếu IV")
        iv=media[cur:cur+iv_size]; cur+=iv_size
        subs=None
        if flags&2:
            if cur+2>p+size: raise RuntimeError("senc thiếu subsample count")
            n=u16(media,cur); cur+=2; subs=[]
            for _ in range(n):
                if cur+6>p+size: raise RuntimeError("senc subsample thiếu dữ liệu")
                subs.append((u16(media,cur),u32(media,cur+2)));cur+=6
        result.append((iv,subs))
    return result

def parse_tfhd(media,box):
    p,size,_,hdr=box
    flags=int.from_bytes(media[p+hdr+1:p+hdr+4],"big")
    cur=p+hdr+4
    track=u32(media,cur);cur+=4
    base=None
    if flags&1: base=struct.unpack_from(">Q",media,cur)[0];cur+=8
    if flags&2: cur+=4
    default=None
    if flags&8: cur+=4
    if flags&16: default=u32(media,cur);cur+=4
    return flags,track,base,default

def parse_trun(media,box,base,fallback,default):
    p,size,_,hdr=box
    flags=int.from_bytes(media[p+hdr+1:p+hdr+4],"big")
    cur=p+hdr+4
    count=u32(media,cur);cur+=4
    off=fallback
    if flags&1:
        off=base+i32(media,cur);cur+=4
    if flags&4: cur+=4
    sizes=[]
    for _ in range(count):
        if flags&0x100: cur+=4
        s=default
        if flags&0x200: s=u32(media,cur);cur+=4
        if flags&0x400: cur+=4
        if flags&0x800: cur+=4
        if s is None: raise RuntimeError("sample-size thiếu cả trun/tfhd")
        sizes.append(int(s))
    return off,sizes

def trex_default(init,track):
    for p,size,_,hdr in nested(init,"trex"):
        b=p+hdr
        if b+20<=p+size and u32(init,b+4)==track:
            return u32(init,b+16)
    return None

def decrypt(sample,key,iv,subs,scheme,crypt,skip):
    from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
    if scheme in ("cenc","cbc1"):
        counter=iv+(b"\\0"*8) if len(iv)==8 else iv
        if len(counter)!=16: raise RuntimeError("CTR IV không hợp lệ")
        c=Cipher(algorithms.AES(key),modes.CTR(counter)).encryptor()
        out=bytearray(sample)
        if subs is None:
            out[:]=c.update(bytes(out))
        else:
            pos=0
            for clear,enc in subs:
                pos+=clear
                out[pos:pos+enc]=c.update(bytes(out[pos:pos+enc]))
                pos+=enc
        c.finalize()
        return bytes(out)
    if scheme=="cbcs":
        out=bytearray(sample)
        pattern=max(1,crypt+skip)
        block_index=0
        chain_iv=iv
        for pos in range(0,len(out)-15,16):
            slot=block_index%pattern
            if slot < crypt:
                c=Cipher(algorithms.AES(key),modes.CBC(chain_iv)).decryptor()
                plain=c.update(bytes(out[pos:pos+16]))+c.finalize()
                chain_iv=bytes(out[pos:pos+16])
                out[pos:pos+16]=plain
            block_index+=1
        return bytes(out)
    raise RuntimeError("scheme không hỗ trợ: "+scheme)

def parse_sidx(data):
    b=next((x for x in boxes(data) if x[2]=="sidx"),None)
    if not b: raise RuntimeError("không tìm thấy sidx")
    p,size,_,hdr=b; cur=p+hdr
    version=data[cur]; cur+=4
    cur+=4
    timescale=u32(data,cur);cur+=4
    if version==0:
        earliest=u32(data,cur);cur+=4; first=u32(data,cur);cur+=4
    else:
        earliest=struct.unpack_from(">Q",data,cur)[0];cur+=8
        first=struct.unpack_from(">Q",data,cur)[0];cur+=8
    cur+=2
    count=u16(data,cur);cur+=2
    refs=[]
    for _ in range(count):
        raw=u32(data,cur);cur+=4
        rtype=(raw>>31)&1; rsize=raw&0x7fffffff
        dur=u32(data,cur);cur+=4
        refs.append((rtype,rsize,dur))
        cur+=4
    return timescale,earliest,first,refs

def get_segment_from_segmentbase(mpd_url, root, period, adaptation, rep):
    base=mpd_url
    for node in [root,period,adaptation,rep]:
        b=child(node,"BaseURL")
        if b is not None and b.text:
            base=urljoin(base,b.text.strip())
    sb=child(rep,"SegmentBase") or child(adaptation,"SegmentBase")
    if sb is None: raise RuntimeError("không có SegmentBase")
    init_node=child(sb,"Initialization")
    init_range=init_node.attrib.get("range") if init_node is not None else None
    index_range=sb.attrib.get("indexRange")
    if not init_range or not index_range: raise RuntimeError("SegmentBase thiếu initialization/indexRange")
    def rng(s):
        a,b=s.split("-",1);return int(a),int(b)
    ir=rng(init_range); sr=rng(index_range)
    init,_,iu,_=get(base,byte_range=ir)
    idx,_,_,_=get(base,byte_range=sr)
    timescale,earliest,first,refs=parse_sidx(idx)
    current=sr[1]+1+first
    for rtype,rsize,dur in refs:
        if rtype==0:
            mr=(current,current+rsize-1)
            media,_,mu,_=get(base,byte_range=mr)
            return init,media,iu,mu
        current+=rsize
    raise RuntimeError("SIDX không có reference type 0")

def get_segment_from_template(mpd_url, root, period, adaptation, rep):
    def choose_template():
        return child(rep,"SegmentTemplate") or child(adaptation,"SegmentTemplate")
    t=choose_template()
    if t is None: raise RuntimeError("không có SegmentTemplate")
    base=mpd_url
    for node in [root,period,adaptation,rep]:
        b=child(node,"BaseURL")
        if b is not None and b.text: base=urljoin(base,b.text.strip())
    number=int(t.attrib.get("startNumber","1"))
    timeline=child(t,"SegmentTimeline")
    s=child(timeline,"S")
    time=int(s.attrib.get("t","0")) if s is not None else 0
    def sub(template):
        vals={"Number":str(number),"Time":str(time),"RepresentationID":rep.attrib.get("id",""),"Bandwidth":rep.attrib.get("bandwidth","0")}
        return re.sub(r"\$(Number|Time|RepresentationID|Bandwidth)(?:%0(\d+)d)?\$",lambda m: vals[m.group(1)].zfill(int(m.group(2))) if m.group(2) and vals[m.group(1)].isdigit() else vals[m.group(1)],template)
    iu=urljoin(base,sub(t.attrib.get("initialization","")))
    mu=urljoin(base,sub(t.attrib.get("media","")))
    return (*get(iu)[:1],*get(mu)[:1],iu,mu)

def run_candidate(c):
    print(f"\n=== {c['name']} ===")
    mpd,_,final,_=get(c["mpd"])
    root=ET.fromstring(mpd); period=children(root,"Period")[0]
    adaptation=None
    for a in children(period,"AdaptationSet"):
        mime=(a.attrib.get("mimeType") or "").lower()
        ctype=(a.attrib.get("contentType") or "").lower()
        reps=children(a,"Representation")
        rep_video=any((r.attrib.get("mimeType") or "").lower().startswith("video/") for r in reps)
        has_video_component=any((x.attrib.get("contentType") or "").lower()=="video" for x in children(a,"ContentComponent"))
        if ctype=="video" or mime.startswith("video/") or rep_video or has_video_component:
            adaptation=a; break
    if adaptation is None: raise RuntimeError("video AdaptationSet not found")
    rep=children(adaptation,"Representation")[0]
    segmentbase=child(rep,"SegmentBase") or child(adaptation,"SegmentBase")
    if segmentbase is not None:
        init,media,iu,mu=get_segment_from_segmentbase(final,root,period,adaptation,rep)
        mode="SegmentBase"
    else:
        init0,media0,iu,mu=get_segment_from_template(final,root,period,adaptation,rep)
        init,media=init0,media0; mode="SegmentTemplate"
    print(f"MODE={mode}\nINIT={iu} bytes={len(init)}\nMEDIA={mu} bytes={len(media)}")
    ver,protected,iv_size,kid,crypt,skip=parse_tenc(init)
    scheme=parse_scheme(init)
    expected=bytes.fromhex(c["kid"])
    key=bytes.fromhex(c["key"])
    if kid!=expected:
        # Axinom/alternate identifier form.
        alt=c.get("alternate_key")
        if alt:
            alt_kid=base64.urlsafe_b64decode(alt[0]+"="*((4-len(alt[0])%4)%4))
            alt_key=base64.urlsafe_b64decode(alt[1]+"="*((4-len(alt[1])%4)%4))
            if kid==alt_kid:
                key=alt_key; expected=alt_kid
            else:
                raise RuntimeError(f"KID mismatch expected={expected.hex()} actual={kid.hex()}")
        else:
            raise RuntimeError(f"KID mismatch expected={expected.hex()} actual={kid.hex()}")
    if protected!=1: raise RuntimeError("tenc isProtected != 1")
    print(f"DRM scheme={scheme} version={ver} ivSize={iv_size} crypt={crypt} skip={skip} KID={kid.hex()}")
    moof=next((x for x in boxes(media) if x[2]=="moof"),None)
    if not moof: raise RuntimeError("media không có moof")
    mp,ms,_,mh=moof
    traf=next((x for x in boxes(media,mp+mh,mp+ms) if x[2]=="traf"),None)
    if not traf: raise RuntimeError("moof không có traf")
    tp,ts,_,th=traf
    cs=list(boxes(media,tp+th,tp+ts))
    tfhd=next((x for x in cs if x[2]=="tfhd"),None)
    trun=next((x for x in cs if x[2]=="trun"),None)
    senc=next((x for x in cs if x[2]=="senc"),None)
    if not tfhd or not trun or not senc:
        raise RuntimeError("fragment thiếu tfhd/trun/senc")
    flags,track,base0,tfhd_size=parse_tfhd(media,tfhd)
    base=base0 if base0 is not None else mp
    default=tfhd_size if tfhd_size is not None else trex_default(init,track)
    fallback=mp+ms
    data_off,sizes=parse_trun(media,trun,base,fallback,default)
    entries=parse_senc(media,senc,iv_size)
    if len(entries)!=len(sizes): raise RuntimeError("senc/trun count mismatch")
    if data_off<0 or data_off+sizes[0]>len(media): raise RuntimeError(f"sample range invalid offset={data_off} size={sizes[0]} bytes={len(media)}")
    iv,subs=entries[0]
    dec=decrypt(media[data_off:data_off+sizes[0]],key,iv,subs,scheme,crypt,skip)
    if len(dec)<5: raise RuntimeError("decrypted sample quá ngắn")
    n=int.from_bytes(dec[:4],"big")
    typ=(dec[4]&0x1f)
    if not (0<n<=len(dec)-4 and 1<=typ<=31):
        raise RuntimeError(f"decrypted AVC NAL heuristic fail: {dec[:16].hex()}")
    print(f"REAL-CLEARKEY-SMOKE PASS mode={mode} track={track} sampleSize={sizes[0]} dataOffset={data_off} firstNAL={n} type={typ} head={dec[:16].hex()}")

def main():
    last=None
    for c in CANDIDATES:
        try:
            run_candidate(c); return
        except Exception as exc:
            print(f"CANDIDATE FAILED: {exc}")
            last=exc
    raise RuntimeError(f"all public ClearKey candidates failed: {last}")

if __name__=="__main__":
    try: main()
    except Exception as e:
        print(f"REAL-CLEARKEY-SMOKE FAIL: {e}",file=sys.stderr); raise
