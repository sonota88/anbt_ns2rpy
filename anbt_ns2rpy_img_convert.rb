#!/usr/bin/env ruby

require "fileutils"

unless ARGV[1]
  $stderr.puts <<EOB
usage: #{__FILE__} png2jpg foo.jpg"
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
