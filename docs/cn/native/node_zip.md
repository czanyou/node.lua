# 压缩解缩 (zip)

实现 zip 压缩文件的读写

通过 `require('miniz')` 调用。

## new_reader

    new_reader(filename, flags)

创建一个 Reader

- filename {string} ZIP 文件名
- flags {number}
  - MZ_ZIP_FLAG_DO_NOT_SORT_CENTRAL_DIRECTORY = 0x0800

### reader:close

    reader:close()

关闭这个 Reader

### reader:extract

    reader:extract(index, flags)

解压指定索引的文件, 并返回解压后的文件内容

- index {number} 文件索引
- flags {number}
  - MZ_ZIP_FLAG_COMPRESSED_DATA = 0x0400 直接返回压缩的数据(不进行解压)

### reader:get_filename

    reader:get_filename(index)

返回指定索引位置的文件的名称

- index {number} 文件索引

### reader:get_num_files

    reader:get_num_files()

返回这个 Reader 打包的压缩包包含的文件以及目录的数目.

### reader:is_directory

    reader:is_directory(index)

- index {number} 文件索引

指出指定的索引的文件是否是一个目录

### reader:locate_file

    reader:locate_file(path, flags)

返回指定的文件名的文件的索引位置

- path {string} 文件路径名
- flags {number}
  - MZ_ZIP_FLAG_CASE_SENSITIVE = 0x0100,
  - MZ_ZIP_FLAG_IGNORE_PATH = 0x0200,

### reader:stat

    reader:stat(index)

返回指定索引的文件的统计信息, 如压缩大小, 原文件大小等信息

- index {number} 文件索引

返回:

- index
- version_made_by
- version_needed
- bit_flag
- method
- time
- crc32
- comp_size
- uncomp_size
- internal_attr
- external_attr
- filename
- comment

## new_writer

    new_writer(reserve, initialSize)

创建一个 Writer

- reserve {number} 文件开始位置保留的长度, 默认为 0
- initialSize {number} 初始化时预分配的空间大小, 默认为 128 * 1024

### writer:add

    writer:add(path, data, flags)

添加一个文件到压缩包中

- path {string} 相对路径
- data {string} 文件内容
- flags {number}

### writer:add_from_zip

    writer:add_from_zip(source, index)

- source {reader Object} ZIP 文件 Reader 对象
- index {number} 文件索引

直接从指定的 Reader 中读取一个文件并添加到这个 Writer 中.

### writer:close

    writer:close()

关闭这个 Writer

### writer:finalize

    writer:finalize()

## deflate

    deflate(data, flags)

deflate

解压

- data {string} 要解压的数据包
- flags  Decompression flags used by tinfl_decompress().
  - 1: TINFL_FLAG_PARSE_ZLIB_HEADER: If set, the input has a valid zlib header and ends with an adler32 checksum (it's a valid zlib stream). Otherwise, the input is a raw deflate stream.
  - 2: TINFL_FLAG_HAS_MORE_INPUT: If set, there are more input bytes available beyond the end of the supplied input buffer. If clear, the input buffer contains all remaining input.
  - 4: TINFL_FLAG_USING_NON_WRAPPING_OUTPUT_BUF: If set, the output buffer is large enough to hold the entire decompressed stream. If clear, the output buffer is at least the size of the dictionary (typically 32KB).
  - 8: TINFL_FLAG_COMPUTE_ADLER32: Force adler-32 checksum computation of the decompressed bytes.

## inflate

    inflate(data, flags)

inflate

压缩

- data {string} 要压缩的数据包
- flags
  - 0x01000: TDEFL_WRITE_ZLIB_HEADER: If set, the compressor outputs a zlib header before the deflate data, and the Adler-32 of the source data at the end. Otherwise, you'll get raw deflate data.
  - 0x02000: TDEFL_COMPUTE_ADLER32: Always compute the adler-32 of the input data (even when not writing zlib headers).
  - 0x04000: TDEFL_GREEDY_PARSING_FLAG: Set to use faster greedy parsing, instead of more efficient lazy parsing.
  - 0x08000: TDEFL_NONDETERMINISTIC_PARSING_FLAG: Enable to decrease the compressor's initialization time to the minimum, but the output may vary from run to run given the same input (depending on the contents of memory).
  - 0x10000: TDEFL_RLE_MATCHES: Only look for RLE matches (matches with a distance of 1)
  - 0x20000: TDEFL_FILTER_MATCHES: Discards matches <= 5 chars if enabled.
  - 0x40000: TDEFL_FORCE_ALL_STATIC_BLOCKS: Disable usage of optimized Huffman tables.
  - 0x80000: TDEFL_FORCE_ALL_RAW_BLOCKS: Only use raw (uncompressed) deflate blocks.
  - The low 12 bits are reserved to control the max # of hash probes per dictionary lookup (see TDEFL_MAX_PROBES_MASK).
