module Gmail
  class Mailbox
    MAILBOX_ALIASES = {
      :all       => ['ALL'],
      :seen      => ['SEEN'],
      :unseen    => ['UNSEEN'],
      :read      => ['SEEN'],
      :unread    => ['UNSEEN'],
      :flagged   => ['FLAGGED'],
      :unflagged => ['UNFLAGGED'],
      :starred   => ['FLAGGED'],
      :unstarred => ['UNFLAGGED'],
      :deleted   => ['DELETED'],
      :undeleted => ['UNDELETED'],
      :draft     => ['DRAFT'],
      :undrafted => ['UNDRAFT']
    }

    attr_reader :name
    attr_reader :uidvalidity
    attr_reader :external_name
    attr_reader :examine

    def initialize(gmail, name="INBOX", uidvalidity = nil, examine = false)
      @name  = name
      @external_name = Net::IMAP.decode_utf7(name)
      @uidvalidity = uidvalidity
      @gmail = gmail
      @examine = examine
    end

    # Returns list of emails which meets given criteria.
    #
    # ==== Examples
    #
    #   gmail.inbox.emails(:all)
    #   gmail.inbox.emails(:unread, :from => "friend@gmail.com")
    #   gmail.inbox.emails(:all, :after => Time.now-(20*24*3600))
    #   gmail.mailbox("Test").emails(:read)
    #
    #   gmail.mailbox("Test") do |box|
    #     box.emails(:read)
    #     box.emails(:unread) do |email|
    #       ... do something with each email...
    #     end
    #   end
    # @param [Symbol, Optional] search the mailbox alias (:all, unread, etc)
    # @param [Hash, Optional] args the search options to use for fetch_uids
    # @arg [:include, Optional] Part of the message to eager load. Can be :message, :envelope, or :both
    # @arg [:batch_size, Optional] If given, sets the batch size to use when loading in messages. Defaults to single batch
    # @arg [:cache_messages, Optional] If given, sets whether or not to cache the messages. False setting is useful when loading large email sets, to save on memory.
    def emails(*args, &block)
      if block_given?
        proc = Proc.new do |batch|
          batch.each { |message| block.call(message) }
        end
        args << proc
      end
      emails_in_batches(*args)
    end

    alias :mails :emails
    alias :search :emails
    alias :find :emails
    alias :filter :emails

    # Same as emails, but yields the batch object as opposed to the individual email
    # @param [Symbol, Optional] search the mailbox alias (:all, unread, etc)
    # @param [Hash, Optional] args the search options to use for fetch_uids
    # @arg [:include, Optional] Part of the message to eager load.
    #    Expects either a symbol or an array of symbols. :message,
    #    :envelope, and :labels supported
    # @arg [:batch_size, Optional] If given, sets the batch size to
    #    use when loading in messages. Defaults to single batch
    # @arg [:cache_messages, Optional] If given, sets whether or not
    #    to cache the messages. False setting is useful when loading
    #    large email sets, to save on memory.
    def emails_in_batches(*args, &block)
      opts =  case args.first
              when Symbol
                args[1] ? args[1] : {}
              when Hash then args.first
              else {}
              end
      uids = fetch_uids(*args)

      tmp_cache = []
      unless uids.nil? || uids.empty?
        batch_size = opts[:batch_size] || 100
        cache_messages = opts[:cache_messages].nil? ? true : opts[:cache_messages]

        fetch = ["UID"].push(opts[:include]).flatten.compact.collect do |opt|
          case opt
          when "message", :message then "RFC822"
          when "envelope", :envelope then "ENVELOPE"
          when "labels", :labels then "X-GM-LABELS"
          when "thread", :thread then "X-GM-THRID"
          when "msgid", :msgid then "X-GM-MSGID"
          else opt
          end
        end

        uids.each_slice(batch_size) do |slice|
          batch = @gmail.conn.uid_fetch(slice, fetch).collect do |msg|
            message = Message.new(self, msg.attr["UID"], message: msg.attr["RFC822"],
                                                         envelope: msg.attr["ENVELOPE"],
                                                         labels: msg.attr["X-GM-LABELS"],
                                                         thread_id: msg.attr["X-GM-THRID"],
                                                         msg_id: msg.attr["X-GM-MSGID"])
            messages[msg.attr["UID"]] ||= message if cache_messages
            message
          end
          batch = block.call(batch) if block_given?
          tmp_cache = tmp_cache | batch if cache_messages
        end
      end
      tmp_cache
    end

    # Fetches the list of message UIDs based on the criteria provided
    #
    # @param [Hash] criteria the search criteria
    # @return [Array] an array of UIDs matching the search criteria
    def fetch_uids(*args)
      args << :all if args.size == 0

        if args.first.is_a?(Symbol)
          search = MAILBOX_ALIASES[args.shift].dup
          opts = args.first.is_a?(Hash) ? args.first : {}

          opts[:after]      and search.concat ['SINCE', opts[:after].to_imap_date]
          opts[:before]     and search.concat ['BEFORE', opts[:before].to_imap_date]
          opts[:on]         and search.concat ['ON', opts[:on].to_imap_date]
          opts[:from]       and search.concat ['FROM', opts[:from]]
          opts[:to]         and search.concat ['TO', opts[:to]]
          opts[:subject]    and search.concat ['SUBJECT', opts[:subject]]
          opts[:label]      and search.concat ['LABEL', opts[:label]]
          opts[:attachment] and search.concat ['HAS', 'attachment']
          opts[:search]     and search.concat ['BODY', opts[:search]]
          opts[:body]       and search.concat ['BODY', opts[:body]]
          opts[:uid]        and search.concat ['UID', opts[:uid]]
          opts[:query]      and search.concat opts[:query]

          @gmail.mailbox(name) do
            uids = @gmail.conn.uid_search(search)
            uids = uids.first(opts[:limit]) if opts[:limit]
            return uids
          end
        elsif args.first.is_a?(Hash)
          fetch_uids(:all, args.first)
        else
          raise ArgumentError, "Invalid search criteria"
        end
    end

    # This is a convenience method that really probably shouldn't need to exist,
    # but it does make code more readable, if seriously all you want is the count
    # of messages.
    #
    # ==== Examples
    #
    #   gmail.inbox.count(:all)
    #   gmail.inbox.count(:unread, :from => "friend@gmail.com")
    #   gmail.mailbox("Test").count(:all, :after => Time.now-(20*24*3600))
    def count(*args)
      emails(*args).size
    end

    # This permanently removes messages which are marked as deleted
    def expunge
      @gmail.mailbox(name) { @gmail.conn.expunge }
    end

    # Cached messages.
    def messages
      @messages ||= {}
    end

    def inspect
      "#<Gmail::Mailbox#{'0x%04x' % (object_id << 1)} name=#{external_name}>"
    end

    def to_s
      name
    end

    MAILBOX_ALIASES.each_key { |mailbox|
      define_method(mailbox) do |*args, &block|
        emails(mailbox, *args, &block)
      end
    }
  end # Message
end # Gmail
