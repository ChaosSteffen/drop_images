require 'rubygems'
require 'mini_magick'
require 'cloudapp_api'

def get_files(arguments)
  files = []

  if arguments.length == 0
    puts 'no image given'
    exit
  else
    arguments.each do |arg|
      if File.file?(arg)
        files << arg
      elsif File.directory?(arg)
        entries = Dir.entries(arg)
        entries.delete_if { |e| File.directory?(File.join(arg, e)) or e.start_with?('.') }
        files += entries.map { |e| File.join(arg, e) }
      else
        puts "no file or directory: #{arg}"
      end
    end
  end
  
  return files
end

def generate_tmp_name(filename)
  ext = File.extname(filename)
  basename = File.basename(filename, ext)
  
  return File.join(Dir.tmpdir, "#{basename}_thumb#{ext}")
end

def generate_thumb(filename)
  filename = File.expand_path(filename)
  thumbname = generate_tmp_name(filename)
  
  image = MiniMagick::Image.open(filename)
  image.combine_options do |c|
    c.resize '150x100^'
    c.gravity "center"
    c.extent "150x100"
  end
  image.write  thumbname
  
  thumbname
end

timestamp = Time.now.to_i

originals = get_files(ARGV)
thumbs = originals.map { |filename| generate_thumb(filename) }

combined = originals.zip(thumbs)

CloudApp.authenticate ENV['CLOUD_APP_MAIL'], ENV['CLOUD_APP_PASS']

links = combined.map do |original, thumbnail|
  original_url = CloudApp::Drop.create(:upload, :file => original, :private => true).remote_url
  thumbnail_url = CloudApp::Drop.create(:upload, :file => thumbnail, :private => true).remote_url
  
  html = "<a class=\"photo_gallery\"rel=\"gallery_#{timestamp}\" href=\"#{original_url}\"><img src=\"#{thumbnail_url}\"></a>"
end * "\n"
puts links