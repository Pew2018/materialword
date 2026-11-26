#!/usr/bin/env python3
"""Render editable SVG sources. Python 3.9+, CairoSVG 2.8.2, Pillow 11.3.0, libcairo.
Run: python tool/generate_app_icons.py [--check]
No Flutter runtime dependencies. --check validates committed outputs without writing.
"""
import argparse
import io
import json
import struct
from pathlib import Path
import xml.etree.ElementTree as ET
import cairosvg
from PIL import Image, ImageDraw, ImageCms, ImageChops

ROOT = Path(__file__).resolve().parents[1]
DESIGN = ROOT / 'design/app-icon'
RES = ROOT / 'android/app/src/main/res'
NS = '{http://www.w3.org/2000/svg}'
_profile = bytearray(ImageCms.ImageCmsProfile(ImageCms.createProfile('sRGB')).tobytes())
# ICC creation time is metadata, not design state. Freeze it for reproducible PNGs.
_profile[24:36] = struct.pack('>6H', 2026, 1, 1, 0, 0, 0)
_profile[84:100] = bytes(16)  # optional profile ID: not computed
ICC = bytes(_profile)
DENSITIES = [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]


def source(name, adaptive=False):
    doc = ET.parse(DESIGN / (name + '.svg')).getroot()
    body = ''.join(ET.tostring(c, encoding='unicode') for c in doc if c.tag != NS + 'defs')
    defs = ''.join(ET.tostring(c, encoding='unicode') for c in doc if c.tag == NS + 'defs')
    if adaptive:
        body = '<g transform="translate(512 512) scale(.72) translate(-512 -512)">' + body + '</g>'
    return defs, body


def svg(name='master', style='full', adaptive=False):
    defs, body = source(name, adaptive)
    if style in ('mac', 'legacy'):
        inset = 64 if style == 'mac' else 16
        width = 1024 - 2 * inset
        defs += f'<defs><clipPath id="edge"><rect x="{inset}" y="{inset}" width="{width}" height="{width}" rx="{width * .225}"/></clipPath></defs>'
        body = f'<g clip-path="url(#edge)"><g transform="translate({inset} {inset}) scale({width / 1024})">{body}</g></g>'
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">{defs}{body}</svg>'


def render(data, size):
    # Each target is rendered independently from paths at 4x for clean small edges.
    png = cairosvg.svg2png(bytestring=data.encode(), output_width=size * 4, output_height=size * 4)
    return Image.open(io.BytesIO(png)).convert('RGBA').resize((size, size), Image.Resampling.LANCZOS)


def save(im, path, rgb=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    if rgb:
        im = im.convert('RGB')
    im.save(path, icc_profile=ICC)


def catalog(platform):
    folder = ROOT / platform / 'Runner/Assets.xcassets/AppIcon.appiconset'
    for entry in json.loads((folder / 'Contents.json').read_text())['images']:
        size = round(float(entry['size'].split('x')[0]) * float(entry['scale'][:-1]))
        yield folder / entry['filename'], size


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text + '\n')


def generate():
    for platform in ('ios', 'macos'):
        for path, size in set(catalog(platform)):
            save(render(svg(style='mac' if platform == 'macos' else 'full'), size), path, rgb=platform == 'ios')
    for density, scale in DENSITIES:
        save(render(svg(style='legacy'), round(48 * scale)), RES / f'mipmap-{density}/ic_launcher.png')
        save(render(svg('foreground', adaptive=True), round(108 * scale)), RES / f'drawable-{density}/ic_launcher_foreground.png')
    write(RES / 'drawable/ic_launcher_background.xml', '''<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">
    <gradient android:angle="315" android:startColor="#249AF2" android:centerColor="#1565C0" android:endColor="#0645A8" />
</shape>''')
    mono = ET.parse(DESIGN / 'monochrome.svg').getroot()
    paths = list(mono.iter(NS + 'path'))
    xmlpaths = '\n'.join(f'        <path android:fillColor="#FF000000" android:fillType="evenOdd" android:pathData="{p.attrib["d"]}" />' for p in paths)
    write(RES / 'drawable/ic_launcher_monochrome.xml', f'''<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
    <group android:scaleX="0.0759375" android:scaleY="0.0759375" android:translateX="15.12" android:translateY="13.905">
{xmlpaths}
    </group>
</vector>''')
    for api in (26, 33):
        mono_line = '\n    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />' if api == 33 else ''
        write(RES / f'mipmap-anydpi-v{api}/ic_launcher.xml', f'''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />{mono_line}
</adaptive-icon>''')
    preview()


