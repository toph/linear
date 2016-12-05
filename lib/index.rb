class Index
  class FileTooBigError < StandardError; end

  # Just use 64 bit positions. This should cover very
  # large files. Let's standardize on endianness just
  # in case index files end up getting shared cross arch.
  # Might as well go little endian, since most servers
  # are x86.
  GLYPH = "Q<".freeze
  SIZE = 8
  MAX = 256**SIZE

  def self.generate(filename, index_filename)
    # This really shouldn't happen with 64 uints.
    file_size = File.size(filename)
    raise FileTooBigError, file_size if file_size >= MAX

    open(index_filename, "w") do |index|
      position = 0

      open(filename) do |f|
        f.each_line do |line|
          bytes = [position].pack(GLYPH)
          index.write(bytes)

          position += line.bytesize
        end
      end
    end
  end

  def initialize(filename, index_filename)
    @file = open(filename)
    @index_file = open(index_filename)
    @limit = File.size(index_filename) / SIZE
  end

  def [](index)
    return nil if index >= @limit

    @index_file.pos = index * SIZE
    bytes = @index_file.read(SIZE)
    location, = bytes.unpack(GLYPH)

    @file.pos = location
    @file.readline
  end
end
