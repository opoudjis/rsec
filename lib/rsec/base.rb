# coding: utf-8
# ------------------------------------------------------------------------------
# Parser Base

module Rsec #:nodoc:
  # parses string<br/>
  # returns nil if unparsed
  def parse str, source_name='source'
    ctx = ParseContext.new str, source_name
    _parse ctx
  end

  # almost the same as parse<br/>
  # but raises SyntaxError
  def parse! str, source_name='source'
    ctx = ParseContext.new str, source_name
    ret = _parse ctx
    if INVALID[ret]
      raise ctx.generate_error source_name
    end
    ret
  end

    # error class for rescue
  class SyntaxError < StandardError
    attr_reader :msg, :line_text, :line, :col

    # constructor
    def initialize msg, line_text, line, col
      @msg, @line_text, @line, @col = msg, line_text, line, col
    end

    # info with source position
    def to_s
      %Q<#@msg\n#@line_text\n#{' ' * @col}^>
    end
  end

  # parse context inherits from StringScanner<br/>
  # <br/>
  # attributes:<br/>
  # <pre>
  #   [R]  string: string to parse
  #   [RW] pos: current position
  #   [R]  source: source file name
  #   [R]  current_line_text: current line text
  #   [R]  cache: for memoization
  # </pre>
  class ParseContext < StringScanner
    attr_reader :source, :cache, :last_fail_pos
    attr_accessor :attr_names

    def initialize str, source
      super(str)
      @source = source
      @cache = {}
      @last_fail_pos = 0
      @last_fail_tokens = []
    end
    
    # clear packrat parser cache
    def clear_cache
      @cache.clear
    end

    # add fail message
    def on_fail tokens
      if pos > @last_fail_pos
        @last_fail_pos = pos
        @last_fail_tokens = tokens
      elsif pos == @last_fail_pos
        @last_fail_tokens += (tokens - @last_fail_tokens)
      end
    end

    # generate parse error
    def generate_error source
      if self.pos <= @last_fail_pos
        line = line @last_fail_pos
        col = col @last_fail_pos
        line_text = line_text @last_fail_pos
        expects = ", expect token [ #{@last_fail_tokens.join ' | '} ]"
      else
        line = line pos
        col = col pos
        line_text = line_text pos
        expects = nil
      end
      msg = "\nin #{source}:#{line} at #{col}#{expects}"
      SyntaxError.new msg, line_text, line, col
    end

    # get line number
    def line pos
      string[0...pos].count("\n") + 1
    end

    # get column number: position in line
    def col pos
      return 1 if pos == 0
      newline_pos = string.rindex "\n", pos - 1
      if newline_pos
        pos - newline_pos
      else
        pos + 1
      end
    end

    # get line text containing pos
    # the text is 80 at most
    def line_text pos
      from = string.rindex "\n", pos
      from = from ? from + 1 : 0
      from = pos - 40 if (from < pos - 40)

      to = string.index("\n", pos)
      to = to ? to - 1 : string.size
      to = pos + 40 if (to > pos + 40)

      string[from..to]
    end
  end

  # the skip token
  SKIP = Object.new
  class << SKIP
    def to_str
      'SKIP_TOKEN'
    end
    alias :[] :==
    alias inspect to_str
  end

  # the invalid token
  INVALID = Object.new
  class << INVALID
    def to_str
      'INVALID_TOKEN'
    end
    alias :[] :==
    alias inspect to_str
  end

  attr_accessor :name
  def inspect
    # TODO move
    @name ||= self.class.to_s[/\w+$/]
    case self
    when Lazy, Dynamic
      "<#{name}>"
    when Binary
      "<#{name} #{left.inspect} #{right.inspect}>"
    when Seq, Seq_, Branch
      # don't use redefined map!
      res = []
      each{|e| res << e.inspect}
      "<#{name} #{res.join ' '}>"
    when Unary
      "<#{name} #{some.inspect}>"
    else
      "<#{name}>"
    end
  end

end
