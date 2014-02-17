require 'rake'
module Middleman
    module SVGFallback
        class << self
        
            def registered(app, options={})
                options[:inkscape_bin] ||= 'inkscape'
                options[:generate_svgz] = true if options[:generate_svgz].nil?
                options[:generate_jpeg] = true if options[:generate_jpeg].nil?
                options[:generate_png] = true if options[:generate_png].nil?
                options[:jpeg_extension] = "jpg" unless options[:jpeg_extension] =~ /^jpe?g$/

                app.after_configuration do

                    input_dir = options[:input_folder] ? options[:input_folder] : images_dir
                    input_dir = File.join(source_dir, input_dir).chomp("/")
                    raise "Could not find source folder #{input_dir}" unless File.directory?(input_dir)
          
                    output_dir = options[:output_folder].nil? ? input_dir : File.join(source_dir, options[:output_folder])
                    output_dir.chomp!("/")
                    raise "Could not find output folder #{output_dir}" unless File.directory?(output_dir)

                    before_build do |builder|
                        files = FileList["#{input_dir}/**/*.svg*"]
          
                        files.each do |file|
                            # make sure we have both an svg and an svgz version
                            path_without_extension = file.sub(/\.svgz?$/,'')
          
                            temp_uncompressed_file = nil
                            unless File.exists? "#{path_without_extension}.svg"
                                `gunzip --to-stdout --suffix .svgz  #{path_without_extension}.svgz > #{path_without_extension}.svg`
                                temp_uncompressed_file = "#{path_without_extension}.svg"
                            end
                            
                            if options[:generate_svgz] && !File.exists?("#{path_without_extension}.svgz")
                                `gzip --to-stdout #{path_without_extension}.svg > #{path_without_extension}.svgz`
                                builder.say_status :svgz, "#{path_without_extension}.svgz"
                            end
          
                            # generate fallbacks
                            raster_images = []
                            raster_images << "png" if options[:generate_png]
                            raster_images << options[:jpeg_extension] if options[:generate_jpeg]
                            raster_images.each do |ext|
                                input_path = "#{path_without_extension}.svg"
                                output_path = "#{File.join(output_dir, File.basename(path_without_extension))}.#{ext}"
                                `#{options[:inkscape_bin]} --export-png=#{output_path} #{options[:inkscape_options]} --without-gui #{input_path}  > /dev/null 2>&1`
                                builder.say_status :svg_fallback, "#{output_path}"
                            end
                            
                            if !options[:generate_svgz] && temp_uncompressed_file
                                File.rm(temp_uncompressed_file)
                            end
                        end
                    end
                end
            end
            alias :included :registered
      
        end
    end
end