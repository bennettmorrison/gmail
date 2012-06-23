require 'spec_helper'

describe "A Gmail mailbox" do
  subject { Gmail::Mailbox }

  context "on initialize" do
    it "should set client and name" do
      within_gmail do |gmail|
        mailbox = subject.new(gmail, "TEST")
        mailbox.instance_variable_get("@gmail").should == gmail
        mailbox.name.should == "TEST"
      end
    end

    it "should work in INBOX by default" do
      within_gmail do |gmail|
        mailbox = subject.new(@gmail)
        mailbox.name.should == "INBOX"
      end
    end
  end

  context "instance" do
    it "should be able to count all emails" do
      mock_mailbox do |mailbox|
        mailbox.count.should > 0
      end
    end

    it "should be able to find messages" do
      mock_mailbox do |mailbox|
        message = mailbox.emails.first
        mailbox.emails(:all, :from => message.from.first.name) == message.from.first.name
      end
    end
    
    
    it "should be able to do a full text search of message bodies" do
      pending "This can wait..."
      #mock_mailbox do |mailbox|
      #  message = mailbox.emails.first
      #  body = message.parts.blank? ? message.body.decoded : message.parts[0].body.decoded
      #  emails = mailbox.emails(:search => body.split(' ').first)
      #  emails.size.should > 0
      #end
    end
    
    describe ":include" do
      it "eager loads message bodies" do
        mock_mailbox do |mailbox|
          start_time = Time.now
          mailbox.emails(:all, :include => :message).first.message.should be
        end
      end
      
      it "eager loads message envelopes" do
        mock_mailbox do |mailbox|
          mailbox.emails(:all, :include => :envelope).first.envelope.should be
        end
      end
    
      it "eager loads message bodies and envelopes" do
        mock_mailbox do |mailbox|
          mail = mailbox.emails(:all, :include => :both).first
          mail.envelope.should be
          mail.message.should be
        end
      end
      
    end
  end
end
