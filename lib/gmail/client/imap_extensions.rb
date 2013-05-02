# Taken from https://github.com/oxos/gmail-oauth-thread-stats/blob/master/gmail_imap_extensions_compatibility.rb

module GmailImapExtensions

  def self.patch_net_imap_response_parser(klass = Net::IMAP::ResponseParser)
    klass.class_eval do
      def msg_att(n = nil)
        match(self.class::T_LPAR)
        attr = {}
        while true
          token = lookahead
          case token.symbol
          when self.class::T_RPAR
            shift_token
            break
          when self.class::T_SPACE
            shift_token
            next
          end
          case token.value
          when /\A(?:ENVELOPE)\z/ni
            name, val = envelope_data
          when /\A(?:FLAGS)\z/ni
            name, val = flags_data
          when /\A(?:INTERNALDATE)\z/ni
            name, val = internaldate_data
          when /\A(?:RFC822(?:\.HEADER|\.TEXT)?)\z/ni
            name, val = rfc822_text
          when /\A(?:RFC822\.SIZE)\z/ni
            name, val = rfc822_size
          when /\A(?:BODY(?:STRUCTURE)?)\z/ni
            name, val = body_data
          when /\A(?:UID)\z/ni
            name, val = uid_data
      
          # Gmail extension additions.
          # Cargo-Cult code warning: # I have no idea why the regexp - just copying a pattern
          when /\A(?:X-GM-LABELS)\z/ni
            name, val = label_data
          when /\A(?:X-GM-MSGID)\z/ni 
            name, val = uid_data
          when /\A(?:X-GM-THRID)\z/ni 
            name, val = uid_data
          else
            parse_error("unknown attribute `%s'", token.value, n)
          end
          attr[name] = val
        end
        return attr
      end

      def label_data
        token = match(self.class::T_ATOM)
        name = token.value.upcase
        match(self.class::T_SPACE)
        return name, astring_list
      end

      def astring_list
        result = []
        match(self.class::T_LPAR)
        while true
          token = lookahead
          case token.symbol
          when self.class::T_RPAR
            shift_token
            break
          when self.class::T_SPACE
            shift_token
          end
          result.push(astring)
        end
        return result
      end

    end # class_eval

    # Bootstrap negative numbers into the NUMBER regexp
    #
    # Handle Gmail's  malformed (negative) X-GM-IDs, which trip up the old
    # NUMBER regexp pattern
    klass.send :remove_const, :BEG_REGEXP
    klass.const_set 'BEG_REGEXP', /\G(?:\
(?# 1:  SPACE   )( +)|\
(?# 2:  NIL     )(NIL)(?=[\x80-\xff(){ \x00-\x1f\x7f%*#{'"'}\\\[\]+])|\
(?# 3:  NUMBER  )(-?\d+)(?=[\x80-\xff(){ \x00-\x1f\x7f%*#{'"'}\\\[\]+])|\
(?# 4:  ATOM    )([^\x80-\xff(){ \x00-\x1f\x7f%*#{'"'}\\\[\]+]+)|\
(?# 5:  QUOTED  )"((?:[^\x00\r\n"\\]|\\["\\])*)"|\
(?# 6:  LPAR    )(\()|\
(?# 7:  RPAR    )(\))|\
(?# 8:  BSLASH  )(\\)|\
(?# 9:  STAR    )(\*)|\
(?# 10: LBRA    )(\[)|\
(?# 11: RBRA    )(\])|\
(?# 12: LITERAL )\{(\d+)\}\r\n|\
(?# 13: PLUS    )(\+)|\
(?# 14: PERCENT )(%)|\
(?# 15: CRLF    )(\r\n)|\
(?# 16: EOF     )(\z))/ni

    # Add String#unescape
    add_unescape
  end # PNIRP

  def self.add_unescape(klass = String)
    klass.class_eval do
      # Add a method to string which unescapes special characters
      # We use a simple state machine to ensure that specials are not
      # themselves escaped
      def unescape
        unesc = ''
        special = false
        escapes = { '\\' => '\\',
                    '"'  => '"',
                    'n' => "\n",
                    't' => "\t",
                    'r' => "\r",
                    'f' => "\f",
                    'v' => "\v",
                    '0' => "\0",
                    'a' => "\a"
                  }

        self.each_char do |char|
          if special
            # If in special mode, add in the replaced special char if there's a match
            # Otherwise, add in the backslash and the current character
            unesc << (escapes.keys.include?(char) ? escapes[char] : "\\#{char}")
            special = false
          else
            # Toggle special mode if backslash is detected; otherwise just add character
            if char == '\\'
              special = true
            else
              unesc << char
            end
          end
        end
        unesc
      end
    end
  end
end # module
