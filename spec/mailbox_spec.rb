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


    describe "#emails_in_batches" do
      it "should be able to find messages" do
        mock_mailbox do |mailbox|
          message = mailbox.emails_in_batches.first
          mailbox.emails_in_batches(:all, :from => message.from.first.name) == message.from.first.name
        end
      end

      it 'loads emails' do
        mock_mailbox do |mailbox|
          messages = mailbox.emails_in_batches(:all)
          messages.first.should be
        end
      end

      it 'accepts a batch size' do
        mock_mailbox do |mailbox|
          messages = mailbox.emails_in_batches(:all, :batch_size => 5)
          messages.first.should be
        end
      end

      it 'accepts a block' do
        mock_mailbox do |mailbox|
          messages = mailbox.emails_in_batches(:all, :batch_size => 5) do |batch|
            batch.size.should be
            batch
          end
        end
      end
    end

    describe "#emails" do
      it "should be able to find messages" do
        mock_mailbox do |mailbox|
          message = mailbox.emails.first
          mailbox.emails(:all, :from => message.from.first.name) == message.from.first.name
        end
      end

      it 'loads emails' do
        mock_mailbox do |mailbox|
          messages = mailbox.emails(:all)
          messages.first.should be
        end
      end

      it 'accepts a batch size' do
        mock_mailbox do |mailbox|
          messages = mailbox.emails(:all, :batch_size => 5)
          messages.first.should be
        end
      end

      it 'accepts a block' do
        mock_mailbox do |mailbox|
          messages = mailbox.emails(:all, :batch_size => 5) do |batch|
            batch.should be_an_instance_of Message
            batch
          end
        end
      end
    end

    describe ":include" do
      it "eager loads message bodies" do
        mock_mailbox do |mailbox|
          start_time = Time.now
          mailbox.emails(:all, :include => :message).first.instance_variable_get(:@message).should be
        end
      end

      it "eager loads message envelopes" do
        mock_mailbox do |mailbox|
          mailbox.emails(:all, :include => :envelope).first.instance_variable_get(:@envelope).should be
        end
      end

      it "eager loads message labels" do
        mock_mailbox do |mailbox|
          mailbox.emails(:all, :include => :labels).first.instance_variable_get(:@labels).should be
        end
      end

      it "eager loads message thread ids" do
        mock_mailbox do |mailbox|
          mailbox.emails(:all, :include => :thread).first.instance_variable_get(:@thread_id).should be
        end
      end

      it "eager loads message message ids" do
        mock_mailbox do |mailbox|
          mailbox.emails(:all, :include => :msgid).first.instance_variable_get(:@msg_id).should be
        end
      end

      it "eager loads multiple options" do
        mock_mailbox do |mailbox|
          mail = mailbox.emails(:all, :include => [:message, :envelope, :labels, :thread, :msgid]).first
          mail.instance_variable_get(:@envelope).should be
          mail.instance_variable_get(:@message).should be
          mail.instance_variable_get(:@labels).should be
          mail.instance_variable_get(:@thread_id).should be
          mail.instance_variable_get(:@msg_id).should be
        end
      end
    end

    #it "should be able to do a full text search of message bodies" do
    #end
  end
end
