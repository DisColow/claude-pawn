import sys, numpy as np
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]
img = Image.open(src).convert('RGB').resize((1024,1024), Image.LANCZOS)
im = np.asarray(img).astype(np.float32)/255
r,g,b = im[...,0],im[...,1],im[...,2]
mx = im.max(-1); mn = im.min(-1); d = mx-mn
s = np.where(mx>0, d/np.maximum(mx,1e-6), 0); v = mx
m = d>1e-6
rc=np.where(m,(mx-r)/np.maximum(d,1e-6),0); gc=np.where(m,(mx-g)/np.maximum(d,1e-6),0); bc=np.where(m,(mx-b)/np.maximum(d,1e-6),0)
h = np.where(r==mx, bc-gc, np.where(g==mx, 2+rc-bc, 4+gc-rc)); h=(h/6)%1
skin = s>0.18
cloth = (s<0.18)&(v<0.45)
h2 = np.where(skin, (h+0.17)%1, h); s2 = np.where(skin, np.clip(s*1.2,0,0.55), s); v2 = np.where(skin, v*0.58, v)
h2 = np.where(cloth, 0.07, h2); s2 = np.where(cloth, 0.6, s2); v2 = np.where(cloth, np.clip(v*1.1,0,1), v2)
i = np.floor(h2*6).astype(int)%6; f = h2*6-np.floor(h2*6)
p=v2*(1-s2); q=v2*(1-s2*f); t=v2*(1-s2*(1-f))
out = np.zeros(h2.shape+(3,),np.float32)
for k,(a,bb,c) in enumerate([(v2,t,p),(q,v2,p),(p,v2,t),(p,q,v2),(t,p,v2),(v2,p,q)]):
    sel=i==k; out[sel,0]=a[sel]; out[sel,1]=bb[sel]; out[sel,2]=c[sel]
Image.fromarray((np.clip(out,0,1)*255).astype(np.uint8)).save(dst)
