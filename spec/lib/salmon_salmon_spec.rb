#   Copyright (c) 2010, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3.  See
#   the COPYRIGHT file.

require 'spec_helper'

describe Salmon do
  let(:user){Factory.create :user}
  let(:post){ user.post :status_message, :message => "hi", :to => user.aspect(:name => "sdg").id }

  describe '#create' do
    let!(:created_salmon) {Salmon::SalmonSlap.create(user, post.to_diaspora_xml)}

    it 'has data in the magic envelope' do
      created_salmon.magic_sig.data.should_not be nil
    end
    
    it 'has no parsed_data' do
      created_salmon.parsed_data.should be nil
    end
    
    it 'sets aes and iv key' do
      created_salmon.aes_key.should_not be nil
      created_salmon.iv.should_not be nil
    end

    it 'should make the data in the signature encrypted with that key' do
      key_hash = {'key' => created_salmon.aes_key, 'iv' => created_salmon.iv}
      decoded_string = Salmon::SalmonSlap.decode64url(created_salmon.magic_sig.data)
      user.aes_decrypt(decoded_string, key_hash).to_s.should == post.to_diaspora_xml.to_s
    end
  end

  context 'round trip' do
    before do
      @sent_salmon = Salmon::SalmonSlap.create(user, post.to_diaspora_xml)
      @parsed_salmon = Salmon::SalmonSlap.parse @sent_salmon.to_xml
      stub_success("tom@tom.joindiaspora.com")
    end


    it 'should verify the signature on a roundtrip' do

      @sent_salmon.magic_sig.data.should == @parsed_salmon.magic_sig.data

      @sent_salmon.magic_sig.sig.should == @parsed_salmon.magic_sig.sig
      @sent_salmon.magic_sig.signable_string.should == @parsed_salmon.magic_sig.signable_string

      @parsed_salmon.verified_for_key?(OpenSSL::PKey::RSA.new(user.exported_key)).should be true
      @sent_salmon.verified_for_key?(OpenSSL::PKey::RSA.new(user.exported_key)).should be true
    end

    it 'should return the data so it can be "received"' do

      xml = post.to_diaspora_xml

      @parsed_salmon.parsed_data.should == xml
    end

    it 'should parse out the authors diaspora_handle' do
      @parsed_salmon.author_email.should == user.person.diaspora_handle

    end

    it 'should reference a local author' do
      @parsed_salmon.author.should == user.person
    end

    it 'should reference a remote author' do
      @parsed_salmon.author_email = 'tom@tom.joindiaspora.com'
      @parsed_salmon.author.public_key.should_not be_nil
    end

    it 'should fail to reference a nonexistent remote author' do
      @parsed_salmon.author_email = 'idsfug@difgubhpsduh.rgd'
      proc {
        Redfinger.stub(:finger).and_return(nil) #Redfinger returns nil when there is no profile
        @parsed_salmon.author.real_name}.should raise_error /No webfinger profile found/
    end

  end
end
