import numpy as np, wave, os
from scipy.signal import butter, sosfilt
SR=44100; rng=np.random.default_rng(7); OUT='/mnt/user-data/outputs/sounds'
T=lambda d: np.arange(int(SR*d))/SR
def bp(x,lo,hi): return sosfilt(butter(2,[lo,hi],'band',fs=SR,output='sos'),x)
def lp(x,f): return sosfilt(butter(2,f,'low',fs=SR,output='sos'),x)
def hp(x,f): return sosfilt(butter(2,f,'high',fs=SR,output='sos'),x)
def noise(d): return rng.standard_normal(int(SR*d))
def atk(x,ms=2):
    n=int(SR*ms/1000); x=x.copy(); x[:n]*=np.linspace(0,1,n); return x
def tine(f,d=1.0,v=1.0,k=5.0):
    # kalimba kayu: fundamental + partial 4x + partial 9.2x (tidak harmonis, khas kayu/logam kecil)
    x=T(d); s=np.sin(2*np.pi*f*x)*np.exp(-k*x)+.45*np.sin(2*np.pi*f*4.02*x)*np.exp(-k*3*x)+.22*np.sin(2*np.pi*f*9.2*x)*np.exp(-k*7*x)
    return atk(s)*v
def knock(f=1000,d=.08,v=1.0,decay=60):
    x=T(d); return atk(bp(noise(d),f*.7,f*1.5)*np.exp(-decay*x)*3+np.sin(2*np.pi*f*.55*x)*np.exp(-decay*1.2*x)*.6,.5)*v
def glide(f0,f1,d,k=6):
    x=T(d); f=f0+(f1-f0)*np.minimum(x/d,1); return np.sin(2*np.pi*np.cumsum(f)/SR)*np.exp(-k*x)
def place(buf,s,at,g=1.0):
    i=int(at*SR); e=min(len(buf),i+len(s))
    if i<len(buf): buf[i:e]+=s[:e-i]*g
def mix(*xs):
    n=max(len(x) for x in xs); o=np.zeros(n)
    for x in xs: o[:len(x)]+=x
    return o
