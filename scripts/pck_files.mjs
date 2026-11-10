// Lists what an exported Godot pack contains: node scripts/pck_files.mjs <file.pck|file.zip> [text]
// prints the paths (only those containing the text). A zip is searched for the pack inside it,
// as the macOS export writes it. build.mjs uses this to check a build.
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { inflateRawSync } from 'node:zlib';

// Pack formats 3 and 4 (Godot 4.4 and later): the header names where the directory starts.
const FLAGS_AT = 20;
const DIRECTORY_ENCRYPTED = 1;
const DIRECTORY_OFFSET_AT = 32;
// After each path: offset and size (8 bytes each), an MD5 (16) and the file's flags (4).
const ENTRY_TAIL = 36;

/** The paths of all files in the pack, relative to res://. */
export function pckFiles(path) {
  const pack = path.endsWith('.zip') ? packInZip(path) : readFileSync(path);
  if (pack.toString('latin1', 0, 4) !== 'GDPC') throw new Error(`${path} is not a Godot pack`);
  const format = pack.readUInt32LE(4);
  if (format < 3) throw new Error(`${path}: pack format ${format} is older than Godot 4.4 writes`);
  if (pack.readUInt32LE(FLAGS_AT) & DIRECTORY_ENCRYPTED) throw new Error(`${path}: the directory is encrypted`);
  let at = Number(pack.readBigUInt64LE(DIRECTORY_OFFSET_AT));
  const paths = [];
  for (let left = pack.readUInt32LE(at); left > 0; left--) {
    const length = pack.readUInt32LE(at + 4);
    // Paths are padded with zero bytes to a multiple of four.
    paths.push(pack.toString('utf8', at + 8, at + 8 + length).replace(/\0+$/, ''));
    at += 4 + length + ENTRY_TAIL;
  }
  return paths;
}

// Walks the zip's central directory to the first .pck and unpacks it.
function packInZip(path) {
  const zip = readFileSync(path);
  const end = zip.lastIndexOf(Buffer.from('PK\x05\x06', 'latin1'));
  if (end < 0) throw new Error(`${path} is not a zip file`);
  let at = zip.readUInt32LE(end + 16);
  for (let left = zip.readUInt16LE(end + 10); left > 0; left--) {
    const nameLength = zip.readUInt16LE(at + 28);
    if (zip.toString('utf8', at + 46, at + 46 + nameLength).endsWith('.pck')) {
      const local = zip.readUInt32LE(at + 42);
      const data = local + 30 + zip.readUInt16LE(local + 26) + zip.readUInt16LE(local + 28);
      const bytes = zip.subarray(data, data + zip.readUInt32LE(at + 20));
      return zip.readUInt16LE(at + 10) === 0 ? bytes : inflateRawSync(bytes);
    }
    at += 46 + nameLength + zip.readUInt16LE(at + 30) + zip.readUInt16LE(at + 32);
  }
  throw new Error(`${path} holds no .pck`);
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const [pack, text = ''] = process.argv.slice(2);
  if (!pack) {
    console.error('usage: node scripts/pck_files.mjs <file.pck|file.zip> [text]');
    process.exit(1);
  }
  const paths = pckFiles(pack).filter((path) => path.includes(text)).sort();
  console.log(paths.join('\n'));
  console.error(`${paths.length} file(s)`);
}
