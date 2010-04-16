#!/usr/bin/ruby -Ku

#trace_var :$_, proc {|v| puts "$_ is now '#{v}'" }
#String.instance_methods(false).sort

def require_gem gem
  require 'rubygems'
  require gem
end

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

module Kernel
  alias_method :old_method_missing, :method_missing
  def method_missing(sym, *args)
    if $last_line.respond_to? sym
      $last_line.send sym, *args
    else
      old_method_missing sym, *args
    end
  end
end

class String
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
end

class CommandString < String
  def initialize(*args)
    super args.join(' ').gsub '÷', '/'
  end
  
  def go
    result = eval self
    if result 
      puts result
    end
  end
end
def CommandString(*args); CommandString.new(*args); end

command = CommandString(ARGV)

if STDIN.stat.pipe?
  while line = STDIN.gets
    $last_line = $_
    # XXX: Need to figure out how to get $_ to stay around
    #command.go
    result = eval command
    puts result if result
  end
else
  command.go
end