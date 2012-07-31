require 'spec_helper'

describe "A Gmail message" do
  context "on initialize" do
    let(:mailbox) { Gmail::Mailbox }
    let(:message) { Gmail::Message.new(mailbox, 1) }
    subject { message }

    its(:uid)  { should be }
    its(:mailbox) { should be }
  end

  context "instance" do
    subject { Gmail::Mailbox }

    before(:all) do
      mock_client do |client|

        mock_mailbox { |mailbox| @mails = mailbox.fetch_uids.count }
        (9-@mails).times do
          client.deliver do
            to TEST_ACCOUNT[0]
            subject "Hello world!"
            body "Yeah, hello there!"
          end.should be_true
        end
      end
    end

    it "should be able to mark itself as read" do
      mock_mailbox do |mailbox|
        uid = mailbox.fetch_uids.first
        message = mailbox.emails(uid: uid).first
        expect { message.read! }.to_not raise_error
      end
    end

    it "should be able to mark itself as unread" do
      mock_mailbox do |mailbox|
        uid = mailbox.fetch_uids.first
        message = mailbox.emails(uid: uid).first
        expect { message.unread! }.to_not raise_error
      end
    end

    it "should be able to set star itself" do
      mock_mailbox do |mailbox|
        uid = mailbox.fetch_uids.first
        message = mailbox.emails(uid: uid).first
        expect { message.star! }.to_not raise_error
      end
    end

    it "should be able to unset stars" do
      mock_mailbox do |mailbox|
        uid = mailbox.fetch_uids.first
        message = mailbox.emails(uid: uid).first
        expect { message.unstar! }.to_not raise_error
      end
    end

    it "should be able to archive itself" do
      mock_mailbox do |mailbox|
        uid = mailbox.fetch_uids.first
        message = mailbox.emails(uid: uid).first
        expect { message.archive! }.to_not raise_error
      end
    end

    it "should be able to delete itself" do
      mock_mailbox do |mailbox|
        uid = mailbox.fetch_uids.first
        message = mailbox.emails(uid: uid).first
        expect { message.delete! }.to_not raise_error
      end
    end

    it "should be able to undelete itself" do
      mock_mailbox do |mailbox|
        uid = mailbox.fetch_uids.first
        message = mailbox.emails(uid: uid).first
        expect { message.undelete! }.to_not raise_error
      end
    end

    it "should be able to move itself to spam" do
      mock_mailbox do |mailbox|
        uid = mailbox.fetch_uids.first
        message = mailbox.emails(uid: uid).first
        expect { message.spam! }.to_not raise_error
      end
    end

    it "should be able to set given label" do
      mock_mailbox do |mailbox|
        uid = mailbox.fetch_uids.first
        message = mailbox.emails(uid: uid).first
        expect { message.label! "TEST" }.to_not raise_error
        message.labels
      end
    end

    it "should be able to mark itself with given flag" do
      mock_mailbox do |mailbox|
        uid = mailbox.fetch_uids.first
        message = mailbox.emails(uid: uid).first
        expect { message.mark :read  }.to_not raise_error
      end
    end

    it "should be able to move itself to given box" do
      mock_mailbox do |mailbox|
        uid = mailbox.fetch_uids.first
        message = mailbox.emails(uid: uid).first
        expect { message.move '[Gmail]/Trash' }.to_not raise_error
      end
    end
  end
end
