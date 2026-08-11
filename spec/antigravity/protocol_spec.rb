# frozen_string_literal: true

# Tests for hand-rolled protobuf encoding/decoding of the 2 stdio messages.
# These are UNIT tests — no harness needed.

RSpec.describe Antigravity::Protocol do
  describe '.encode_input_config' do
    it 'encodes InputConfig as a length-prefixed binary protobuf' do
      bytes = described_class.encode_input_config(
        storage_directory: '/tmp/agy-test',
        bind_address: 'localhost'
      )

      # First 4 bytes are little-endian uint32 length
      expect(bytes.bytesize).to be > 4
      declared_len = bytes[0..3].unpack1('V')
      expect(bytes.bytesize).to eq(declared_len + 4)
    end

    it 'includes client_info with language "ruby"' do
      bytes = described_class.encode_input_config(
        storage_directory: '/tmp/test'
      )
      # The protobuf payload should contain the string "ruby"
      payload = bytes[4..]
      expect(payload).to include('ruby')
    end
  end

  describe '.decode_output_config' do
    it 'decodes a length-prefixed OutputConfig binary' do
      # Manually build a minimal OutputConfig:
      # field 1 (int32 port=12345): varint tag=0x08, value=12345
      # field 2 (string api_key="secret"): tag=0x12, len=6, "secret"
      port_field = [0x08].pack('C') + encode_varint(12345)
      key_bytes = 'secret'.b
      key_field = [0x12].pack('C') + encode_varint(key_bytes.bytesize) + key_bytes
      payload = port_field + key_field
      framed = [payload.bytesize].pack('V') + payload

      result = described_class.decode_output_config(framed)
      expect(result[:port]).to eq(12345)
      expect(result[:api_key]).to eq('secret')
    end

    it 'raises ProtocolError on truncated data' do
      expect {
        described_class.decode_output_config("\x00\x00")
      }.to raise_error(Antigravity::ProtocolError)
    end
  end

  # Helper to produce varint bytes for building test fixtures
  def encode_varint(value)
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
end
