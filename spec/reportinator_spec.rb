require 'spec_helper'
require 'ceedling/reportinator'

describe Reportinator do
  before(:each) do
    @rp = described_class.new
  end
 
  describe '#generate_banner' do
    it 'generates a banner with a width based on a string' do
      expect(@rp.generate_banner("Hello world!")).to eq("------------\nHello world!\n------------\n")
    end

    it 'generates a banner with a fixed width' do
      expect(@rp.generate_banner("Hello world!", 3)).to eq("---\nHello world!\n---\n")
    end
  end

end
