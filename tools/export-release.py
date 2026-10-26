"""Allowlist-only, deterministic source archive with conservative privacy gates."""
import argparse, hashlib, json, re, zipfile
from pathlib import Path

def inspect(root, listed):
    findings=[]; files=[]
    for rel in listed:
        p=root/rel
        if not p.is_file() or p.is_symlink() or not p.resolve().is_relative_to(root.resolve()):
            findings.append({'file':rel,'rule':'missing-or-unsafe-path'});continue
        if p.suffix.lower() not in {'.md','.json','.py','.ps1','.cjs','.cmd','.txt',''} and p.name!='.gitignore':
            findings.append({'file':rel,'rule':'extension-denied'});continue
        try: text=p.read_text(encoding='utf-8-sig')
        except UnicodeError: findings.append({'file':rel,'rule':'non-text'});continue
        patterns={
          'private-key':r'-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
          'github-token':r'\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,})\b',
          'aws-key':r'\bAKIA[A-Z0-9]{16}\b',
          'live-websocket':r'wss?://[^\s\x22\x27<>]+/[^\s\x22\x27<>]{8,}',
          'dpapi-blob':r'01000000d08c9ddf' + r'0115d1118c7a00c04fc297eb',
          'machine-guid':r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b',
          'user-profile-path':r'[A-Za-z]:[\\/]+Users[\\/]+(?!<)[A-Za-z0-9_.-]+',
          'private-project-root':r'[A-Za-z]:[\\/]+gpt[\\/]+(?:2026-|opc|vms)',
        }
        for rule,pattern in patterns.items():
            if re.search(pattern,text,re.I):findings.append({'file':rel,'rule':rule})
        files.append({'path':rel,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
    return findings,files

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--report',type=Path,required=True);a=p.parse_args()
    root=Path(__file__).resolve().parents[1]
    listed=json.loads((root/'release-allowlist.json').read_text())
    if len(set(listed))!=len(listed):raise SystemExit('Duplicate allowlist entry')
    findings,files=inspect(root,listed)
    a.report.parent.mkdir(parents=True,exist_ok=True)
    report={'passed':not findings,'scope':'allowlisted text only; pattern scan is not proof that all secrets are absent','findings':findings,'files':files}
    a.report.write_text(json.dumps(report,indent=2),encoding='utf-8')
    if findings:raise SystemExit('Export refused: privacy/path findings; inspect report')
    a.output.parent.mkdir(parents=True,exist_ok=True)
    with zipfile.ZipFile(a.output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=9) as z:
        for item in sorted(files,key=lambda i:i['path']):
            info=zipfile.ZipInfo('workbox/'+item['path'],date_time=(2026,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED;info.external_attr=0o644<<16
            z.writestr(info,(root/item['path']).read_bytes())
        info=zipfile.ZipInfo('workbox/SHA256SUMS.txt',date_time=(2026,1,1,0,0,0));info.compress_type=zipfile.ZIP_DEFLATED
        z.writestr(info,''.join(i['sha256']+'  '+i['path']+'\n' for i in sorted(files,key=lambda i:i['path'])))
    print(json.dumps({'files':len(files),'archiveSha256':hashlib.sha256(a.output.read_bytes()).hexdigest(),'bytes':a.output.stat().st_size}))
if __name__=='__main__':main()
