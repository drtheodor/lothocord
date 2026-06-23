#include "zlib_decompressor.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

ZlibDecompressor::ZlibDecompressor() : initialized(false) {
    // Initialize z_stream structure
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.avail_in = 0;
    strm.next_in = Z_NULL;
}

ZlibDecompressor::~ZlibDecompressor() {
    finish();
}

Error ZlibDecompressor::start_decompression() {
    if (initialized) {
        // Already initialized, maybe we should finish first?
        // For simplicity, we'll return an error.
        return ERR_ALREADY_EXISTS;
    }

    // Initialize inflate for automatic header detection (zlib or gzip)
    // windowBits = 15 + 32 means "detect zlib or gzip header automatically"
    int ret = inflateInit2(&strm, 15 + 32);
    if (ret != Z_OK) {
        UtilityFunctions::print("inflateInit2 failed: ", ret);
        return FAILED;
    }
    initialized = true;
    return OK;
}

Error ZlibDecompressor::feed_data(const PackedByteArray &data) {
    if (!initialized) {
        return ERR_UNCONFIGURED;
    }

    // Set input
    strm.avail_in = data.size();
    // next_in must be non-const, but Bytef is unsigned char*
    strm.next_in = (Bytef *)data.ptr(); // const cast – safe because zlib doesn't modify it

    // Decompress until no more input or output available
    int ret;
    do {
        // Prepare output buffer
        unsigned char out[16384]; // 16 KB chunk
        strm.avail_out = sizeof(out);
        strm.next_out = out;

        ret = inflate(&strm, Z_SYNC_FLUSH); // Use Z_SYNC_FLUSH to align with Discord's flush points

        if (ret != Z_OK && ret != Z_STREAM_END && ret != Z_BUF_ERROR) {
            UtilityFunctions::print("inflate error: ", ret);
            return FAILED;
        }

        // Append any produced output to our buffer
        int produced = sizeof(out) - strm.avail_out;
        if (produced > 0) {
            PackedByteArray chunk;
            chunk.resize(produced);
            memcpy(chunk.ptrw(), out, produced);
            output_buffer.append_array(chunk);
        }
    } while (strm.avail_in > 0 || (ret == Z_OK && strm.avail_out == 0));

    return OK;
}

PackedByteArray ZlibDecompressor::read_decompressed() {
    PackedByteArray result = output_buffer;
    output_buffer.clear();
    return result;
}

void ZlibDecompressor::finish() {
    if (initialized) {
        inflateEnd(&strm);
        initialized = false;
    }
    output_buffer.clear();
}

void ZlibDecompressor::_bind_methods() {
    ClassDB::bind_method(D_METHOD("start_decompression"), &ZlibDecompressor::start_decompression);
    ClassDB::bind_method(D_METHOD("feed_data", "data"), &ZlibDecompressor::feed_data);
    ClassDB::bind_method(D_METHOD("read_decompressed"), &ZlibDecompressor::read_decompressed);
    ClassDB::bind_method(D_METHOD("finish"), &ZlibDecompressor::finish);
}
