# frozen_string_literal: true

require_relative 'version'

module Antigravity
  # Hand-rolled protobuf encoding/decoding for the 2 stdio handshake messages:
  #   InputConfig  (SDK → localharness via stdin)
  #   OutputConfig (localharness → SDK via stdout)
  #
  # Uses raw protobuf wire format to avoid the google-protobuf gem dependency.
  # See: https://github.com/palladius/antigravity-ruby-sdk/issues/7
  #
  # Wire format reference: https://protobuf.dev/programming-guides/encoding/
  #   Varint:           wire type 0, tag = (field_number << 3) | 0
  #   Length-delimited: wire type 2, tag = (field_number << 3) | 2
  class Protocol
    # --- Encoding: InputConfig ---
    # message InputConfig {
    #   string storage_directory = 1;
    #   uint32 port = 2;           # optional, we leave 0
    #   string bind_address = 3;   # default "localhost"
    #   ClientInfo client_info = 4;
    #   map<string, string> env = 5;
    # }
    # message ClientInfo {
    #   string language = 1;
    #   string version = 2;
    #   string language_version = 3;
    #   string os = 4;
    #   string os_version = 5;
    # }
    def self.encode_input_config(storage_directory:, bind_address: 'localhost', env: {})
      buf = ''.b

      # field 1: storage_directory (string)
      buf << encode_string_field(1, storage_directory)

      # field 3: bind_address (string, default "localhost")
      buf << encode_string_field(3, bind_address)

      # field 4: client_info (embedded message)
      client_info = encode_client_info
      buf << encode_bytes_field(4, client_info)

      # field 5: env map entries (each is an embedded message with key=1, value=2)
      env.each do |key, value|
        entry = encode_string_field(1, key.to_s) + encode_string_field(2, value.to_s)
        buf << encode_bytes_field(5, entry)
      end

      # Length-prefix: 4-byte little-endian uint32
      [buf.bytesize].pack('V') + buf
    end

    # --- Decoding: OutputConfig ---
    # message OutputConfig {
    #   int32  port = 1;
    #   string api_key = 2;
    # }
    def self.decode_output_config(data)
      raise ProtocolError, 'Data too short for length prefix' if data.bytesize < 4

      declared_len = data[0..3].unpack1('V')
      payload = data[4..]

      raise ProtocolError, "Truncated payload: expected #{declared_len}, got #{payload&.bytesize || 0}" if payload.nil? || payload.bytesize < declared_len

      result = { port: 0, api_key: '' }
      pos = 0

      while pos < declared_len
        tag_byte, new_pos = decode_varint(payload, pos)
        pos = new_pos
        field_number = tag_byte >> 3
        wire_type = tag_byte & 0x07

        case wire_type
        when 0 # varint
          value, pos = decode_varint(payload, pos)
          result[:port] = value if field_number == 1
        when 2 # length-delimited
          length, pos = decode_varint(payload, pos)
          value = payload[pos, length]
          pos += length
          result[:api_key] = value.force_encoding('UTF-8') if field_number == 2
        else
          raise ProtocolError, "Unsupported wire type #{wire_type} at position #{pos}"
        end
      end

      result
    end

    # Read a length-prefixed frame from an IO (blocking).
    # Returns the raw payload bytes.
    def self.read_length_prefixed(io, timeout: 10)
      len_bytes = read_exactly(io, 4, timeout: timeout)
      raise ProtocolError, 'EOF reading length prefix' unless len_bytes&.bytesize == 4

      payload_len = len_bytes.unpack1('V')
      raise ProtocolError, "Unreasonable payload length: #{payload_len}" if payload_len > 1_000_000

      frame = [payload_len].pack('V') + read_exactly(io, payload_len, timeout: timeout)
      frame
    end

    class << self
      private

      def encode_client_info
        buf = ''.b
        buf << encode_string_field(1, 'ruby')
        buf << encode_string_field(2, Antigravity::VERSION)
        buf << encode_string_field(3, RUBY_VERSION)
        buf << encode_string_field(4, ruby_platform_os)
        buf << encode_string_field(5, RUBY_PLATFORM)
        buf
      end

      def ruby_platform_os
        case RUBY_PLATFORM
        when /darwin/i then 'macos'
        when /linux/i  then 'linux'
        when /win/i    then 'windows'
        else RUBY_PLATFORM
        end
      end

      # Encode a string field: tag + varint length + UTF-8 bytes
      def encode_string_field(field_number, value)
        encode_bytes_field(field_number, value.to_s.encode('UTF-8').b)
      end

      # Encode a length-delimited field: tag + varint length + raw bytes
      def encode_bytes_field(field_number, bytes)
        tag = (field_number << 3) | 2 # wire type 2 = length-delimited
        encode_varint_bytes(tag) + encode_varint_bytes(bytes.bytesize) + bytes
      end

      # Encode an integer as varint bytes
      def encode_varint_bytes(value)
        bytes = []
        loop do
          byte = value & 0x7F
          value >>= 7
          byte |= 0x80 if value > 0
          bytes << byte
          break if value == 0
        end
        bytes.pack('C*')
      end

      # Decode a varint starting at position, returns [value, new_position]
      def decode_varint(data, pos)
        result = 0
        shift = 0
        loop do
          raise ProtocolError, "Varint extends past end of data at pos #{pos}" if pos >= data.bytesize

          byte = data.getbyte(pos)
          pos += 1
          result |= (byte & 0x7F) << shift
          break if (byte & 0x80) == 0

          shift += 7
          raise ProtocolError, 'Varint too long' if shift >= 64
        end
        [result, pos]
      end

      # Read exactly n bytes from IO with timeout
      def read_exactly(io, n, timeout: 10)
        buf = ''.b
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
        while buf.bytesize < n
          remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
          raise ProtocolError, "Timeout reading #{n} bytes from harness" if remaining <= 0

          ready = IO.select([io], nil, nil, [remaining, 0.1].min)
          if ready
            chunk = io.read_nonblock(n - buf.bytesize, exception: false)
            case chunk
            when String then buf << chunk
            when :wait_readable then next
            when nil then raise ProtocolError, 'EOF while reading from harness'
            end
          end
        end
        buf
      end
    end
  end
end
