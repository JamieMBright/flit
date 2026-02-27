// ignore_for_file: avoid_print
//
// Shore Distance Texture Generator
//
// Reads a heightmap image and produces a grayscale shore-distance field PNG.
// For each ocean pixel (elevation below threshold), computes the distance
// to the nearest land pixel using a BFS-based distance transform.
//
// Output: 0 = at the shoreline, 255 = far from any shore.
//
// Usage:
//   dart run scripts/generate_shore_distance.dart <input_heightmap> <output_png> [threshold]
//
// Arguments:
//   input_heightmap - Path to the input heightmap image (PNG).
//   output_png      - Path to write the output shore distance image.
//   threshold       - (Optional) Grayscale cutoff for land vs ocean.
//                     Pixels with value >= threshold are land. Default: 128.
//
// Example:
//   dart run scripts/generate_shore_distance.dart \
//     assets/images/heightmap.png \
//     assets/images/shore_distance.png \
//     128

import 'dart:io';
import 'dart:typed_data';

void main(List<String> args) {
  if (args.length < 2) {
    print(
      'Usage: dart run scripts/generate_shore_distance.dart '
      '<input_heightmap> <output_png> [threshold]',
    );
    print('');
    print('  input_heightmap  Path to input heightmap PNG');
    print('  output_png       Path to output shore distance PNG');
    print('  threshold        Land/ocean cutoff (0-255, default: 128)');
    exit(1);
  }

  final inputPath = args[0];
  final outputPath = args[1];
  final threshold = args.length >= 3 ? int.parse(args[2]) : 128;

  print('Shore Distance Field Generator');
  print('  Input:     $inputPath');
  print('  Output:    $outputPath');
  print('  Threshold: $threshold');
  print('');

  // Read the input file bytes.
  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    print('Error: Input file not found: $inputPath');
    exit(1);
  }

  final inputBytes = inputFile.readAsBytesSync();

  // Decode the PNG manually.
  // Since this runs outside Flutter (no dart:ui), we use a minimal
  // approach: read the raw PNG data. For simplicity we expect
  // uncompressed or zlib-compressed 8-bit grayscale or RGBA PNG.
  //
  // NOTE: For production use, add the `image` package to pubspec.yaml
  // and use it here. This implementation provides the algorithmic
  // skeleton; the actual PNG codec would require an external library
  // or a more complete implementation.

  print('Decoding input image...');
  final image = _decodePng(inputBytes);
  if (image == null) {
    print('Error: Failed to decode PNG. Ensure the file is a valid PNG.');
    print('');
    print('For full PNG support, add the "image" package to pubspec.yaml:');
    print('  dart pub add image');
    print('Then update this script to use package:image/image.dart.');
    exit(1);
  }

  final width = image.width;
  final height = image.height;
  print('  Image size: ${width}x$height');

  // Build a boolean grid: true = land, false = ocean.
  final isLand = List<bool>.filled(width * height, false);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final idx = y * width + x;
      isLand[idx] = image.getGray(x, y) >= threshold;
    }
  }

  // Count land and ocean pixels.
  final landCount = isLand.where((v) => v).length;
  final oceanCount = isLand.length - landCount;
  print('  Land pixels:  $landCount');
  print('  Ocean pixels: $oceanCount');

  if (landCount == 0) {
    print('Warning: No land pixels found. Output will be all white (255).');
  }
  if (oceanCount == 0) {
    print('Warning: No ocean pixels found. Output will be all black (0).');
  }

  // BFS-based distance transform from shore.
  // "Shore" pixels are ocean pixels adjacent to at least one land pixel.
  print('Computing distance field (BFS)...');
  final dist = _computeShoreDistance(isLand, width, height);

  // Normalize distances to 0-255 range.
  // 0 = at shore, 255 = maximum distance from shore.
  var maxDist = 0.0;
  for (var i = 0; i < dist.length; i++) {
    if (!isLand[i] && dist[i] > maxDist && dist[i] < double.infinity) {
      maxDist = dist[i];
    }
  }
  print('  Max shore distance: ${maxDist.toStringAsFixed(1)} pixels');

  // Build output grayscale image.
  final output = Uint8List(width * height);
  for (var i = 0; i < dist.length; i++) {
    if (isLand[i]) {
      // Land pixels get 0 (black) - they are "at the shore" or on land.
      output[i] = 0;
    } else if (maxDist > 0) {
      output[i] = ((dist[i] / maxDist) * 255.0).round().clamp(0, 255);
    } else {
      output[i] = 0;
    }
  }

  // Encode as raw grayscale PNG.
  print('Encoding output PNG...');
  final pngBytes = _encodePngGrayscale(output, width, height);

  // Write output.
  final outputFile = File(outputPath);
  outputFile.parent.createSync(recursive: true);
  outputFile.writeAsBytesSync(pngBytes);
  print('  Written: $outputPath (${pngBytes.length} bytes)');
  print('Done.');
}

