#!/usr/bin/ruby -Ku
# -*- coding: utf-8 -*-

require "uconv"
require "pp"

#$statements_re = /^(add|bg|br|cl|goto|ld|select|\*|renpy:)/
$statements_re = /^(add|bg|cl|goto|ld|select|\*|renpy:)/

$SCRIPT_RPY_TEMPLATE = "script_template.txt"

class String
  def path2chara
    temp = self.sub(/\.jpg$/, ".png")
    return temp.gsub(".","_")
  end
  
  def path2alias
    temp = self.sub(/\.(.+?)$/, "")
    return temp.gsub(".","_")
  end
  
  def full_pos
    case self
    when "c" ; "center"
    when "l" ; "left"
    when "r" ; "right"
    else     ; raise "must not happen"
    end
  end
end


class NScripter
  def initialize
    @scripts = []
  end


  def parse_files
    1.upto(99){|n|
      script = Script.new(n)
      
      #break if n > 1
      
      script.preproc()
      script.parse()
      
      @scripts << script
    
      dest_path = "%02d.rpy" % [n]
    
      break if script.is_last
    }
  end
  
  
  def write
    @scripts.each{|s|
      s.write()
    }
  end
  
  
  def regist
    src = File.read $SCRIPT_RPY_TEMPLATE
    temp_bg = []
    temp_doll = []
    temp_variables = []
    
    @scripts.each{|s|
      temp_bg << s.bg_files
      temp_doll << s.doll_files
      temp_variables << s.variables
    }
    @bg_files = temp_bg.flatten.sort.uniq
    @doll_files = temp_doll.flatten.sort.uniq
    @variables = temp_variables.flatten.sort.uniq
    
    temp_str_bg = ""
    temp_str_doll = ""
    temp_str_variables = ""
    str_bg = @bg_files.map{|path|
      %Q!    image bg #{path.path2alias} = "bg/#{path}"!
    }.join("\n")
    str_doll = @doll_files.map{|path|
      path.sub!(/\.jpg$/, ".png")
      %Q!    image #{path.path2alias} = "doll/#{path}"!
    }.join("\n")
    str_variables = @variables.map{|var_name|
      /^(.)(.+)$/ =~ var_name
      type, var_name = $1, $2
      case type
      when "%"
        %Q!    $ #{var_name} = 0!
      when "$"
        %Q!    $ #{var_name} = ""!
      else
        ;
      end
    }.join("\n")
      
    src.sub!( /__REGIST__/, [str_bg, str_doll, str_variables].join("\n\n") )
    
    open("script.rpy", "w"){|fout|
      fout.print src
    }
    
    open("__list_bg.txt", "w"){|fout|
      @bg_files.each{|path| fout.puts path }
    }
    open("__list_doll.txt", "w"){|fout|
      @doll_files.each{|path| fout.puts path }
    }
  end
end




