##
## $Rev$
## $Release$
## $Copyright$
##

require 'eruby'
require 'erb'
require 'stringio'

require 'erubis'
require 'erubis/engine/enhanced'
require 'erubis/engine/optimized'
require 'erubis/tiny'
require 'erubybench-lib'


## default value
defaults = {
  :ntimes    => 1000,
  :erubyfile => 'erubybench.rhtml',
  :datafile  => 'erubybench.yaml',
}


## usage
def usage(defaults)
  script = File.basename($0)
  s =  "Usage: ruby #{script} [-h] [-n N] [-f file] [-d file] [-t testname ...]\n"
  s << "  -h      :  help\n"
  s << "  -n N    :  number of times to loop (default #{defaults[:ntimes]})\n"
  s << "  -f file :  eruby filename (default '#{defaults[:filename]}')\n"
  s << "  -d file :  data filename (default '#{defaults[:datafile]}')\n"
  return s
end


## parse command-line options
require 'optparse'
optparser = OptionParser.new
options = {}
['-h', '-n N', '-F erubyfile', '-f datafile', '-t targets', '-x exclude',
 '-T testtype', '-C compiler', '-X'].each do |opt|
  optparser.on(opt) { |val| options[opt[1]] = val }
end
begin
  filenames = optparser.parse!(ARGV)
rescue => ex
  $stderr.puts "#{command}: #{ex.to_s}"
  exit(1)
end


flag_help = options[?h]
ntimes    = (options[?n] || defaults[:ntimes]).to_i
erubyfile = options[?F] || defaults[:erubyfile]
datafile  = options[?f] || defaults[:datafile]
targets   = options[?t]
testtype  = options[?T]
compiler_name = options[?C] || 'ErubisOptimized'
excludes  = options[?x]
$expand = options[?X] ? true : false

$ntimes = ntimes


#flag_help = false
#flag_all = false
#targets = nil
#test_type = nil
#compiler_name = 'ErubisOptimized'
#while !ARGV.empty? && ARGV[0][0] == ?-
#  opt = ARGV.shift
#  case opt
#  when '-n'  ;  n = ARGV.shift.to_i
#  when '-f'  ;  filename = ARGV.shift
#  when '-d'  ;  datafile = ARGV.shift
#  when '-h', '--help'  ;  flag_help = true
#  when '-A'  ;  test_all = true
#  when '-C'  ;  compiler_name = ARGV.shift
#  when '-t'  ;  test_type = ARGV.shift
#  else       ;  raise "#{opt}: invalid option."
#  end
#end
#puts "** n=#{n.inspect}, filename=#{filename.inspect}, datafile=#{datafile.inspect}"


## help
if flag_help
  puts usage(defaults)
  exit()
end


## load data file
require 'yaml'
ydoc = YAML.load_file(datafile)
data = []
ydoc['data'].each do |hash|
  data << hash.inject({}) { |h, t| h[t[0].intern] = t[1]; h }
  #h = {}; hash.each { |k, v| h[k.intern] = v } ; data << h
end
data = data.sort_by { |h| h[:code] }
#require 'pp'; pp data


## test definitions
testdefs_str = <<END
- name:   ERuby
  class:  ERuby
  code: |
    ERuby.import(erubyfile)
  compile: |
    ERuby::Compiler.new.compile_string(str)
  return: null

- name:   ERB
  class:  ERB
  code: |
    print ERB.new(File.read(erubyfile)).result(binding())
#    eruby = ERB.new(File.read(erubyfile))
#    print eruby.result(binding())
  compile: |
    ERB.new(str).src
  return: str

- name:   ErubisEruby
  class:  Erubis::Eruby
  return: str

- name:   ErubisEruby2
  desc:   print _buf    #, no binding()
  class:  Erubis::Eruby2
  code: |
    #Erubis::Eruby2.new(File.read(erubyfile)).result()
    Erubis::Eruby2.new(File.read(erubyfile)).result(binding())
  return: null
  skip:   yes

- name:   ErubisExprStripped
  desc:   strip expr code
  class:  Erubis::ExprStrippedEruby
  return: str
  skip:   yes

- name:   ErubisOptimized
  class:  Erubis::OptimizedEruby
  return: str
  skip:   yes

- name:   ErubisOptimized2
  class:  Erubis::Optimized2Eruby
  return: str
  skip:   yes

#- name:   ErubisArrayBuffer
#  class:  Erubis::ArrayBufferEruby
#  code: |
#    Erubis::ArrayBufferEruby.new(File.read(erubyfile)).result(binding())
#  compile: |
#    Erubis::ArrayBufferEruby.new(str).src
#  return: str
#  skip:   no

- name:   ErubisStringBuffer
  class:  Erubis::StringBufferEruby
  return: str
  skip:   no

- name:   ErubisStringIO
  class:  Erubis::StringIOEruby
  return: str
  skip:   yes

- name:   ErubisSimplified
  class:  Erubis::SimplifiedEruby
  return: str
  skip:   no

- name:   ErubisStdout
  class:  Erubis::StdoutEruby
  return: null
  skip:   no

- name:   ErubisStdoutSimplified
  class:  Erubis::StdoutSimplifiedEruby
  return: str
  skip:   no

- name:   ErubisPrintOut
  class:  Erubis::PrintOutEruby
  return: str
  skip:   no

- name:   ErubisPrintOutSimplified
  class:  Erubis::PrintOutSimplifiedEruby
  return: str
  skip:   no

- name:   ErubisTiny
  class:  Erubis::TinyEruby
  return: yes
  skip:   no

