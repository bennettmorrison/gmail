require 'spec_helper'
require 'gmail/client/imap_extensions'
describe "GmailImapExtensions" do 
  before(:all) { GmailImapExtensions.patch_net_imap_response_parser }
  let(:parser) { Net::IMAP::ResponseParser.new }

  describe 'X-GM-MSGID' do
    context 'when given a response with a well-formed X-GM-MSGID' do
      let(:response)  { "* 2 FETCH (X-GM-MSGID 1427748806289683814)\r\n" }
      it 'processes the ID' do
        msg = parser.parse response
        msg.data.attr['X-GM-MSGID'].should eq 1427748806289683814
      end
    end
    context 'when given a response with a negative/malformed X-GM-MSGID' do
      let(:response)  { "* 2 FETCH (X-GM-MSGID -1427748806289683814)\r\n" }
      it 'processes the ID' do
        msg = parser.parse response
        msg.data.attr['X-GM-MSGID'].should eq -1427748806289683814
      end
    end
  end

  describe 'X-GM-THRID' do
    context 'when given a response with a well-formed X-GM-THRID' do
      let(:response)  { "* 2 FETCH (X-GM-THRID 1427748806289683814)\r\n" }
      it 'processes the ID' do
        msg = parser.parse response
        msg.data.attr['X-GM-THRID'].should eq 1427748806289683814
      end
    end
    context 'when given a response with a negative/malformed X-GM-THRID' do
      let(:response)  { "* 2 FETCH (X-GM-THRID -1427748806289683814)\r\n" }
      it 'processes the ID' do
        msg = parser.parse response
        msg.data.attr['X-GM-THRID'].should eq -1427748806289683814
      end
    end
  end
end
