#!/usr/bin/env python3
"""Generate public synthetic OCR/codec fixtures, then verify production paths.
Requires Pillow and ffmpeg with libx264 and libx265. No real card is read.
Usage: python3 scripts/verify-observed-video.py /absolute/scratch/output
"""
import os
from pathlib import Path
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont

root = Path(sys.argv[1]).resolve()
root.mkdir(parents=True, exist_ok=False)
for label, text in [('a329t', 'VIOFO A329T'), ('a329s', 'VIOFO A329S'), ('a329tc', 'VIOFO A329TC'), ('a329tw', 'VIOFO A329TW'), ('unmarked', '')]:
    folder = root / label / 'DCIM/Movie'
    folder.mkdir(parents=True)
    image = Image.new('RGB', (1280, 720), 'black')
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf', 42)
    draw.text((440, 658), text, font=font, fill='white')
    image_path = root / f'{label}.png'
    image.save(image_path)
    for index, codec in enumerate(['libx264', 'libx265']):
        name = f'2030_0101_12000{index}_00000{index+1}F.MP4'
        command = ['ffmpeg', '-v', 'error', '-loop', '1', '-i', str(image_path), '-t', '2', '-r', '10']
        command += ['-c:v', codec, '-pix_fmt', 'yuv420p', '-tag:v', 'hvc1' if codec == 'libx265' else 'avc1']
        if codec == 'libx265':
            command += ['-x265-params', 'log-level=error']
        subprocess.run(command + [str(folder / name)], check=True)
        subprocess.run(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=codec_name', '-of', 'json', str(folder / name)], check=True)
multiplex = root / 'multitrack/DCIM/Movie'
multiplex.mkdir(parents=True)
inputs = sorted((root / 'unmarked/DCIM/Movie').glob('*.MP4'))
subprocess.run(['ffmpeg', '-v', 'error', '-i', str(inputs[0]), '-i', str(inputs[1]), '-map', '0:v:0', '-map', '1:v:0', '-c', 'copy', str(multiplex / '2030_0101_120000_000001F.MP4')], check=True)
env = dict(os.environ, DASHCAM_SYNTHETIC_VIDEO_FIXTURES=str(root))
subprocess.run(['swift', 'run', 'DashcamOffloader', '--verify'], env=env, check=True)