/// Compute the BFS distance from each ocean pixel to the nearest shore.
///
/// Shore pixels are ocean pixels that are 4-connected to at least one
/// land pixel. Returns a list of distances (one per pixel). Land pixels
/// have distance 0. Ocean pixels far from land have large distances.
List<double> _computeShoreDistance(List<bool> isLand, int width, int height) {
  final n = width * height;
  final dist = List<double>.filled(n, double.infinity);

  // Queue stores pixel indices. Start by seeding all shore ocean pixels.
  final queue = <int>[];

  // 4-connected neighbor offsets.
  final dx = [0, 0, -1, 1];
  final dy = [-1, 1, 0, 0];

  // Find shore pixels: ocean pixels adjacent to land.
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final idx = y * width + x;

      if (isLand[idx]) {
        dist[idx] = 0.0;
        continue;
      }

      // Check if this ocean pixel neighbors any land pixel.
      var isShore = false;
      for (var d = 0; d < 4; d++) {
        final nx = x + dx[d];
        final ny = y + dy[d];
        if (nx >= 0 && nx < width && ny >= 0 && ny < height) {
          if (isLand[ny * width + nx]) {
            isShore = true;
            break;
          }
        }
      }

      if (isShore) {
        dist[idx] = 0.0;
        queue.add(idx);
      }
    }
  }

  // BFS expansion from all shore pixels simultaneously.
  var head = 0;
  while (head < queue.length) {
    final idx = queue[head++];
    final x = idx % width;
    final y = idx ~/ width;
    final currentDist = dist[idx];

    for (var d = 0; d < 4; d++) {
      final nx = x + dx[d];
      final ny = y + dy[d];
      if (nx < 0 || nx >= width || ny < 0 || ny >= height) continue;

      final nIdx = ny * width + nx;
      if (isLand[nIdx]) continue;

      final newDist = currentDist + 1.0;
      if (newDist < dist[nIdx]) {
        dist[nIdx] = newDist;
        queue.add(nIdx);
      }
    }
  }

  return dist;
}

// ─── Minimal PNG Codec ─────────────────────────────────────────────────
//
// These routines provide a basic PNG encoder/decoder that works without
// external packages. For production, consider using package:image.

/// Simple decoded image container.
class _RawImage {
  _RawImage(this.width, this.height, this.pixels);
  final int width;
  final int height;
  final Uint8List pixels; // grayscale values, row-major

  int getGray(int x, int y) => pixels[y * width + x];
}

