require 'mime/message'

module Gmail
  class Message
    # Raised when given label doesn't exists.
    class NoLabelError < Exception; end

    attr_reader :uid, :mailbox

    def initialize(mailbox, uid, options={})
      @uid     = uid
      @mailbox = mailbox
      @gmail   = mailbox.instance_variable_get("@gmail") if mailbox
      @message = Mail.new options[:message]
      @envelope = options[:envelope]
      @labels = options[:labels]
      @thread_id = options[:thread_id]
      @msg_id = options[:msg_id]
    end
        
    def flags
      @flags ||= @gmail.conn.uid_fetch(uid, "FLAGS")[0].attr["FLAGS"]
    end

    def is_read?
      flags.include? :Seen
    end

    def is_starred?
      labels.include? :Starred
    end

    def is_important?
      labels.include? :Important
    end

    def uid
      @uid ||= @gmail.conn.uid_search(['HEADER', 'Message-ID', message_id])[0]
    end

    def msg_id
      @msg_id ||= with_mailbox {
        @gmail.conn.uid_fetch(uid, "X-GM-MSGID")[0].attr["X-GM-MSGID"]
      }
    end

    # Mark message with given flag.
    def flag(name)
      !!with_mailbox { @gmail.conn.uid_store(uid, "+FLAGS", [name]) }
    end

    # Unmark message.
    def unflag(name)
      !!with_mailbox { @gmail.conn.uid_store(uid, "-FLAGS", [name]) }
    end

    # Proper way to label/star/move to inbox
    def gmail_flag(name)
      !!@gmail.mailbox(@mailbox.name) { @gmail.conn.uid_store(uid, "+X-GM-LABELS", [name]) }
    end

    def gmail_unflag(name)
      !!@gmail.mailbox(@mailbox.name) { @gmail.conn.uid_store(uid, "-X-GM-LABELS", [name]) }
    end

    # Do commonly used operations on message. 
    def mark(flag)
      case flag
        when :read    then read!
        when :unread  then unread!
        when :deleted then delete!
        when :spam    then spam!
      else
        flag(flag)
      end
    end

    # Mark this message as a spam.
    def spam!
      move_to('[Gmail]/Spam')
    end

    # Mark as read.
    def read!
      flag(:Seen)
    end

    # Mark as unread.
    def unread!
      unflag(:Seen)
    end

    # Mark message with star.
    def star!
      gmail_flag(:Starred)
    end

    # Remove message from list of starred.
    def unstar!
      gmail_unflag(:Starred)
    end

    def important!
      gmail_flag(:Important)
    end

    def unimportant!
      gmail_unflag(:Important)
    end

    # Move to trash / bin.
    def delete!
      @mailbox.messages.delete(uid)
      flag(:deleted)

      # For some, it's called "Trash", for others, it's called "Bin". Support both.
      trash =  @gmail.labels.exist?('[Gmail]/Bin') ? '[Gmail]/Bin' : '[Gmail]/Trash'
      move_to(trash) unless %w[[Gmail]/Spam [Gmail]/Bin [Gmail]/Trash].include?(@mailbox.name)
    end

    # Move out of trash / bin.
    def undelete!
      @mailbox.messages[uid] = self
      unflag(:deleted)

      move_to(@mailbox.name) unless %w[[Gmail]/Spam [Gmail]/Bin [Gmail]/Trash].include?(@mailbox.name)
    end

    # Archive this message.
    def archive!
      #move_to('[Gmail]/All Mail')
      gmail_unflag(:Inbox)
    end

    # Move to given box and delete from others.
    def move_to(name, from=nil)
      label(name, from)
      delete! if !%w[[Gmail]/Bin [Gmail]/Trash].include?(name)
    end
    alias :move :move_to

    # Move message to given and delete from others. When given mailbox doesn't
    # exist then it will be automaticaly created.
    def move_to!(name, from=nil)
      label!(name, from) && delete!
    end
    alias :move! :move_to!

    # Mark this message with given label. When given label doesn't exist then
    # it will raise <tt>NoLabelError</tt>.
    #
    # See also <tt>Gmail::Message#label!</tt>.
    def label(name, from=nil)
      @gmail.mailbox(Net::IMAP.encode_utf7(from || @mailbox.external_name)) { @gmail.conn.uid_copy(uid, Net::IMAP.encode_utf7(name)) }
    rescue Net::IMAP::NoResponseError
      raise NoLabelError, "Label '#{name}' doesn't exist!"
    end

    # Mark this message with given label. When given label doesn't exist then
    # it will be automaticaly created.
    #
    # See also <tt>Gmail::Message#label</tt>.
    def label!(name, from=nil)
      label(name, from)
    rescue NoLabelError
      @gmail.labels.add(Net::IMAP.encode_utf7(name))
      label(name, from)
    end
    alias :add_label :label!
    alias :add_label! :label!

    def labels
      @labels ||= with_mailbox {
        @gmail.conn.uid_fetch(uid, "X-GM-LABELS")[0].attr["X-GM-LABELS"]
      }
    end

    # Remove given label from this message.
    def remove_label!(name)
      move_to('[Gmail]/All Mail', name)
    end
    alias :delete_label! :remove_label!

    def inspect
      "#<Gmail::Message#{'0x%04x' % (object_id << 1)} mailbox=#{@mailbox.external_name}#{' uid='+@uid.to_s if @uid}#{' message_id='+@message_id.to_s if @message_id}>"
    end

    def method_missing(meth, *args, &block)
      # Delegate rest directly to the message.
      if envelope.respond_to?(meth)
        envelope.send(meth, *args, &block)
      elsif message.respond_to?(meth)
        message.send(meth, *args, &block)
      else
        super(meth, *args, &block)
      end
    end

    def respond_to?(meth, *args, &block)
      if envelope.respond_to?(meth)
        return true
      elsif message.respond_to?(meth)
        return true
      else
        super(meth, *args, &block)
      end
    end

    def envelope
      @envelope ||= with_mailbox {
        @gmail.conn.uid_fetch(uid, "ENVELOPE")[0].attr["ENVELOPE"]
      }
    end

    def thread_id
      @thread_id ||= with_mailbox {
        @gmail.conn.uid_fetch(uid, "X-GM-THRID")[0].attr["X-GM-THRID"]
      }
    end

    def message
      @message ||= Mail.new(with_mailbox {
        request,part = 'RFC822','RFC822'
        request,part = 'BODY.PEEK[]','BODY[]' if @gmail.peek
        @gmail.conn.uid_fetch(uid, request)[0].attr[part] # RFC822
      })
    end
    alias_method :raw_message, :message

    def with_mailbox(&block)
      @gmail.mailbox(@mailbox.name, @mailbox.examine, &block)
    end

  end # Message
end # Gmail