class Script
  attr_reader :is_last, :bg_files, :doll_files, :variables

  def initialize(n)
    @n = n
    @src_path  = "#{$src_dir}/%02d.txt"  % [@n]
    @sink_path = "#{$sink_dir}/%02d.rpy" % [@n]
    
    return unless src_exist?(@n)
  
    @src = Uconv.sjistou8(File.read(@src_path))
    @src.gsub!(/\r\n/, "\n")
    @src.gsub!(/\r/, "\n")
    
    @file_number = @src_path.sub( /^.*(\d\d)\.txt/i, '\1' )
    @file_number_next = "%02d" % [@file_number.to_i + 1]
    
    if src_exist?(@n+1)
      @is_last = false
    else
      @is_last = true
    end
    $stderr.puts "#{@src_path} is last?: #{@is_last}"
  
    @indent = " " * 4
    
    @parsed = []
    if @n > 1
      @parsed << "label ns_file_%s:" % [@file_number]
    end
    
    @bg_files = []
    @doll_files = []
    @variables = []
    @current_doll = {}
    @current_bg = nil
  end
  
  
  def src_exist?(n)
    src_path = "#{$src_dir}/%02d.txt"  % [n]
    if File.exist? src_path
      return true
    else
      # 0パディングでないファイル名
      temp_path = "#{$src_dir}/%d.txt"  % [n]
      if File.exist? temp_path
        @src_path = temp_path
      else
        return false
      end
    end
  end
  
  
  def add(str)
    @parsed <<  (@indent * @indent_depth) + str 
  end
  
  
  def flush_messages
    return if @buf.empty?
    @buf.each{|line|
      temp = ""
      line.each{|str|
        str.gsub!( /^br$/, " \\n " )
        
        #str.sub! /@$/, "¶{p}" # クリック待ち + 改行
        str.sub! /@$/, "{p}" # クリック待ち + 改行
        
        str.gsub! '"', '\\\\"'
        #pp str.strip
        #temp += str.strip
        str.strip!
        str.gsub!("\n", "<n>")
        temp += str
      }
      line = temp
    }
    temp = @buf.join(" ")
    
    #@src.gsub! "\\", "{p}"
    #@src.gsub! "@", "{w=1}"
    temp.gsub! "@", "{w}" # クリック待ち

    
    temp.strip!
    temp.sub!( /\{w\}\Z/, "" )
    temp.sub!( /\{p\}\Z/, "" )
    add %{n "#{temp}"}
    @buf = []
  end
  
  
  #
  # 複数行の select文を 1行にまとめる
  #
  def parse_select_statement
    temp = @src
    result = []
    
    while /
          ^select\s+
               "(.+?)", \s* (\*[a-z0-9]+?)   # 1つ目
          (,\s*"(.+?)", \s* (\*[a-z0-9]+?))+ # 2つ目以降
        /mx =~ temp
      
      pre = $`
      select = $&
      post = $'

      result << pre
      result << select.gsub("\n", "")
      temp = post
    end
    result << temp
    @src = result.join("\n\n")
  end


  def preproc
    @blocks = []
    buf = []
    
    parse_select_statement()

    begin
      @src.gsub! "\\", %Q!\nrenpy:nvl clear!
    rescue => e
      $stderr.puts e.inspect, @n
    end

    @src.each{|line|
      case line
      when /^;/
        ;
      when /^\s*$/
        ;
      when $statements_re
        @blocks << buf unless buf.empty?
        @blocks << [ $1, $'.strip ]
        buf = []
      else
        buf << line
      end
    }
  end
  
  
  def parse
    @indent_depth = 1
    @buf = []

    count = 0
    @blocks.each{|line|
      count += 1
      
      case line[0]
      when $statements_re
        flush_messages()
        statement, args = line
      end
      
      case line[0]
      #when /^\s*$/
      #  @parsed << ""
      when "bg"
        case args
        when /^"((.+?)\.jpg)"(,\s*(\d))?/
          bg_file, bg_name = $1, $2
          trans_sec = $4 if $4
          args.gsub! '"', "__"
          add %Q!$ temp_dissolve = Dissolve(#{trans_sec}) ! if trans_sec
          add %Q!scene bg #{bg_name}!
          add %Q!with temp_dissolve! if trans_sec
          @current_bg = bg_name
          @bg_files << bg_file
        when /^(.+),(\d)$/
          #bg black,2
          #bg white,2
          bg_name = $1
          trans_sec = $2
          add %Q!$ temp_dissolve = Dissolve(#{trans_sec}) ! if trans_sec
          add %Q!scene bg #{bg_name}!
          add %Q!with temp_dissolve! if trans_sec
          @current_bg = bg_name
        end
      
      when "\*"
        @parsed << "label #{args}:"
        
      when "br"
        #$stderr.puts "#{count} #{line}" if @file_number == "03"
        @buf << " __br__ "
        
      when "cl" # 立ち絵消去
        args.strip!
        /(.+?),(\d)$/ =~ args
        pos, trans_sec = $1, $2
        #$stderr.puts "#{args}__#{pos}__#{trans_sec}"
        if pos == "a"
          if @current_bg != nil
            add %{scene bg #{@current_bg}} 
          else
            add %{scene bg black} 
          end
        else
          p @current_doll
          chara = @current_doll[pos].sub(/\.jpg$/, "").path2chara
          add %{$ temp_dissolve = Dissolve(#{trans_sec}) } if trans_sec
          add %{hide #{chara} }
          add %{with temp_dissolve} if trans_sec
          @current_doll[pos] = nil
        end
      
      when "ld" # 立ち絵
        #$stderr.puts "LD----__#{args.strip}__"
        case args.strip
        #when /^(.)":a;(.+)"(,\s*(\d))?$/ # 文法的にはたぶんこっちが正しい
        when /^(.),?":a;(.+)"(,\s*(\d))?/
          #ld c":a;aya_pt_ons_bustup.jpg",2
          #ld l,":a;akane_pt_ons01.jpg",2
          #$stderr.puts "LD2----__#{$1}__#{$2}__#{$3}__#{$4}__#{$5}__"
          pos, file, trans_sec = $1, $2, $4
          chara = file.sub(/\.jpg$/, "").path2chara
          @current_doll[pos] = file
          
          @doll_files << file
          add %Q!$ temp_dissolve = Dissolve(#{trans_sec}) ! if trans_sec
          add %Q!show #{chara} at #{pos.full_pos} ###############!
          add %Q!with temp_dissolve! if trans_sec
        else
          raise "syntax error at line #{@file_number}-#{count}."
        end
        
      when "select"
        args.strip!

        add "menu:"
        re = /"(.+?)", \s* \*([a-z0-9]+)/mx
        args.scan(re).each{|piece|
          label, dest = piece[0], piece[1]
          @indent_depth += 1
          add %{"#{label}":}
          @indent_depth += 1
          add %{jump #{dest}}
          @indent_depth -= 2
        }


      when "goto"
        add %Q!jump #{args.sub("*", "")}!

      ## variable
      when "mov"
        case args
        when /^%([a-zA-Z_]+),(\d)/
          var_name, val = $1, $2
          add %Q!$ #{var_name} = #{val}!
        end
      when "add"
        case args
        when /^%([a-zA-Z_]+),(\d)/
          var_name, val = $1, $2
          add %Q!$ #{var_name} += #{val}!
          @variables << "%" + var_name
        when /^\$([a-zA-Z_]+),"(.+)"/
          var_name, val = $1, $2
          add %Q!$ #{var_name} += "#{val}"!
          @variables << "$" + var_name
        end
      
      when "renpy:"
        add args
      
      else
        @buf << line
      
      end
    }
  end
  
  
  def to_s
    return @parsed.join("\n")
  end
  
  
  def write
    puts @sink_path
    open(@sink_path, "w"){|fout|
      fout.puts "label renpy_file_%02d:" % [@n]
      
      fout.puts self.to_s
      
      unless @is_last
        fout.puts "    jump renpy_file_%02d" % [@n+1]
      end
    }
  end
end




###########################################################

unless ARGV[0]
  puts "Usage: #{__FILE__} src_dir"
  exit 1
end

$src_dir = ARGV[0]
$sink_dir = "."

ns = NScripter.new
ns.parse_files
ns.write
ns.regist



=begin

逆引きNDSプログラミング - NScripter
http://smilelab.sakura.ne.jp/ndswiki/?NScripter

=end