- name:   ErubisTinyStdout
  class:  Erubis::TinyStdoutEruby
  return: null
  skip:   no

- name:   ErubisTinyPrint
  class:  Erubis::TinyPrintEruby
  return: null
  skip:   no

#- name:    load
#  class:   load
#  code: |
#    load($load_erubyfile)
#  compile: null
#  return: null
#  skip:    yes

END
testdefs = YAML.load(testdefs_str)

## manipulate
testdefs.each do |testdef|
  c = testdef['class']
  testdef['code']    ||= "print #{c}.new(File.read(erubyfile)).result(binding())\n"
  testdef['compile'] ||= "#{c}.new(str).src\n"
  require 'pp'
  #pp testdef
end

### create file for load
#if testdefs.find { |h| h['name'] == 'load' }
#  $load_erubyfile = erubyfile + ".tmp"   # for load
#  $data = data
#  str = File.read(erubyfile)
#  str.gsub!(/\bdata\b/, '$data')
#  hash = testdefs.find { |h| h['name'] == compiler_name }
#  code = eval hash['compile']
#  code.sub!(/_buf\s*\z/, 'print \&')
#  File.open($load_erubyfile, 'w') { |f| f.write(code) }
#  at_exit do
#    File.unlink $load_erubyfile if test(?f, $load_erubyfile)
#  end
#end


## select test target
if targets.nil?
  testdefs.delete_if { |h| h['skip'] }
elsif targets.downcase != 'all'
  targets = targets.split(/,/)
  testdefs.delete_if { |h| !targets.include?(h['name']) }
end

## exclude target
if excludes
  excludes = excluces.split(/,/)
  testdefs.delete_if { |h| excludes.include?(h['name']) }
end

#require 'pp'; pp testdefs


str = File.read(erubyfile)
testdefs.each do |h|
  ## define test functions for each classes
  s = ''
  s << "def test_#{h['name']}(erubyfile, data)\n"
  s << "  $stdout = $devnull\n"
  if $expand
    $ntimes.times do
      s << '  ' << h['code']  #<< "\n"
    end
  else
    s << "  $ntimes.times do\n"
    s << "    #{h['code']}\n"
    s << "  end\n"
  end
  s << "  $stdout = STDOUT\n"
  s << "end\n"
  #puts s
  eval s
end


## define view functions for each classes
str = File.read(erubyfile)
testdefs.each do |h|
  if h['compile']
    code = eval h['compile']
    s = <<-END
      def view_#{h['name']}(data)
        #{code}
      end
    END
    #puts s
    eval s
  end
end


## define tests for view functions
testdefs.each do |h|
  pr = h['return'] ? 'print ' : ''
  s = ''
  s << "def test_view_#{h['name']}(data)\n"
  s << "  $stdout = $devnull\n"
  if $expand
    $ntimes.times do
      s << "  #{pr}view_#{h['name']}(data)\n"
    end
  else
    s << "  $ntimes.times do\n"
    s << "    #{pr}view_#{h['name']}(data)\n"
    s << "  end\n"
  end
  s << "  $stdout = STDOUT\n"
  s << "end\n"
  #puts s
  eval s
end


## define tests for caching
str = File.read(erubyfile)
testdefs.each do |h|
  if h['compile']
    # create file to read
    code = eval h['compile']
    fname = "#{erubyfile}.#{h['name']}"
    File.open(fname, 'w') { |f| f.write(code) }
    #at_exit do File.unlink fname if test(?f, fname) end
    # define function
    pr = h['return'] ? 'print ' : ''
    s = ''
    s << "def test_cache_#{h['name']}(erubyfile, data)\n"
    s << "  $stdout = $devnull\n"
    s << "  $ntimes.times do\n"
    s << "    #{pr}eval(File.read(\"\#{erubyfile}.#{h['name']}\"))\n"
    s << "  end\n"
    #ntimes.times do
    #  s << "  #{pr}eval(File.read(\"\#{erubyfile}.#{h['name']}\"))\n"
    #end
    s << "  $stdout = STDOUT\n"
    s << "end\n"
    #puts s
    eval s
  end
end


## open /dev/null
$devnull = File.open("/dev/null", 'w')


## rehearsal
$stdout = $devnull
testdefs.each do |h|
  ## execute test code
  eval h['code']
  ## execute view function
  next unless h['compile']
  v = __send__("view_#{h['name']}", data)
  print v if h['return']
  ## execute caching function
  v = eval(File.read("#{erubyfile}.#{h['name']}"))
  print v if h['return']
end
$stdout = STDOUT


## do benchmark
require 'benchmark'
begin
  Benchmark.bm(30) do |job|
    ## basic test
    testdefs.each do |h|
      title = h['class']
      func = 'test_' + h['name']
      GC.start
      job.report(title) do
        __send__(func, erubyfile, data)
      end
    end if !testtype || testtype == 'basic'

    ## caching function
    testdefs.each do |h|
      next unless h['compile']
      title = 'cache_' + h['name']
      func = 'test_cache_' + h['name']
      GC.start
      job.report(title) do
        __send__(func, erubyfile, data)
      end
    end if !testtype || testtype == 'cache'

    ## view-function test
    testdefs.each do |h|
      next unless h['compile']
      title = 'func_' + h['name']
      func = 'test_view_' + h['name']
      GC.start
      job.report(title) do
        __send__(func, data)
      end
    end if !testtype || testtype == 'func'

  end
ensure
  $devnull.close()
end