def masked(im, shape):
    size = im.width
    mask = Image.new('L', im.size)
    d = ImageDraw.Draw(mask)
    if shape == 'circle':
        d.ellipse((0, 0, size - 1, size - 1), fill=255)
    elif shape == 'rounded':
        d.rounded_rectangle((0, 0, size - 1, size - 1), radius=size * .23, fill=255)
    else:
        pix = mask.load()
        for y in range(size):
            for x in range(size):
                if abs((x + .5 - size / 2) / (size / 2)) ** 4 + abs((y + .5 - size / 2) / (size / 2)) ** 4 <= 1:
                    pix[x, y] = 255
    out = im.copy()
    out.putalpha(ImageChops.multiply(out.getchannel('A'), mask))
    return out


def adaptive(size, mono=False, color='#205842', bg='#C3EDCE'):
    # Preview the generated Android resources, including VectorDrawable transforms.
    if mono:
        im = Image.new('RGBA', (size, size), bg)
        fg = Image.new('RGBA', im.size, color)
        doc = ET.parse(RES / 'drawable/ic_launcher_monochrome.xml').getroot()
        ns = '{http://schemas.android.com/apk/res/android}'
        group = doc.find('group')
        a = group.attrib
        paths = ''.join(f'<path fill-rule="evenodd" d="{p.attrib[ns + "pathData"]}"/>' for p in group)
        native = f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108"><g transform="translate({a[ns + "translateX"]} {a[ns + "translateY"]}) scale({a[ns + "scaleX"]} {a[ns + "scaleY"]})">{paths}</g></svg>'
        fg.putalpha(render(native, size).getchannel('A'))
    else:
        ns = '{http://schemas.android.com/apk/res/android}'
        gradient = ET.parse(RES / 'drawable/ic_launcher_background.xml').getroot().find('gradient')
        assert gradient.attrib[ns + 'angle'] == '315'
        stops = [gradient.attrib[ns + key] for key in ('startColor', 'centerColor', 'endColor')]
        native_bg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 108 108"><defs><linearGradient id="bg" x2="1" y2="1">' + ''.join(f'<stop offset="{i / 2}" stop-color="{c}"/>' for i, c in enumerate(stops)) + '</linearGradient></defs><path fill="url(#bg)" d="M0 0H108V108H0Z"/></svg>'
        im = render(native_bg, size)
        fg = Image.open(RES / 'drawable-xxxhdpi/ic_launcher_foreground.png').convert('RGBA').resize((size, size), Image.Resampling.LANCZOS)
    im.alpha_composite(fg)
    # Launchers expose the central 72dp of the 108dp layers before applying masks.
    inset = size // 6
    return im.crop((inset, inset, size - inset, size - inset)).resize((size, size), Image.Resampling.LANCZOS)


def preview():
    sheet = Image.new('RGB', (1320, 1000), '#F1F4F8')
    d = ImageDraw.Draw(sheet)
    d.text((36, 24), 'MaterialWord / generated platform assets / simulated masks', fill='#173451')
    def paste(im, x, y, label):
        sheet.paste(im, (x, y), im if im.mode == 'RGBA' else None)
        d.text((x, y + im.height + 12), label, fill='#173451')
    ios = Image.open(ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png').convert('RGBA')
    paste(masked(ios.resize((300, 300)), 'rounded'), 36, 65, 'iOS / system mask simulation')
    paste(Image.open(ROOT / 'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png').resize((300, 300)), 370, 65, 'macOS / actual alpha boundary')
    for i, shape in enumerate(('circle', 'rounded', 'squircle')):
        paste(masked(adaptive(180), shape), 710 + i * 200, 100, 'Android / ' + shape)
    d.text((36, 430), 'Actual iOS and macOS outputs at native pixels (16px is macOS only)', fill='#173451')
    for i, size in enumerate((16, 24, 32, 48, 64)):
        paste(render(svg(), size), 40 + i * 140, 480, str(size) + 'px iOS' if size != 16 else '16px brand probe')
        paste(render(svg(style='mac'), size), 40 + i * 140, 600, str(size) + 'px macOS')
    for i, (color, bg) in enumerate((('#205842', '#C3EDCE'), ('#5B3820', '#FFE0BC'), ('#D4D7FF', '#292C52'))):
        paste(masked(adaptive(150, True, color, bg), 'circle'), 730 + i * 185, 460, 'Themed / holes')
    # Show a high resolution alpha safe-zone overlay, including motion margin.
    safe = render(svg('foreground', adaptive=True), 216)
    safe_bg = Image.new('RGBA', safe.size, '#DDE6F1')
    safe_bg.alpha_composite(safe)
    sd = ImageDraw.Draw(safe_bg)
    sd.ellipse((42, 42, 174, 174), outline='#DA3F57', width=2)
    paste(safe_bg, 770, 710, '108dp / red = 66dp circle')
    d.text((36, 870), 'Editable paths. Fixed brand blue #1565C0. No baked Apple mask in iOS assets.', fill='#173451')
    d.text((36, 900), 'Preview only: launcher / Home Screen / Finder device rendering is not verified here.', fill='#526479')
    save(sheet, DESIGN / 'preview.png', rgb=True)


def check():
    checked = 0
    for platform in ('ios', 'macos'):
        for path, size in catalog(platform):
            with Image.open(path) as im:
                assert im.size == (size, size), path
                assert im.info.get('icc_profile'), ('missing sRGB', path)
                if platform == 'ios':
                    assert im.mode == 'RGB', path
                    assert all(im.getpixel(p) != (255, 255, 255) for p in ((0, 0), (size - 1, size - 1))), path
                else:
                    assert im.mode == 'RGBA' and im.getpixel((0, 0))[3] == 0, path
            checked += 1
    for density, scale in DENSITIES:
        for folder, name, size in ((f'mipmap-{density}', 'ic_launcher', round(48 * scale)), (f'drawable-{density}', 'ic_launcher_foreground', round(108 * scale))):
            with Image.open(RES / folder / (name + '.png')) as im:
                assert im.size == (size, size)
                if name.endswith('foreground'):
                    assert im.mode == 'RGBA' and im.getpixel((0, 0))[3] == 0
            checked += 1
    androidns = '{http://schemas.android.com/apk/res/android}'
    for path in (RES / 'drawable').glob('ic_launcher*.xml'):
        ET.parse(path)
    for api in (26, 33):
        doc = ET.parse(RES / f'mipmap-anydpi-v{api}/ic_launcher.xml').getroot()
        assert len(doc) == (3 if api == 33 else 2)
        for child in doc:
            name = child.attrib[androidns + 'drawable'].split('/')[-1]
            assert list(RES.glob('drawable*/' + name + '.*')), name
    for name in ('master', 'foreground', 'background', 'monochrome'):
        ET.parse(DESIGN / (name + '.svg'))
    # All opaque geometry (including antialiased edge at > 50%) must fit 66dp circle.
    for name in ('foreground', 'monochrome'):
        alpha = render(svg(name, adaptive=True), 432).getchannel('A')
        points = [(x, y) for y in range(432) for x in range(432) if alpha.getpixel((x, y)) > 127]
        radius = max(((x + .5 - 216) ** 2 + (y + .5 - 216) ** 2) ** .5 / 4 for x, y in points)
        assert radius < 33, (name, radius)
        print(f'{name}: outermost visible pixel radius {radius:.2f}dp < 33dp')
    # Check the actual transparent A stem and underline, not just an all-solid silhouette.
    mono = render(svg('monochrome'), 1024).getchannel('A')
    assert mono.getpixel((462, 344)) == 0
    assert mono.getpixel((460, 613)) == 0
    assert mono.getpixel((470, 414)) == 255  # triangle counter remains a filled island
    print(f'PASS: {checked} catalog/density entries, XML references, sRGB, alpha, holes, safe circle')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if not args.check:
        generate()
    check()
