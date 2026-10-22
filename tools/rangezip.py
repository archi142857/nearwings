import io, sys, zipfile, requests

class RangeFile(io.RawIOBase):
    def __init__(self, url):
        self.s = requests.Session()
        r = self.s.head(url, allow_redirects=True)
        r.raise_for_status()
        self.url = r.url
        self.size = int(r.headers["Content-Length"])
        self.pos = 0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos
    def seek(self, off, whence=0):
        self.pos = off if whence == 0 else (self.pos + off if whence == 1 else self.size + off)
        return self.pos
    def read(self, n=-1):
        if n is None or n < 0: n = self.size - self.pos
        if n == 0 or self.pos >= self.size: return b""
        end = min(self.pos + n, self.size) - 1
        r = self.s.get(self.url, headers={"Range": f"bytes={self.pos}-{end}"})
        if r.status_code != 206: raise IOError(f"range failed {r.status_code}")
        self.pos += len(r.content)
        return r.content
    def readinto(self, b):
        d = self.read(len(b)); b[:len(d)] = d; return len(d)

url, outdir, *suffixes = sys.argv[1:]
z = zipfile.ZipFile(io.BufferedReader(RangeFile(url), buffer_size=1 << 20))
print(len(z.namelist()), "entries")
for i in z.infolist():
    if any(i.filename.endswith(s) for s in suffixes):
        print("extract", i.filename, i.file_size)
        z.extract(i, outdir)