/// Attempt to decode a PNG file into a grayscale image.
///
/// This is a simplified decoder that handles the most common PNG formats.
/// For full PNG support use the `image` package.
///
/// Returns null if decoding fails.
_RawImage? _decodePng(Uint8List bytes) {
  // Validate PNG signature.
  if (bytes.length < 8) return null;
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  for (var i = 0; i < 8; i++) {
    if (bytes[i] != signature[i]) return null;
  }

  // Parse chunks to find IHDR and IDAT.
  var offset = 8;
  int? width;
  int? height;
  int? colorType;
  int? bitDepth;
  final idatChunks = <Uint8List>[];

  while (offset + 8 <= bytes.length) {
    final length = _readUint32(bytes, offset);
    final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
    final dataStart = offset + 8;

    if (type == 'IHDR' && length >= 13) {
      width = _readUint32(bytes, dataStart);
      height = _readUint32(bytes, dataStart + 4);
      bitDepth = bytes[dataStart + 8];
      colorType = bytes[dataStart + 9];
    } else if (type == 'IDAT') {
      idatChunks.add(bytes.sublist(dataStart, dataStart + length));
    } else if (type == 'IEND') {
      break;
    }

    offset = dataStart + length + 4; // skip CRC
  }

  if (width == null || height == null || colorType == null) return null;
  if (idatChunks.isEmpty) return null;

  // Concatenate IDAT data and decompress.
  final compressedLen = idatChunks.fold<int>(0, (s, c) => s + c.length);
  final compressed = Uint8List(compressedLen);
  var pos = 0;
  for (final chunk in idatChunks) {
    compressed.setAll(pos, chunk);
    pos += chunk.length;
  }

  Uint8List decompressed;
  try {
    decompressed = zlib.decode(compressed) as Uint8List;
  } catch (_) {
    try {
      decompressed = Uint8List.fromList(zlib.decode(compressed));
    } catch (_) {
      return null;
    }
  }

  // Determine bytes per pixel.
  int bpp;
  switch (colorType) {
    case 0: // Grayscale
      bpp = (bitDepth! + 7) ~/ 8;
    case 2: // RGB
      bpp = 3 * ((bitDepth! + 7) ~/ 8);
    case 4: // Grayscale + Alpha
      bpp = 2 * ((bitDepth! + 7) ~/ 8);
    case 6: // RGBA
      bpp = 4 * ((bitDepth! + 7) ~/ 8);
    default:
      return null; // Unsupported color type (indexed, etc.)
  }

  final stride = width * bpp;
  final pixels = Uint8List(width * height);

  // Unfilter and convert to grayscale.
  var srcOffset = 0;
  final prevRow = Uint8List(stride);
  final currentRow = Uint8List(stride);

  for (var y = 0; y < height; y++) {
    if (srcOffset >= decompressed.length) break;
    final filterType = decompressed[srcOffset++];

    // Read raw scanline.
    for (var i = 0; i < stride && srcOffset < decompressed.length; i++) {
      currentRow[i] = decompressed[srcOffset++];
    }

    // Apply PNG filter.
    _unfilterRow(filterType, currentRow, prevRow, bpp);

    // Extract grayscale value for each pixel.
    for (var x = 0; x < width; x++) {
      final pixelOffset = x * bpp;
      int gray;
      switch (colorType) {
        case 0: // Grayscale
          gray = currentRow[pixelOffset];
        case 2: // RGB -> luminance
          final r = currentRow[pixelOffset];
          final g = currentRow[pixelOffset + 1];
          final b = currentRow[pixelOffset + 2];
          gray = ((r * 299 + g * 587 + b * 114) / 1000).round();
        case 4: // Grayscale + Alpha
          gray = currentRow[pixelOffset];
        case 6: // RGBA -> luminance
          final r = currentRow[pixelOffset];
          final g = currentRow[pixelOffset + 1];
          final b = currentRow[pixelOffset + 2];
          gray = ((r * 299 + g * 587 + b * 114) / 1000).round();
        default:
          gray = 0;
      }
      pixels[y * width + x] = gray.clamp(0, 255);
    }

    // Save current row as previous for next iteration.
    prevRow.setAll(0, currentRow);
  }

  return _RawImage(width, height, pixels);
}

