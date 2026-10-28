// Preserve Windows branding independently of macOS artwork. Container conversion only.
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { join, resolve } from 'node:path';

const root = fileURLToPath(new URL('../../', import.meta.url));
const sizes = [16, 32, 64, 128, 256];
const files = [
  'icon_16x16.png', 'icon_32x32.png', 'icon_32x32@2x.png',
  'icon_128x128.png', 'icon_256x256.png',
];
const images = await Promise.all(files.map(file =>
  readFile(join(root, 'Windows/BrandSources/Ocean/AppIcon.iconset', file))));
const header = Buffer.alloc(6 + 16 * images.length);
header.writeUInt16LE(1, 2);
header.writeUInt16LE(images.length, 4);
let offset = header.length;
for (let i = 0; i < images.length; i++) {
  const entry = 6 + 16 * i;
  header[entry] = sizes[i] === 256 ? 0 : sizes[i];
  header[entry + 1] = header[entry];
  header.writeUInt16LE(1, entry + 4);
  header.writeUInt16LE(32, entry + 6);
  header.writeUInt32LE(images[i].length, entry + 8);
  header.writeUInt32LE(offset, entry + 12);
  offset += images[i].length;
}
const destination = resolve(root, 'Windows/Caeser.App/Assets');
await mkdir(destination, { recursive: true });
await writeFile(join(destination, 'Caeser.ico'), Buffer.concat([header, ...images]));
console.log('Caeser.ico: 5 tamanhos, usando os PNGs originais sem redesenhar.');
