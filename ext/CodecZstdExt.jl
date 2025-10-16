module CodecZstdExt

using BEVE
using CodecZstd
using BEVE: to_beve, to_beve!, from_beve, deser_beve
import BEVE: to_beve_zstd, from_beve_zstd, write_beve_zstd_file, read_beve_zstd_file,
              deser_beve_zstd, deser_beve_zstd_file

const DEFAULT_ZSTD_LEVEL = 3
const _transcode = CodecZstd.TranscodingStreams.transcode

function to_beve_zstd(data;
                      buffer::Union{Nothing, IOBuffer} = nothing,
                      level::Integer = DEFAULT_ZSTD_LEVEL)::Vector{UInt8}
    raw = buffer === nothing ? to_beve(data) : to_beve!(buffer, data)
    return _transcode(ZstdCompressor(level = level), raw)
end

function from_beve_zstd(data::AbstractVector{UInt8};
                        preserve_matrices::Bool = false)
    decompressed = _transcode(ZstdDecompressor(), data)
    return from_beve(decompressed; preserve_matrices = preserve_matrices)
end

function write_beve_zstd_file(path::AbstractString,
                              data;
                              buffer::Union{Nothing, IOBuffer} = nothing,
                              level::Integer = DEFAULT_ZSTD_LEVEL)::Vector{UInt8}
    compressed = to_beve_zstd(data; buffer = buffer, level = level)
    open(path, "w") do io
        write(io, compressed)
    end
    return compressed
end

function read_beve_zstd_file(path::AbstractString;
                             preserve_matrices::Bool = false)
    compressed = read(path)
    return from_beve_zstd(compressed; preserve_matrices = preserve_matrices)
end

function deser_beve_zstd(::Type{T}, data::AbstractVector{UInt8};
                         error_on_missing_fields::Bool = false,
                         preserve_matrices::Bool = false) where T
    decompressed = _transcode(ZstdDecompressor(), data)
    return deser_beve(T, decompressed;
                      error_on_missing_fields = error_on_missing_fields,
                      preserve_matrices = preserve_matrices)
end

function deser_beve_zstd_file(::Type{T}, path::AbstractString;
                              error_on_missing_fields::Bool = false,
                              preserve_matrices::Bool = false) where T
    compressed = read(path)
    return deser_beve_zstd(T, compressed;
                           error_on_missing_fields = error_on_missing_fields,
                           preserve_matrices = preserve_matrices)
end

end # module