/// Apply PNG row un-filtering in place.
void _unfilterRow(int filterType, Uint8List row, Uint8List prevRow, int bpp) {
  switch (filterType) {
    case 0: // None
      break;
    case 1: // Sub
      for (var i = bpp; i < row.length; i++) {
        row[i] = (row[i] + row[i - bpp]) & 0xFF;
      }
    case 2: // Up
      for (var i = 0; i < row.length; i++) {
        row[i] = (row[i] + prevRow[i]) & 0xFF;
      }
    case 3: // Average
      for (var i = 0; i < row.length; i++) {
        final a = i >= bpp ? row[i - bpp] : 0;
        final b = prevRow[i];
        row[i] = (row[i] + ((a + b) >> 1)) & 0xFF;
      }
    case 4: // Paeth
      for (var i = 0; i < row.length; i++) {
        final a = i >= bpp ? row[i - bpp] : 0;
        final b = prevRow[i];
        final c = i >= bpp ? prevRow[i - bpp] : 0;
        row[i] = (row[i] + _paethPredictor(a, b, c)) & 0xFF;
      }
  }
}

/// Paeth predictor function used in PNG filtering.
int _paethPredictor(int a, int b, int c) {
  final p = a + b - c;
  final pa = (p - a).abs();
  final pb = (p - b).abs();
  final pc = (p - c).abs();
  if (pa <= pb && pa <= pc) return a;
  if (pb <= pc) return b;
  return c;
}

/// Read a big-endian 32-bit unsigned integer from a byte list.
int _readUint32(Uint8List bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}

/// Encode a grayscale image as a minimal PNG.
Uint8List _encodePngGrayscale(Uint8List pixels, int width, int height) {
  final out = BytesBuilder();

  // PNG signature
  out.add([137, 80, 78, 71, 13, 10, 26, 10]);

  // IHDR chunk
  final ihdr = BytesBuilder();
  _writeUint32(ihdr, width);
  _writeUint32(ihdr, height);
  ihdr.addByte(8); // bit depth
  ihdr.addByte(0); // color type: grayscale
  ihdr.addByte(0); // compression
  ihdr.addByte(0); // filter
  ihdr.addByte(0); // interlace
  _writeChunk(out, 'IHDR', ihdr.toBytes());

  // IDAT chunk - build raw scanlines then zlib-compress.
  final raw = BytesBuilder();
  for (var y = 0; y < height; y++) {
    raw.addByte(0); // filter type: None
    raw.add(pixels.sublist(y * width, (y + 1) * width));
  }
  final compressed = zlib.encode(raw.toBytes());
  _writeChunk(out, 'IDAT', Uint8List.fromList(compressed));

  // IEND chunk
  _writeChunk(out, 'IEND', Uint8List(0));

  return Uint8List.fromList(out.toBytes());
}

/// Write a PNG chunk (length + type + data + CRC).
void _writeChunk(BytesBuilder out, String type, Uint8List data) {
  // Length (4 bytes, big-endian)
  final lengthBytes = ByteData(4)..setUint32(0, data.length);
  out.add(lengthBytes.buffer.asUint8List());

  // Type (4 ASCII bytes)
  final typeBytes = type.codeUnits;
  out.add(typeBytes);

  // Data
  out.add(data);

  // CRC-32 over type + data
  final crcData = Uint8List(4 + data.length);
  crcData.setAll(0, typeBytes);
  crcData.setAll(4, data);
  final crc = _crc32(crcData);
  final crcBytes = ByteData(4)..setUint32(0, crc);
  out.add(crcBytes.buffer.asUint8List());
}

/// Write a 32-bit big-endian unsigned integer to a BytesBuilder.
void _writeUint32(BytesBuilder out, int value) {
  out.addByte((value >> 24) & 0xFF);
  out.addByte((value >> 16) & 0xFF);
  out.addByte((value >> 8) & 0xFF);
  out.addByte(value & 0xFF);
}

/// CRC-32 lookup table (initialized lazily).
final List<int> _crc32Table = _buildCrc32Table();

List<int> _buildCrc32Table() {
  final table = List<int>.filled(256, 0);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      if ((c & 1) != 0) {
        c = 0xEDB88320 ^ (c >> 1);
      } else {
        c = c >> 1;
      }
    }
    table[n] = c;
  }
  return table;
}

/// Compute CRC-32 checksum of the given bytes.
int _crc32(Uint8List bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc = _crc32Table[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}

/// zlib codec from dart:io.
final zlib = ZLibCodec();
