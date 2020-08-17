require 'rails_helper'

RSpec.describe InMemory::Util do
  let(:klass) { Class.new { extend InMemory::Util } }

  describe '.parse_json' do
    subject { klass.parse_json({a: 1}.to_json) }
    it { is_expected.to satisfy { |result| result[:a] == 1 } }
  end

  describe '.compress' do
    subject { klass.compress('a') }
    it { is_expected.to be_truthy }
  end

  describe '.decompress' do
    let(:data) { Base64.encode64(Zlib::Deflate.deflate('abc')) }
    subject { klass.decompress(data) }
    it { is_expected.to eq('abc') }
  end
end