def mk(d): return np.zeros(int(SR*d))
def save(name,x,peak=.8):
    x=x.copy(); n=int(SR*.004); x[:n]*=np.linspace(0,1,n); x[-n:]*=np.linspace(1,0,n)
    x=x/max(1e-9,np.max(np.abs(x)))*peak
    with wave.open(f'{OUT}/{name}.wav','wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(SR);w.writeframes((x*32767).astype('<i2').tobytes())
    print(f'{name:22s}{len(x)/SR:5.2f}s peak {np.max(np.abs(x)):.2f}')
P=dict(C5=523.25,D5=587.33,E5=659.25,G5=783.99,A5=880.0,C6=1046.5,D6=1174.7,E6=1318.5,G6=1568.0,A6=1760.0,C7=2093.0)
def tick(v=1.0,f=1200): return mix(knock(f,.06,v),tine(2400,.05,.12*v,k=40))
def spin_times(dur,N=21): return [dur*(1-(1-k/N)**.25) for k in range(1,N+1)]
def spin(dur,N=21):
    b=mk(dur+.3); x=T(dur+.3); tau=np.minimum(x/dur,1)
    b+=lp(noise(dur+.3),1800)*(1-tau)**3*.22
    for i,t in enumerate(spin_times(dur,N)): place(b,tick(.9,1100+60*(i%3)),t)
    return b
# ---- RODA
for i,f in enumerate([1050,1200,1350]): save(f'wheel_tick_{i+1}',tick(1,f)[:int(SR*.07)],.7)
save('wheel_spin',spin(6.0))
b=mk(1.6); place(b,glide(150,60,.25,10)*1.1,0); place(b,knock(900,.08),0)
for i,n in enumerate(['G5','C6','E6','G6']): place(b,tine(P[n],1.2,.55),.08+i*.07)
save('wheel_land',b)
# ---- DADU
b=mk(2.4); t=.0; k=0
for bounce,(at,g,f) in enumerate([(0.0,1,500),(.55,.8,450),(1.05,.6,400),(1.45,.4,380),(1.75,.25,360)]):
    place(b,knock(f,.12,1,40)*g,at)
    for j in range(4): place(b,knock(rng.uniform(1800,3200),.04,.7,90)*g*.8,at+rng.uniform(.02,.2))
for i in range(14):
    place(b,knock(rng.uniform(2000,3800),.03,.5,110),.05+i*.045*(1+i*.12))
save('dice_roll',b)
b=mk(.6); place(b,knock(520,.12,1,45),0); place(b,knock(2600,.04,.6,100),.01); place(b,tine(P['E6'],.5,.25),.05)
save('dice_land',b)
# ---- KAPSUL
b=mk(1.8)
for i in range(13): place(b,mix(knock(650+40*(i%2),.07,.9),tine(2200,.05,.2,k=40)),.1+i*.115)
place(b,lp(noise(1.8),300)*np.sin(np.linspace(0,np.pi,int(SR*1.8)))*.5,0)
save('capsule_crank',b)
b=mk(1.2); place(b,glide(700,220,.12,25)*1.0,0)
for at,g in [(.28,.9),(.5,.55),(.66,.3),(.78,.15)]: place(b,mix(knock(1700,.07,1,70)*g,glide(900,500,.06,50)*.3*g),at)
save('capsule_drop',b)
b=mk(1.4); x=T(.2); place(b,mix(bp(noise(.2),1800,7000)*np.exp(-45*x)*2.5,glide(300,950,.2,12)*.8),0)
for i,n in enumerate(['C6','E6','G6','A6','C7']): place(b,tine(P[n],.8,.5),.07+i*.055)
save('capsule_open',b)
# ---- AMPLOP
n=1.3; x=T(n); m=lp(np.abs(lp(noise(n),30)),30)
m=m/m.max(); b=bp(noise(n),2500,9000)*(m**2)*np.sin(np.linspace(0,np.pi,len(x)))*3
save('envelope_shuffle',b,.6)
b=mk(1.4); x=T(.25); place(b,bp(noise(.25),1200,5000)*np.minimum(x/.03,1)*np.exp(-12*x)*2,0)
sw=T(.4); place(b,hp(noise(.4),4500)*np.sin(np.pi*sw/.4)**2*.5,.12)
for i,nm in enumerate(['G6','C7']): place(b,tine(P[nm],1.0,.4),.45+i*.1)
save('envelope_open',b)
# ---- HASIL & UI
b=mk(2.6)
for i,nm in enumerate(['C5','E5','G5','A5','C6','E6']): place(b,tine(P[nm],1.0,.7),i*.09)
for nm in ['C5','E5','G5','C6']: place(b,tine(P[nm],1.6,.55,k=3),.62)
for i in range(6): place(b,tine(rng.choice([P['G6'],P['A6'],P['C7']]),.5,.18),.7+i*.07)
save('win_lolos',b)
b=mk(1.6)
def wob(f0,f1,d):
    x=T(d); f=f0+(f1-f0)*np.minimum(x/d,1)+4*np.sin(2*np.pi*5.5*x); return atk(np.sin(2*np.pi*np.cumsum(f)/SR)*np.exp(-3.2*x)*.9+.3*np.sin(4*np.pi*np.cumsum(f)/SR)*np.exp(-6*x))
place(b,wob(659,587,.7),0); place(b,wob(523,415,.9),.28); place(b,knock(220,.1,.7,35),.28)
save('over_budget',b)
save('ui_tap',mix(tine(P['A6'],.12,1,k=25),knock(1800,.04,.5,100)),.6)
b=mk(.9)
for i,(f,at,g) in enumerate([(2740,0,1),(3650,0,.7),(5120,0,.45),(3100,.1,.8),(4150,.1,.5)]):
    x=T(.6); place(b,np.sin(2*np.pi*f*x)*np.exp(-9*x),at,g)
place(b,knock(3000,.03,.8,150),0)
save('coin_record',b,.75)
b=mk(1.0); place(b,tine(P['A5'],.9,.8),0); place(b,tine(P['E5'],.9,.8),.17); place(b,tine(P['E5']/2,.5,.4,k=7),.17)
save('notif_warning',b)
b=mk(1.2)
for i,nm in enumerate(['C5','E5','G5']): place(b,tine(P[nm],.9,.7),i*.13)
place(b,tine(P['C6'],1.0,.5),.42)
save('notif_reminder',b)
# ---- SPLASH 3.6 dtk (sinkron dengan animasi)
D=3.6; b=mk(D+.6)
for k in range(8): place(b,mix(tine(P[['C5','D5','E5','G5','A5','C6','D6','E6'][k]],.35,.45,k=9),bp(noise(.08),1500+k*400,4000+k*400)*np.exp(-30*T(.08))*.5),k*.045)
for k in range(10): place(b,tick(.35,2200+(k%2)*300)[:int(SR*.05)],.6+k*.06)
sp=spin(D*.44,21); place(b,sp,D*.10,.9)
place(b,tine(P['C6'],.4,.4,k=8),D*.47); place(b,knock(700,.1,.9,45),D*.47)
place(b,knock(900,.08,1),D*.545)
for i,nm in enumerate(['G5','C6','E6','G6']): place(b,tine(P[nm],1.2,.5),D*.545+i*.05)
place(b,glide(300,950,.2,12)*.6,D*.56)
for i in range(10): place(b,tine(rng.choice([P['G6'],P['A6'],P['C7'],P['E6']]),.4,.18),D*.54+i*.035)
place(b,bp(noise(.4),1500,6000)*np.sin(np.pi*T(.4)/.4)**2*.5,D*.56)
for i,nm in enumerate(['C5','E5','G5','A5']): place(b,tine(P[nm],1.1,.6),D*.62+i*.11)
for nm in ['C5','G5','C6','E6']: place(b,tine(P[nm],1.5,.45,k=3),D*.62+.55)
save('splash_jingle',b)
# ---- KOIN
b=mk(1.4); x=T(1.4); trem=.55+.45*np.sin(2*np.pi*(9*x-3.2*x*x))
ring=sum(np.sin(2*np.pi*f*x*(1+.004*np.sin(2*np.pi*6*x)))*a for f,a in [(2740,1),(3650,.6),(5120,.35),(1830,.4)])*np.exp(-1.8*x)*trem
b+=ring*.5; place(b,bp(noise(.2),900,3500)*np.sin(np.pi*T(.2)/.2)*1.2,0)
save('coin_flip',b)
b=mk(.9); place(b,knock(2600,.05,1,90),0)
for f,a in [(2740,1),(3650,.7),(5120,.4)]: place(b,np.sin(2*np.pi*f*T(.8))*np.exp(-9*T(.8)),0,a*.5)
for at,g in [(.1,.55),(.19,.35),(.26,.2),(.31,.1)]: place(b,knock(3200,.03,1,120)*g,at)
save('coin_land',b,.75)
b=mk(1.2)
for i,nm in enumerate(['C6','E6','G6','C7']): place(b,tine(P[nm],.9,.6),i*.07)
for i in range(5): place(b,tine(rng.choice([P['G6'],P['A6'],P['C7']]),.4,.18),.3+i*.06)
save('coin_double',b)
b=mk(1.2); place(b,wob(587,494,.5)*.8,0); place(b,wob(440,370,.6)*.6,.22); place(b,knock(250,.1,.5,40),.22)
save('coin_halve',b)
