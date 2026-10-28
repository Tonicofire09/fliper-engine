"""Identidade da Fliper Engine: gera os SVG/PNG/ICO da marca a partir da grade do logo Fliper (5x5, olhos magenta).
   python3 misc/fliper/marca.py   (precisa de Pillow e do Playwright com Chromium para os PNG)"""
import os, subprocess
from PIL import Image, ImageDraw
AQUI = os.path.dirname(os.path.abspath(__file__)); RAIZ = os.path.dirname(os.path.dirname(AQUI))
MAGENTA, BRANCO, PRETO, DOURADO = '#FF2E88', '#FFFFFF', '#050505', '#FFC531'
# o logo do site: 5x5, 1 = branco, 2 = magenta (olhos)
MARCA = ['.111.', '11111', '12121', '.111.', '1...1']
# fonte pixel 5x7 só com as letras da marca
F = {
 'F': ['11111','1....','1....','1111.','1....','1....','1....'], 'L': ['1....','1....','1....','1....','1....','1....','11111'],
 'I': ['111','.1.','.1.','.1.','.1.','.1.','111'], 'P': ['1111.','1...1','1...1','1111.','1....','1....','1....'],
 'E': ['11111','1....','1....','1111.','1....','1....','11111'], 'R': ['1111.','1...1','1...1','1111.','1.1..','1..1.','1...1'],
 'N': ['1...1','11..1','1.1.1','1..11','1...1','1...1','1...1'], 'G': ['.111.','1...1','1....','1.111','1...1','1...1','.111.'],
 ' ': ['..','..','..','..','..','..','..']}

def marca_rects(x0, y0, cel, gap=0.14):
    out = []
    for j, l in enumerate(MARCA):
        for i, c in enumerate(l):
            if c == '.': continue
            r = cel * (1 - gap)
            out.append(f'<rect x="{x0 + i * cel + cel * gap / 2:.2f}" y="{y0 + j * cel + cel * gap / 2:.2f}" width="{r:.2f}" height="{r:.2f}" rx="{cel * .13:.2f}" fill="{MAGENTA if c == "2" else "{cor}"}"/>')
    return out

def texto_rects(t, x0, y0, px, cor):
    out, x = [], x0
    for ch in t:
        g = F[ch]
        for j, l in enumerate(g):
            for i, c in enumerate(l):
                if c == '1': out.append(f'<rect x="{x + i * px:.2f}" y="{y0 + j * px:.2f}" width="{px + .3:.2f}" height="{px + .3:.2f}" fill="{cor}"/>')
        x += (len(g[0]) + 1) * px
    return out, x - px

def svg(w, h, corpo, fundo=None):
    bg = f'<rect width="{w}" height="{h}" fill="{fundo}"/>' if fundo else ''
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" shape-rendering="crispEdges">{bg}{"".join(corpo)}</svg>\n'

def logo(w, h, cor_txt, sub=None):
    """marca + FLIPER (e um subtítulo em magenta), cabendo em w x h."""
    cel = h / 5 * 0.78; y = (h - cel * 5) / 2
    m = [r.replace('{cor}', cor_txt) for r in marca_rects(0, y, cel)]
    livre = w - (cel * 5 + cel * .9)
    px = min(h / 7 * (0.62 if not sub else 0.5), livre / 33)  # FLIPER = 33 colunas de pixel
    t, fim = texto_rects('FLIPER', cel * 5 + cel * .9, (h - px * 7) / 2 - (px * 2.2 if sub else 0), px, cor_txt)
    s = []
    if sub: s, _ = texto_rects(sub, cel * 5 + cel * .9, (h - px * 7) / 2 + px * 6.4, px * .55, MAGENTA)
    return m + t + s

def grava(rel, txt):
    p = os.path.join(RAIZ, rel); open(p, 'w').write(txt); return p

def png(svgp, pngp, w, h):
    subprocess.run(['node', os.path.join(AQUI, 'rasterizar.cjs'), svgp, pngp, str(w), str(h)], check=True)

if __name__ == '__main__':
    # editor: logo do gerenciador de projetos e da barra de título
    grava('editor/icons/Logo.svg', svg(187, 69, logo(187, 69, '#FFFFFF', 'ENGINE')))
    grava('editor/icons/TitleBarLogo.svg', svg(100, 24, logo(100, 24, '#E0E0E0')))
    # ícone: a marca num quadrado preto arredondado
    ic = [r.replace('{cor}', BRANCO) for r in marca_rects(22, 22, 16.8)]
    icone = f'<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128"><rect width="128" height="128" rx="24" fill="{PRETO}"/><rect x="3" y="3" width="122" height="122" rx="22" fill="none" stroke="{MAGENTA}" stroke-width="2" opacity=".55"/>{"".join(ic)}</svg>\n'
    for rel in ['misc/logo/icon.svg', 'misc/fliper/icon.svg']: grava(rel, icone)
    png(os.path.join(RAIZ, 'misc/fliper/icon.svg'), os.path.join(RAIZ, 'main/app_icon.png'), 128, 128)
    png(os.path.join(RAIZ, 'misc/fliper/icon.svg'), os.path.join(RAIZ, 'misc/logo/icon.png'), 128, 128)
    # tela de abertura (editor e jogos): preto, marca + FLIPER ENGINE
    cel = 34; m = [r.replace('{cor}', BRANCO) for r in marca_rects(400 - cel * 2.5, 190, cel)]
    t, fim = texto_rects('FLIPER', 0, 0, 9, BRANCO); larg = fim
    t, _ = texto_rects('FLIPER', 400 - larg / 2, 395, 9, BRANCO)
    s, fim2 = texto_rects('ENGINE', 0, 0, 4, MAGENTA); s, _ = texto_rects('ENGINE', 400 - fim2 / 2, 470, 4, MAGENTA)
    grava('misc/fliper/splash.svg', svg(800, 600, m + t + s))
    png(os.path.join(RAIZ, 'misc/fliper/splash.svg'), os.path.join(RAIZ, 'main/splash.png'), 800, 600)
    # ícone do Windows (várias resoluções)
    big = os.path.join(AQUI, 'icon256.png'); png(os.path.join(RAIZ, 'misc/fliper/icon.svg'), big, 256, 256)
    im = Image.open(big)
    for rel in ['platform/windows/godot.ico', 'platform/windows/godot_console.ico']:
        im.save(os.path.join(RAIZ, rel), sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    os.remove(big)
    print('marca Fliper gravada')
