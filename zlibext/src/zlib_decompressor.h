#ifndef ZLIB_DECOMPRESSOR_H
#define ZLIB_DECOMPRESSOR_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>

#include <zlib.h>

namespace godot {

class ZlibDecompressor : public RefCounted {
    GDCLASS(ZlibDecompressor, RefCounted)

private:
    z_stream strm;
    bool initialized;
    PackedByteArray output_buffer; // temporary storage for decompressed data

protected:
    static void _bind_methods();

public:
    ZlibDecompressor();
    ~ZlibDecompressor();

    // Initialize the zlib stream (call before feeding data)
    Error start_decompression();

    // Feed compressed data. Returns OK on success, error code otherwise.
    Error feed_data(const PackedByteArray &data);

    // Read all currently decompressed bytes (call after a flush is detected)
    PackedByteArray read_decompressed();

    // Close the stream and free resources
    void finish();
};

} // namespace godot

#endif // ZLIB_DECOMPRESSOR_H
