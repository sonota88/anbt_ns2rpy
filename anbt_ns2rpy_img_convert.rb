#!/usr/bin/env ruby
# -*- coding: undecided -*-

=begin

修正BSDライセンスとします。
日本語訳はここ。
http://sourceforge.jp/projects/opensource/wiki/licenses%2Fnew_BSD_license

--------
Copyright (c) 2009, sonota (yosiot8753@gmail.com)
All rights reserved.

Redistribution and use in source and binary forms, with or without 
modification, are permitted provided that the following conditions 
are met:

* Redistributions of source code must retain the above copyright 
  notice, this list of conditions and the following disclaimer.
* Redistributions in binary form must reproduce the above copyright 
  notice, this list of conditions and the following disclaimer in the 
  documentation and/or other materials provided with the distribution.
* Neither the name of the sonota nor the names of its contributors 
  may be used to endorse or promote products derived from this 
  software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT 
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR 
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT 
HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS 
OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED 
AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, 
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF 
THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH 
DAMAGE.

=end


require "fileutils"

unless ARGV[1]
  $stderr.puts <<EOB
usage: #{__FILE__} png2jpg foo.png"
       or
       #{__FILE__} jpg2png foo.jpg"
EOB
end


def jpg2png(jpgfile)
  
  trunk = jpgfile.sub(/\.jpg$/,"")
  result = trunk + ".png"
  image  = "temp-0.png"
  alpha1 = "temp-1.png"
  alpha2 = "alpha.png"
  
  cmd = %{convert -crop 50%x100% #{jpgfile} temp.png}
  puts cmd
  system cmd
  
  cmd = %{convert #{alpha1} -negate #{alpha2} }
  puts cmd
  system cmd
  
  cmd = %{composite #{alpha2} #{image} -compose CopyOpacity #{result} }
  puts cmd
  system cmd
  
  FileUtils.rm image
  FileUtils.rm alpha1
  FileUtils.rm alpha2
end


def png2jpg(pngfile)
  trunk = jpgfile.sub(/\.jpg$/,"")
  result = trunk + ".jpg"
  
  temp = `identify #{pngfile}`
  puts temp
  /(\d+)x(\d+)/ =~ temp
  w, h = $1, $2
  
  color = "color.png"
  
  system "cp #{pngfile} #{color}"
end


case ARGV[0]
when "jpg2png"
  jpg2png(ARGV[1])
when "png2jpg"
  png2jpg(ARGV[1])
else
  raise "must not happen"
end
