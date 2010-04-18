#!/usr/bin/ruby -Ku

def require_gem gem
  require 'rubygems'
  require gem
end

def error(*args)
  args = args.find_all { |x| x }
  args << "\n"
  STDERR.print "ERROR: ", *args
end

class NilClass
  attr_accessor :sym, :args
  def method_missing(sym, *args)
    @sym = sym
    @args = args
  end
end

class Array
  def | arg
    if arg.respond_to? :sym and arg.sym
      self.map { |x| x.send arg.sym, *arg.args }
    end
  end
end

class String
  def | arg
    if arg.respond_to? :sym and arg.sym
      self.send arg.sym, *arg.args
    end
  end

  def curl(*args)
    unless $curl
      require_gem 'curb'
      $curl = Curl::Easy.new
    end
    $curl.url = self
    if args.length == 0
      $curl.http_get
    else
      $curl.http_post *args
    end
    $curl.body_str
  end
  
  def append_to(file)
    open(file, 'w') { |f| f << self }
  end

  def directory?; FileTest.directory? self; end
  def file?; FileTest.file? self; end
  def chmod(mode); File.chmod(mode, self); end 
end

class Finder < Enumerable::Enumerator
  require 'find'
  def initialize(path)
    @path = path
  end
  def each
    Find.find(@path) { |f| yield f }
  end
end

class SubshellBase
  alias_method :old_method_missing, :method_missing
  def method_missing(sym, *args)
    if ''.respond_to? sym
      self.exec "$_.send #{sym.inspect}, *#{args.inspect}"
    elsif true
      `#{sym.to_s} #{args.join ' '}`
    else
      error "Bad command or filename: #{sym}", (" #{args.inspect}" unless args.empty?)
      raise NameError
    end
  end
  
  def get_line
    #eval 'line = STDIN.gets; line ? line.chomp! : nil', self.pure_binding
    eval 'STDIN.gets', self.pure_binding
  end
  
  def pure_binding
    @pure_binding ||= self.instance_eval "binding"
    #eval('import SubshellStuff', @pure_binding)
  end
  
  def exec(command)
    begin
      result = eval(command, self.pure_binding)
      puts result unless result == nil
    rescue
    end
  end
end

class Subshell < SubshellBase
  def ÷(a,b)
    a/b
  end

  def ifconfig
    require_gem 'ifconfig'
    IfconfigWrapper.new.parse
  end

  def term_cols
    $TERM_COLS = $TERM_COLS or `tput cols`.to_i
  end

  def stripe(array)
    col_width = 12
    num_cols = term_cols / col_width
    num_rows = (1.0 * array.length / num_cols).ceil
    (0..num_rows-1).each do |x|
      (0..num_cols-1).each do |y|
        printf "%-#{col_width-1}.#{col_width-1}s ", array[x*num_cols+y]
      end
      puts
    end
    return nil
  end

  def help(arg)
    type = arg.is_a?(Class) ? arg : arg.class
    stripe type.instance_methods(false).sort
    return nil
  end
  
  def find(path)
    require 'find'
    #if block_given?
      Find.find(path)
    #else
    #  Finder.new(path)
    #end
  end
end

def get_line
  line = STDIN.gets
  line ? CommandString.new(line.chomp!) : nil
end

class CommandString < String
  def initialize(*args)
    super args.join(' ').gsub '÷', '/'
  end
end
def CommandString(*args); CommandString.new(*args); end

def exec(command)
  command = CommandString command
  subshell = Subshell.new

  if STDIN.stat.pipe?
    while line = subshell.get_line
      subshell.exec command
    end
  else
    subshell.exec command
  end
end

def ps1
  display_pwd = ENV['PWD'].sub /^#{ENV['HOME']}/, '~'
  "#{ENV['USER']}@#{ENV['HOST']}:#{display_pwd} $ "
end

def shell
  require 'readline'

  stty_save = `stty -g`.chomp
  trap('INT') { puts; puts; system('stty', stty_save); exit }
  
  subshell = Subshell.new
  
  while line = Readline.readline(ps1)
    finish if line.nil? or line == 'exit'
    next if line == ""
    Readline::HISTORY.push line

    commands = line.split /(\s*[;|&]\s*)/
    #command.each_slice(2) do |i|
    #  cmd = commands[i]
    #  delim = commands[i+1]
    #  #######
    #end
    subshell.exec line
  end
end

if ARGV.length > 0
  exec(ARGV)
else
  shell
end